require("dotenv").config();
const express = require("express");
const helmet = require("helmet");
const morgan = require("morgan");
const { getRedisClient } = require("./redis");

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

app.get("/health", async (_req, res) => {
  try {
    const redis = await getRedisClient();
    await redis.ping();

    return res.status(200).json({
      status: "ok",
      service: "credpal-app",
      redis_status: "connected",
      timestamp: new Date().toISOString()
    });
  } catch (error) {
    return res.status(500).json({
      status: "error",
      service: "credpal-app",
      redis_status: "unavailable",
      message: "Health check failed",
      error: error.message
    });
  }
});

app.get("/status", async (_req, res) => {
  try {
    const redis = await getRedisClient();
    const processed = await redis.get("processed_count");

    return res.status(200).json({
      status: "running",
      uptime_seconds: process.uptime(),
      processed_count: Number(processed || 0),
      environment: process.env.NODE_ENV || "development",
      timestamp: new Date().toISOString()
    });
  } catch (error) {
    return res.status(500).json({
      status: "error",
      message: "Status check failed",
      error: error.message
    });
  }
});

app.post("/process", async (req, res) => {
  try {
    const payload = req.body || {};
    const redis = await getRedisClient();

    const current = Number((await redis.get("processed_count")) || 0);
    const next = current + 1;

    await redis.set("processed_count", String(next));
    await redis.set(`last_payload:${next}`, JSON.stringify(payload));

    return res.status(202).json({
      message: "Payload accepted for processing",
      request_payload: payload,
      processed_count: next,
      processed_at: new Date().toISOString()
    });
  } catch (error) {
    return res.status(500).json({
      status: "error",
      message: "Processing failed",
      error: error.message
    });
  }
});

module.exports = app;
