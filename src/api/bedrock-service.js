/**
 * SkillBridge AI — Amazon Bedrock Service Integration
 * Connects to Amazon Bedrock Runtime for AI Skill Gap Analysis, Personalized Roadmaps, and AI Mentoring.
 */

const { BedrockRuntimeClient, InvokeModelCommand } = require("@aws-sdk/client-bedrock-runtime");

const REGION = process.env.AWS_REGION || "us-east-1";
// Use Amazon Nova Pro / Nova Lite / Llama 3 as available in region
const DEFAULT_MODEL_ID = process.env.BEDROCK_MODEL_ID || "amazon.nova-lite-v1:0";

const bedrockClient = new BedrockRuntimeClient({ region: REGION });

/**
 * Generate Skill Gap Analysis & Personalized Roadmap using Amazon Bedrock
 */
async function analyzeSkillGapAndRoadmap(assessment) {
  const { name, currentRole, experienceLevel, currentSkills, targetRole, weeklyHours } = assessment;

  const prompt = `You are an expert AWS Cloud Career Mentor. Analyze this technology learner profile:
Name: ${name}
Current Role: ${currentRole}
Experience Level: ${experienceLevel}
Current Skills: ${currentSkills}
Target Role: ${targetRole}
Weekly Available Hours: ${weeklyHours}

Perform a rigorous skill gap analysis and generate a weekly learning roadmap adapted to ${weeklyHours} hours per week.
Return ONLY a valid, minified JSON object with no preamble, markdown code blocks, or extra text using this EXACT schema:
{
  "targetRole": "${targetRole}",
  "skillGap": [
    { "name": "Skill Name", "priority": "high|medium|low", "reason": "Why this skill is needed" }
  ],
  "roadmap": [
    {
      "week": 1,
      "title": "Week 1 Title",
      "objectives": "Learning goals",
      "hours": ${weeklyHours},
      "tasks": [
        { "id": "w1-1", "title": "Specific practical task", "completed": false }
      ]
    }
  ]
}`;

  try {
    const response = await invokeBedrockModel(prompt);
    const parsed = parseJSONFromText(response);

    if (parsed && parsed.skillGap && parsed.roadmap) {
      return parsed;
    }
  } catch (err) {
    console.warn("[Bedrock Service] Model invocation failed, using structured fallback:", err.message);
  }

  // Graceful Fallback if Bedrock model fails or throttles
  return createFallbackRoadmap(assessment);
}

/**
 * AI Mentor Question & Answer Generator
 */
async function generateMentorReply(promptText, contextRole = "AWS Solutions Architect") {
  const systemPrompt = `You are the SkillBridge AI Learning Mentor, an empathetic, expert AWS Cloud Architect tutor. 
The user is aiming to become a ${contextRole}.
Answer the user's question clearly with practical real-world AWS architectural insights, simple analogies, and actionable steps.
User Question: "${promptText}"`;

  try {
    const reply = await invokeBedrockModel(systemPrompt);
    if (reply && reply.trim().length > 10) {
      return reply;
    }
  } catch (err) {
    console.warn("[Bedrock Mentor] Invocation error:", err.message);
  }

  return generateStaticMentorResponse(promptText, contextRole);
}

/**
 * Low-level Amazon Bedrock Model invocation helper
 */
async function invokeBedrockModel(promptText) {
  let payload;

  if (DEFAULT_MODEL_ID.includes("amazon.nova")) {
    payload = {
      messages: [
        { role: "user", content: [{ text: promptText }] }
      ],
      inferenceConfig: { maxTokens: 2000, temperature: 0.7 }
    };
  } else if (DEFAULT_MODEL_ID.includes("meta.llama")) {
    payload = {
      prompt: `<|begin_of_text|><|start_header_id|>user<|end_header_id|>\n${promptText}<|eot_id|><|start_header_id|>assistant<|end_header_id|>\n`,
      max_gen_len: 2000,
      temperature: 0.7
    };
  } else {
    payload = {
      prompt: `\n\nHuman: ${promptText}\n\nAssistant:`,
      max_tokens_to_sample: 2000,
      temperature: 0.7
    };
  }

  const command = new InvokeModelCommand({
    modelId: DEFAULT_MODEL_ID,
    contentType: "application/json",
    accept: "application/json",
    body: JSON.stringify(payload)
  });

  const response = await bedrockClient.send(command);
  const responseBody = JSON.parse(new TextDecoder().decode(response.body));

  if (responseBody.output && responseBody.output.message && responseBody.output.message.content) {
    return responseBody.output.message.content[0].text;
  }
  if (responseBody.generation) {
    return responseBody.generation;
  }
  if (responseBody.completion) {
    return responseBody.completion;
  }

  return JSON.stringify(responseBody);
}

