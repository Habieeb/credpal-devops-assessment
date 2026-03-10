require("dotenv").config();
const express = require("express");
const helmet = require("helmet");
const morgan = require("morgan");

const app = express();

app.use(helmet());
app.use(express.json());
app.use(morgan("combined"));

app.get("/", (_req, res) => {
  return res.status(200).json({
    message: "CredPal DevOps assessment app is running",
    endpoints: ["/health", "/status", "/process"]
  });
});

app.get("/health", (_req, res) => {
  return res.status(200).json({
    status: "ok",
    service: "credpal-app",
    timestamp: new Date().toISOString()
  });
});

app.get("/status", (_req, res) => {
  return res.status(200).json({
    status: "running",
    uptime_seconds: process.uptime(),
    processed_count: 0,
    redis_status: "not configured in production",
    environment: process.env.NODE_ENV || "development",
    timestamp: new Date().toISOString()
  });
});

app.post("/process", (req, res) => {
  const payload = req.body || {};

  return res.status(202).json({
    message: "Payload accepted for processing",
    request_payload: payload,
    processed_count: 0,
    processed_at: new Date().toISOString(),
    note: "Redis-backed processing is available in local Docker Compose setup"
  });
});

module.exports = app;
