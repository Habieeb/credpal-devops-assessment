const { createClient } = require("redis");

let client;

async function getRedisClient() {
  if (!client) {
    client = createClient({
      url: process.env.REDIS_URL || "redis://redis:6379"
    });

    client.on("error", (err) => {
      console.error("Redis Client Error:", err.message);
    });

    await client.connect();
  }

  return client;
}

module.exports = { getRedisClient };
