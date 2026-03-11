data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }
}

resource "aws_iam_role" "ec2_role" {
  name = "${local.name}-ec2-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_instance_profile" "ec2_profile" {
  name = "${local.name}-instance-profile"
  role = aws_iam_role.ec2_role.name
}

resource "aws_lb" "app" {
  name               = replace(local.name, "/[^a-zA-Z0-9-]/", "-")
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = aws_subnet.public[*].id
}

resource "aws_lb_target_group" "app" {
  name        = substr("${local.name}-tg", 0, 32)
  port        = var.container_port
  protocol    = "HTTP"
  target_type = "instance"
  vpc_id      = aws_vpc.main.id

  health_check {
    path                = "/health"
    matcher             = "200"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 3
  }
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.app.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = "redirect"

    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}

resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.app.arn
  port              = 443
  protocol          = "HTTPS"
  certificate_arn   = aws_acm_certificate.cert.arn
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app.arn
  }
}

resource "aws_launch_template" "app" {
  name_prefix   = "${local.name}-lt-"
  image_id      = data.aws_ami.amazon_linux.id
  instance_type = "t3.micro"

  iam_instance_profile {
    name = aws_iam_instance_profile.ec2_profile.name
  }

  vpc_security_group_ids = [aws_security_group.ec2.id]

  user_data = base64encode(<<-EOF
    #!/bin/bash
    set -euxo pipefail

    IMAGE="ghcr.io/habieeb/credpal-devops-assessment:latest"
    CONTAINER_NAME="credpal-app"
    PORT="${var.container_port}"
    REDIS_URL="redis://${aws_elasticache_replication_group.redis.primary_endpoint_address}:6379"

    dnf update -y
    dnf install -y docker
    systemctl enable docker
    systemctl start docker
    usermod -aG docker ec2-user

    cat >/usr/local/bin/update-credpal-app.sh <<'SCRIPT'
    #!/bin/bash
    set -euo pipefail

    IMAGE="ghcr.io/habieeb/credpal-devops-assessment:latest"
    CONTAINER_NAME="credpal-app"
    PORT="${var.container_port}"
    REDIS_URL="redis://${aws_elasticache_replication_group.redis.primary_endpoint_address}:6379"

    current_container_image_id=$$(docker inspect "$${CONTAINER_NAME}" --format '{{.Image}}' 2>/dev/null || true)

    docker pull "$${IMAGE}" >/dev/null

    latest_image_id=$$(docker image inspect "$${IMAGE}" --format '{{.Id}}')

    if [ -z "$${current_container_image_id}" ] || [ "$${current_container_image_id}" != "$${latest_image_id}" ]; then
      docker rm -f "$${CONTAINER_NAME}" 2>/dev/null || true

      docker run -d \
        --name "$${CONTAINER_NAME}" \
        --restart unless-stopped \
        -p "$${PORT}:$${PORT}" \
        -e PORT="$${PORT}" \
        -e NODE_ENV=production \
        -e REDIS_URL="$${REDIS_URL}" \
        "$${IMAGE}"
    fi
    SCRIPT

    chmod +x /usr/local/bin/update-credpal-app.sh

    cat >/etc/systemd/system/credpal-app-updater.service <<'SERVICE'
    [Unit]
    Description=Update CredPal app container if a newer image is available
    After=docker.service
    Requires=docker.service

    [Service]
    Type=oneshot
    ExecStart=/usr/local/bin/update-credpal-app.sh
    SERVICE

    cat >/etc/systemd/system/credpal-app-updater.timer <<'TIMER'
    [Unit]
    Description=Run CredPal app updater every 5 minutes

    [Timer]
    OnBootSec=30s
    OnUnitActiveSec=5min
    Unit=credpal-app-updater.service

    [Install]
    WantedBy=timers.target
    TIMER

    systemctl daemon-reload
    systemctl enable credpal-app-updater.timer
    systemctl start credpal-app-updater.timer

    /usr/local/bin/update-credpal-app.sh
  EOF
  )
}

resource "aws_autoscaling_group" "app" {
  name                      = "${local.name}-asg"
  desired_capacity          = var.desired_count
  min_size                  = var.desired_count
  max_size                  = 4
  health_check_type         = "ELB"
  health_check_grace_period = 300

  vpc_zone_identifier = aws_subnet.private[*].id
  target_group_arns   = [aws_lb_target_group.app.arn]

  launch_template {
    id      = aws_launch_template.app.id
    version = "$Latest"
  }

  tag {
    key                 = "Name"
    value               = "${local.name}-app"
    propagate_at_launch = true
  }

  instance_refresh {
    strategy = "Rolling"

    preferences {
      min_healthy_percentage = 50
    }
  }

  depends_on = [aws_lb_listener.https]
}
