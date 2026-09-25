/**
 * API Contract Test Suite for SkillBridge AI
 */

const { handler } = require("../../src/api/index");

describe("SkillBridge AI - API Gateway Contract Tests", () => {
  test("GET /api/v1/status should return 200 OK with health metadata", async () => {
    const event = {
      httpMethod: "GET",
      path: "/api/v1/status"
    };

    const response = await handler(event, {});
    expect(response.statusCode).toBe(200);

    const body = JSON.parse(response.body);
    expect(body.status).toBe("healthy");
    expect(body.service).toBe("skillbridge-ai-api");
    expect(body.bedrock).toBe("connected");
  });

  test("POST /api/v1/assessment should return skillGap and roadmap", async () => {
    const event = {
      httpMethod: "POST",
      path: "/api/v1/assessment",
      body: JSON.stringify({
        name: "Test User",
        currentRole: "Student",
        experienceLevel: "Beginner",
        currentSkills: "Python, SQL",
        targetRole: "AWS Solutions Architect",
        weeklyHours: 6
      })
    };

    const response = await handler(event, {});
    expect(response.statusCode).toBe(200);

    const body = JSON.parse(response.body);
    expect(body.skillGap).toBeDefined();
    expect(body.roadmap).toBeDefined();
  });

  test("POST /api/v1/mentor should return AI reply", async () => {
    const event = {
      httpMethod: "POST",
      path: "/api/v1/mentor",
      body: JSON.stringify({
        prompt: "Explain VPC subnets",
        context: "AWS Solutions Architect"
      })
    };

    const response = await handler(event, {});
    expect(response.statusCode).toBe(200);

    const body = JSON.parse(response.body);
    expect(body.reply).toBeDefined();
  });
});
