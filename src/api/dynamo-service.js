/**
 * SkillBridge AI — Amazon DynamoDB Service Integration
 * Handles persistence for User Profiles, Skill Assessments, Roadmaps, Progress, and Challenges.
 */

const { DynamoDBClient } = require("@aws-sdk/client-dynamodb");
const { DynamoDBDocumentClient, PutCommand, GetCommand, UpdateCommand } = require("@aws-sdk/lib-dynamodb");

const REGION = process.env.AWS_REGION || "us-east-1";
const TABLE_NAME = process.env.DYNAMODB_TABLE_NAME || "skillbridge-dev-data";

const client = new DynamoDBClient({ region: REGION });
const docClient = DynamoDBDocumentClient.from(client);

// In-Memory Fallback Cache when DynamoDB table is being created or running locally
const memoryStore = new Map();

/**
 * Save User Assessment & Roadmap to DynamoDB
 */
async function saveAssessmentAndRoadmap(userId, assessment, skillGap, roadmap) {
  const record = {
    PK: `USER#${userId}`,
    SK: "ROADMAP#CURRENT",
    userId,
    assessment,
    skillGap,
    roadmap,
    updatedAt: new Date().toISOString()
  };

  memoryStore.set(`user:${userId}`, record);

  try {
    const command = new PutCommand({
      TableName: TABLE_NAME,
      Item: record
    });
    await docClient.send(command);
    console.log(`[DynamoDB] Saved roadmap for user ${userId}`);
  } catch (err) {
    console.warn("[DynamoDB] Table write warning (using fallback memory store):", err.message);
  }

  return record;
}

/**
 * Get User Roadmap & Progress from DynamoDB
 */
async function getUserRoadmap(userId) {
  try {
    const command = new GetCommand({
      TableName: TABLE_NAME,
      Key: {
        PK: `USER#${userId}`,
        SK: "ROADMAP#CURRENT"
      }
    });

    const response = await docClient.send(command);
    if (response.Item) {
      return response.Item;
    }
  } catch (err) {
    console.warn("[DynamoDB] Table read warning (using fallback memory store):", err.message);
  }

  return memoryStore.get(`user:${userId}`) || null;
}

/**
 * Save / Update Task Progress
 */
async function updateTaskProgress(userId, taskId, completed) {
  const existing = await getUserRoadmap(userId);
  if (!existing || !existing.roadmap) return false;

  let found = false;
  existing.roadmap.forEach(wk => {
    wk.tasks.forEach(t => {
      if (t.id === taskId) {
        t.completed = completed;
        found = true;
      }
    });
  });

  if (found) {
    await saveAssessmentAndRoadmap(userId, existing.assessment, existing.skillGap, existing.roadmap);
  }

  return found;
}

module.exports = {
  saveAssessmentAndRoadmap,
  getUserRoadmap,
  updateTaskProgress
};
