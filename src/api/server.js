/**
 * SkillBridge AI — Standalone HTTP Server for AWS App Runner / Local Execution
 */

const http = require('http');
const url = require('url');
const { handler } = require('./index');

const PORT = process.env.PORT || 8080;

const server = http.createServer(async (req, res) => {
  const parsedUrl = url.parse(req.url, true);

  let body = '';
  req.on('data', chunk => {
    body += chunk;
  });

  req.on('end', async () => {
    const event = {
      httpMethod: req.method,
      path: parsedUrl.pathname,
      queryStringParameters: parsedUrl.query,
      headers: req.headers,
      body: body || null
    };

    try {
      const result = await handler(event, {});

      const headers = result.headers || {};
      for (const [key, val] of Object.entries(headers)) {
        res.setHeader(key, val);
      }

      res.statusCode = result.statusCode || 200;
      res.end(result.body || '');
    } catch (err) {
      console.error('[SkillBridge Server Error]:', err);
      res.statusCode = 500;
      res.setHeader('Content-Type', 'application/json');
      res.end(JSON.stringify({ error: 'Internal Server Error', message: err.message }));
    }
  });
});

server.listen(PORT, '0.0.0.0', () => {
  console.log(`[SkillBridge AI Server] Listening on http://0.0.0.0:${PORT}`);
});
