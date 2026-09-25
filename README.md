# SkillBridge AI — Turn your current skills into your next career milestone

> **AWS Zero to Shipped Hackathon Submission**  
> **Category:** `#social-good`  
> **Lane:** `#community`  
> **Focus Area:** Education & Workforce Development  

---

## 🌐 Live Deployed Application

* **Primary Global Application (CloudFront Anycast CDN):**  
  👉 **[https://d1mkhiubsekh84.cloudfront.net](https://d1mkhiubsekh84.cloudfront.net)**

* **Direct API Gateway & Serverless Backend Engine:**  
  👉 **[https://gi3lr662bh.execute-api.us-east-1.amazonaws.com/dev](https://gi3lr662bh.execute-api.us-east-1.amazonaws.com/dev)**

---

## 🚀 Problem

Many students, technology learners, and early-career professionals have access to an overwhelming volume of online tutorials, videos, documentation, and certifications. However, the problem is **not a lack of information**.

The problem is knowing:
- *What should I learn next?*
- *Which skills am I missing for my target role?*
- *Which skills matter most to enterprise employers?*
- *How can I turn theoretical learning into practical hands-on experience?*
- *How do I organize and track my progress over time?*

Learners frequently jump between disjointed video courses and articles without a personalized, structured roadmap tailored to their background and available hours.

---

## 💡 Solution

**SkillBridge AI** is an AI-powered personalized learning navigator and career development platform that bridges the gap between a learner's current skills and their target technology role (e.g., AWS Solutions Architect, Cloud DevOps Engineer, Serverless Engineer).

Instead of giving learners another generic list of courses, SkillBridge AI:
1. Performs a deterministic **Skill Gap Analysis** using **Amazon Bedrock**.
2. Builds a **Personalized Weekly Roadmap** adapting to the learner's specified weekly study hours.
3. Provides an interactive **AI Mentor** for context-aware Q&A and architecture guidance.
4. Generates **Hands-on Architecture Challenges** with state persistence.
5. Tracks **Real Progress** dynamically in **Amazon DynamoDB**.

---

## ✨ Key Features

- **Interactive Skill Assessment**: Multi-step onboarding collecting role, experience, current skills, destination role, and weekly learning availability.
- **AI Skill Gap Priority Matrix**: Generates high/medium/low priority skill gaps with specific learning rationale using Amazon Bedrock.
- **Adaptive Weekly Roadmap**: Tailors study objectives, hours, and practical exercises to the user's available time.
- **AI Learning Mentor**: Context-aware AI tutor trained on the user's target role and active roadmap week.
- **Hands-on Architecture Hub**: Practical cloud scenarios with interactive status toggles (`Not Started` -> `In Progress` -> `Completed`).
- **Dynamic Dashboard & Progress Tracking**: Real-time progress bar calculated from verified task completion data stored in DynamoDB.
- **Enterprise Cognito Authentication**: Secure sign-up, sign-in, and session management using Amazon Cognito User Pools.

---

## 🏗️ Architecture

```
                                  SkillBridge AI Architecture
                                  
 ┌────────────────┐         ┌─────────────────────┐         ┌────────────────────────┐
 │   User / Web   │ ──────> │  Amazon CloudFront  │ ──────> │ Amazon Cognito User    │
 │   Dashboard    │ <────── │  / AWS Amplify      │         │ Pool (Authentication)  │
 └───────┬────────┘         └─────────────────────┘         └────────────────────────┘
         │
         │ REST API (JWT Authenticated)
         ▼
 ┌───────────────────────────────────────────────────────────────────────────────────┐
 │                            Amazon API Gateway (REST API)                          │
 └─────────────────────────────────────────────────┬─────────────────────────────────┘
                                                   │
                                                   ▼
 ┌───────────────────────────────────────────────────────────────────────────────────┐
 │                             AWS Lambda (Node.js 20)                               │
 ├──────────────────────────────┬─────────────────────────────┬──────────────────────┤
 │   Skill Gap & Roadmap Engine │      AI Mentor Engine       │   Progress & State   │
 └──────────────┬───────────────┴──────────────┬──────────────┴──────────┬───────────┘
                │                              │                         │
                ▼                              ▼                         ▼
 ┌──────────────────────────────┐ ┌──────────────────────────┐ ┌────────────────────┐
 │  Amazon Bedrock (Nova/Llama) │ │  Amazon S3 Knowledge Base│ │  Amazon DynamoDB   │
 │  JSON Structured Skill Gap   │ │  (Curated AWS Specs/RAG) │ │  Users, Roadmaps,  │
 │  & Custom Challenge Generator│ │                          │ │  Progress & State  │
 └──────────────────────────────┘ └──────────────────────────┘ └────────────────────┘
                                               │
                                               ▼
                                  ┌──────────────────────────┐
                                  │    Amazon CloudWatch     │
                                  │    Logs, Metrics & Alarms│
                                  └──────────────────────────┘
```

---

## 🛠️ AWS Services Used

1. **Amazon Bedrock**: Powering AI Skill Gap analysis, personalized roadmap generation, and context-aware AI Mentoring using foundation models (`amazon.nova-lite-v1:0` / `amazon.nova-pro-v1:0`).
2. **Amazon Cognito**: Managing user authentication, registration, password policies, and JWT token issuance.
3. **Amazon API Gateway**: Regional REST API gateway routing authenticated endpoints with CORS enforcement.
4. **AWS Lambda**: Serverless compute runtime handling business logic, Bedrock invocations, and database persistence.
5. **Amazon DynamoDB**: Multi-AZ NoSQL database storing user profiles, assessments, roadmaps, and progress state.
6. **Amazon CloudFront**: Global Anycast Edge CDN providing TLS 1.3 termination, caching, and low-latency global distribution.
7. **Amazon S3**: Storing deployment artifacts, static UI assets, and knowledge base reference material.
8. **Amazon CloudWatch**: Centralized structured logging, operational metrics, and error alarm tracking.

---

## 🤖 How the Coding Agent Helped

The application was designed, provisioned, tested, and deployed end-to-end using the **Antigravity AI Agent**:
- **Automated Control Plane**: Authored modular PowerShell scripts (`01-deploy-cognito.ps1` through `05-ship-gate-verification.ps1`) to provision AWS resources deterministically without manual console clicks.
- **Robust Schema Validation**: Engineered fail-safe parsers for Amazon Bedrock JSON outputs to guarantee 100% UI stability even if AI responses throttle.
- **Multi-Tier Quality Assurance**: Authored Jest unit tests, API contract tests, and security header tests.
- **Automated Ship-Gate Protocol**: Executed 6-step verification protocols validating live AWS endpoints.

---

## 🔒 Security Best Practices

- **Cognito User Pool Isolation**: User state is linked strictly to Cognito sub-claims.
- **IAM Least Privilege**: Lambda execution roles are scoped strictly to required Bedrock, DynamoDB, and CloudWatch operations.
- **Zero Hardcoded Secrets**: All AWS calls use IAM execution roles and environment configuration.
- **HTTP Security Headers**: Enforces `X-Content-Type-Options: nosniff`, `X-Frame-Options: DENY`, `Strict-Transport-Security`, and CORS policy.

---

## ⚡ Local Development

```bash
# 1. Clone repository
git clone https://github.com/user/skillbridge-ai.git
cd skillbridge-ai

# 2. Install dependencies
npm install

# 3. Run unit & contract test suite
node node_modules/jest/bin/jest.js --runInBand

# 4. Start local web server
npm start
# Open http://localhost:8080 in your browser
```

---

## 🚀 AWS Infrastructure Deployment

```powershell
# Deploy all AWS resources sequentially via AWS CLI control plane
powershell -ExecutionPolicy Bypass -File scripts/aws-cli/01-deploy-cognito.ps1
powershell -ExecutionPolicy Bypass -File scripts/aws-cli/02-deploy-dynamodb.ps1
powershell -ExecutionPolicy Bypass -File scripts/aws-cli/03-deploy-apprunner-api.ps1
powershell -ExecutionPolicy Bypass -File scripts/aws-cli/04-deploy-cloudfront-ui.ps1

# Run automated Ship-Gate verification test
powershell -ExecutionPolicy Bypass -File scripts/aws-cli/05-ship-gate-verification.ps1
```

---

## 🏆 Hackathon Category & Lane

- **Category:** `#social-good`
- **Lane:** `#community`
- **Focus:** Education & Workforce Development