/**
 * Safe JSON Extractor
 */
function parseJSONFromText(text) {
  try {
    const match = text.match(/\{[\s\S]*\}/);
    if (match) {
      return JSON.parse(match[0]);
    }
    return JSON.parse(text);
  } catch (e) {
    return null;
  }
}

/**
 * Structured Fallback Roadmap Generator
 */
function createFallbackRoadmap(assessment) {
  const { targetRole, weeklyHours } = assessment;

  return {
    targetRole: targetRole || "AWS Solutions Architect",
    skillGap: [
      { name: "AWS IAM & Security Governance", priority: "high", reason: "Fundamental access control required for all cloud architectures." },
      { name: "Virtual Private Cloud (VPC) & Subnets", priority: "high", reason: "Mandatory network isolation and routing boundary." },
      { name: "Amazon EC2 & Auto Scaling", priority: "medium", reason: "Core compute execution layer for application workloads." },
      { name: "Amazon DynamoDB & S3 Persistence", priority: "medium", reason: "Key-value and object storage foundation." },
      { name: "AWS CloudWatch & Alarms", priority: "low", reason: "Operational observability and log aggregation." }
    ],
    roadmap: [
      {
        week: 1,
        title: "AWS Identity & Access Management (IAM)",
        objectives: "Master Users, Groups, Roles, Policies, and Least Privilege principle.",
        hours: weeklyHours || 6,
        tasks: [
          { id: "w1-1", title: "Create custom IAM User with least-privilege policy", completed: false },
          { id: "w1-2", title: "Configure AWS CLI credentials and MFA protection", completed: false },
          { id: "w1-3", title: "Enable CloudTrail security event logging", completed: false }
        ]
      },
      {
        week: 2,
        title: "Amazon VPC & Cloud Networking",
        objectives: "Design a Multi-AZ VPC topology with Public/Private Subnets and NAT Gateways.",
        hours: weeklyHours || 6,
        tasks: [
          { id: "w2-1", title: "Provision custom 10.0.0.0/16 VPC with 2 Public & 2 Private subnets", completed: false },
          { id: "w2-2", title: "Configure Route Tables, IGW, and Security Groups", completed: false }
        ]
      },
      {
        week: 3,
        title: "Compute & Scalable Storage (EC2 & S3)",
        objectives: "Deploy EC2 web servers and configure encrypted S3 buckets.",
        hours: weeklyHours || 6,
        tasks: [
          { id: "w3-1", title: "Launch EC2 instance in Private Subnet", completed: false },
          { id: "w3-2", title: "Create S3 bucket with KMS encryption and public access block", completed: false }
        ]
      },
      {
        week: 4,
        title: "Database Persistence & Observability",
        objectives: "Implement DynamoDB table persistence and CloudWatch alarms.",
        hours: weeklyHours || 6,
        tasks: [
          { id: "w4-1", title: "Create DynamoDB table with GSI and TTL", completed: false },
          { id: "w4-2", title: "Set up CloudWatch alarm for system health", completed: false }
        ]
      }
    ]
  };
}

function generateStaticMentorResponse(prompt, targetRole) {
  const q = prompt.toLowerCase();
  if (q.includes("vpc")) {
    return `<strong>Virtual Private Cloud (VPC)</strong> is your isolated virtual network in AWS. Key components include:
<br><br>
• <strong>Public Subnet</strong>: Connected to the Internet Gateway for public-facing assets.<br>
• <strong>Private Subnet</strong>: Isolated from direct public internet access for databases and backend servers.<br>
• <strong>Security Groups</strong>: Stateful virtual firewalls at the instance level.`;
  }
  if (q.includes("iam")) {
    return `<strong>IAM Best Practices for ${targetRole}:</strong><br>1. Always enforce Multi-Factor Authentication (MFA).<br>2. Grant least-privilege permissions via IAM Roles rather than long-lived keys.<br>3. Never use root user credentials for daily administrative tasks.`;
  }
  return `To excel as a <strong>${targetRole}</strong>, focus on combining theoretical AWS Knowledge Concepts with hands-on CLI practice. Review your current weekly roadmap objectives to build your next exercise!`;
}

module.exports = {
  analyzeSkillGapAndRoadmap,
  generateMentorReply
};
