jest.mock("../src/redis", () => ({
  getRedisClient: jest.fn(async () => ({
    ping: jest.fn(async () => "PONG"),
    get: jest.fn(async (key) => {
      if (key === "processed_count") return "2";
      return null;
    }),
    set: jest.fn(async () => "OK")
  }))
}));

const request = require("supertest");
const app = require("../src/app");

describe("App endpoints", () => {
  test("GET /health should return 200", async () => {
    const response = await request(app).get("/health");
    expect(response.statusCode).toBe(200);
    expect(response.body.status).toBe("ok");
  });

  test("GET /status should return status payload", async () => {
    const response = await request(app).get("/status");
    expect(response.statusCode).toBe(200);
    expect(response.body.status).toBe("running");
  });

  test("POST /process should accept payload", async () => {
    const response = await request(app)
      .post("/process")
      .send({ task: "demo" });

    expect(response.statusCode).toBe(202);
    expect(response.body.message).toBe("Payload accepted for processing");
  });
});
