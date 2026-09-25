/**
 * Security Header Test Suite for SkillBridge AI
 */

const { handler } = require("../../src/api/index");

describe("SkillBridge AI - Security Headers & Compliance", () => {
  test("All API responses must include strict security headers", async () => {
    const event = {
      httpMethod: "GET",
      path: "/api/v1/status"
    };

    const response = await handler(event, {});
    expect(response.headers["X-Content-Type-Options"]).toBe("nosniff");
    expect(response.headers["X-Frame-Options"]).toBe("DENY");
    expect(response.headers["Strict-Transport-Security"]).toBeDefined();
    expect(response.headers["Access-Control-Allow-Origin"]).toBe("*");
  });
});
