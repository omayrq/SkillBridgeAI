/**
 * SkillBridge AI — Main AWS Lambda / API Handler
 */

const fs = require('fs');
const path = require('path');
const { analyzeSkillGapAndRoadmap, generateMentorReply } = require('./bedrock-service');
const { saveAssessmentAndRoadmap, getUserRoadmap, updateTaskProgress } = require('./dynamo-service');

const startTime = Date.now();

// Cache static assets
let htmlCache = null;
let cssCache = null;
let jsCache = null;

function loadStaticAssets() {
  if (!htmlCache) {
    const htmlPath = path.join(__dirname, '../frontend/index.html');
    htmlCache = fs.existsSync(htmlPath) ? fs.readFileSync(htmlPath, 'utf8') : '<h1>SkillBridge AI</h1>';
  }
  if (!cssCache) {
    const cssPath = path.join(__dirname, '../frontend/styles.css');
    cssCache = fs.existsSync(cssPath) ? fs.readFileSync(cssPath, 'utf8') : '';
  }
  if (!jsCache) {
    const jsPath = path.join(__dirname, '../frontend/app.js');
    jsCache = fs.existsSync(jsPath) ? fs.readFileSync(jsPath, 'utf8') : '';
  }
}

function createResponse(statusCode, body, contentType = 'application/json') {
  return {
    statusCode,
    headers: {
      'Content-Type': contentType,
      'Access-Control-Allow-Origin': '*',
      'Access-Control-Allow-Headers': 'Content-Type, Authorization, X-Amz-Date, X-Api-Key',
      'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS',
      'Cache-Control': 'no-cache',
      'X-Content-Type-Options': 'nosniff',
      'X-Frame-Options': 'DENY',
      'Strict-Transport-Security': 'max-age=31536000; includeSubDomains'
    },
    body: typeof body === 'object' ? JSON.stringify(body) : body
  };
}

exports.handler = async (event, context) => {
  loadStaticAssets();

  const method = event.httpMethod || (event.requestContext && event.requestContext.http && event.requestContext.http.method) || 'GET';
  const rawPath = event.path || (event.requestContext && event.requestContext.http && event.requestContext.http.path) || '/';
  
  // Extract user ID from Cognito Authorizer claims if available, else default guest
  const cognitoUserId = event.requestContext?.authorizer?.claims?.sub || event.requestContext?.authorizer?.jwt?.claims?.sub || 'demo-user-1';

  // Handle CORS OPTIONS pre-flight
  if (method === 'OPTIONS') {
    return createResponse(204, '');
  }

  // Serve Frontend UI Static Assets
  if (method === 'GET' && (rawPath === '/' || rawPath === '' || rawPath === '/index.html' || rawPath === '/dev' || rawPath === '/dev/')) {
    return createResponse(200, htmlCache, 'text/html; charset=utf-8');
  }

  if (method === 'GET' && rawPath.endsWith('/styles.css')) {
    return createResponse(200, cssCache, 'text/css; charset=utf-8');
  }

  if (method === 'GET' && rawPath.endsWith('/app.js')) {
    return createResponse(200, jsCache, 'application/javascript; charset=utf-8');
  }

  // API Route 1: Health Check GET /api/v1/status
  if (method === 'GET' && rawPath.endsWith('/status')) {
    return createResponse(200, {
      status: 'healthy',
      service: 'skillbridge-ai-api',
      version: '1.0.0',
      environment: process.env.ENVIRONMENT || 'dev',
      uptime: Math.floor((Date.now() - startTime) / 1000),
      bedrock: 'connected',
      dynamodb: 'connected',
      timestamp: new Date().toISOString()
    });
  }

  // Parse Body for POST endpoints
  let body = {};
  if (event.body) {
    try {
      body = typeof event.body === 'string' ? JSON.parse(event.body) : event.body;
    } catch (e) {
      return createResponse(400, { error: 'Bad Request', message: 'Invalid JSON payload' });
    }
  }

  // API Route 2: POST /api/v1/assessment — Process assessment & invoke Bedrock
  if (method === 'POST' && rawPath.includes('/assessment')) {
    const { name, currentRole, experienceLevel, currentSkills, targetRole, weeklyHours } = body;

    if (!currentSkills || !targetRole) {
      return createResponse(400, { error: 'Bad Request', message: 'Missing required fields: currentSkills, targetRole' });
    }

    const result = await analyzeSkillGapAndRoadmap(body);
    await saveAssessmentAndRoadmap(cognitoUserId, body, result.skillGap, result.roadmap);

    return createResponse(200, {
      userId: cognitoUserId,
      assessment: body,
      skillGap: result.skillGap,
      roadmap: result.roadmap,
      timestamp: new Date().toISOString()
    });
  }

  // API Route 3: GET /api/v1/roadmap — Fetch user roadmap
  if (method === 'GET' && rawPath.includes('/roadmap')) {
    const data = await getUserRoadmap(cognitoUserId);
    if (!data) {
      return createResponse(404, { error: 'Not Found', message: 'No roadmap found for user.' });
    }
    return createResponse(200, data);
  }

  // API Route 4: POST /api/v1/mentor — AI Mentor Q&A Endpoint
  if (method === 'POST' && rawPath.includes('/mentor')) {
    const { prompt, context } = body;
    if (!prompt) {
      return createResponse(400, { error: 'Bad Request', message: 'Missing required field: prompt' });
    }

    const reply = await generateMentorReply(prompt, context || 'AWS Solutions Architect');
    return createResponse(200, {
      reply,
      timestamp: new Date().toISOString()
    });
  }

  // API Route 5: POST /api/v1/progress — Update task completion status
  if (method === 'POST' && rawPath.includes('/progress')) {
    const { taskId, completed } = body;
    if (!taskId) {
      return createResponse(400, { error: 'Bad Request', message: 'Missing taskId' });
    }

    const updated = await updateTaskProgress(cognitoUserId, taskId, completed !== false);
    return createResponse(200, { success: updated, taskId, completed: completed !== false });
  }

  // Fallback 404
  return createResponse(404, { error: 'Not Found', message: `Route not found for ${method} ${rawPath}` });
};
