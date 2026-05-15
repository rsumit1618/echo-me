export default function handler(_, res) {
  sendJson(res, 200, {
    ok: true,
    service: 'Echo Me AI Server',
    health: '/api/health',
  });
}

function sendJson(res, statusCode, body) {
  res.statusCode = statusCode;
  res.setHeader('Content-Type', 'application/json');
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.end(JSON.stringify(body));
}
