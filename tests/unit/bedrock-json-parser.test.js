/**
 * Unit Test Suite for SkillBridge AI Bedrock Service & Roadmap Logic
 */

const { analyzeSkillGapAndRoadmap } = require("../../src/api/bedrock-service");

describe("SkillBridge AI - Bedrock & Roadmap Engine", () => {
  test("Should generate valid structured skill gap and roadmap for AWS Solutions Architect", async () => {
    const mockAssessment = {
      name: "Test Learner",
      currentRole: "Student",
      experienceLevel: "Beginner",
      currentSkills: "Python, SQL, Linux",
      targetRole: "AWS Solutions Architect",
      weeklyHours: 6
    };

    const result = await analyzeSkillGapAndRoadmap(mockAssessment);

    expect(result).toBeDefined();
    expect(result.targetRole).toBe("AWS Solutions Architect");
    expect(Array.isArray(result.skillGap)).toBe(true);
    expect(result.skillGap.length).toBeGreaterThan(0);
    expect(result.skillGap[0]).toHaveProperty("name");
    expect(result.skillGap[0]).toHaveProperty("priority");

    expect(Array.isArray(result.roadmap)).toBe(true);
    expect(result.roadmap.length).toBeGreaterThan(0);
    expect(result.roadmap[0]).toHaveProperty("week");
    expect(result.roadmap[0]).toHaveProperty("tasks");
  });
});
