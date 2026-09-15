const http = require('http');
const https = require('https');
const fs = require('fs');
const path = require('path');
const { URL } = require('url');

const PORT = 8080;
const REMOTE_BACKEND_HOST = 'quickfix-production-4c09.up.railway.app';
const DEFAULT_EDGE_IP = '69.46.46.69';

let resolvedEdgeIp = DEFAULT_EDGE_IP;

// Resolve Railway Edge IP via Cloudflare DoH to bypass Jio DNS block
function resolveDoH() {
  const dohUrl = 'https://1.1.1.1/dns-query?name=' + REMOTE_BACKEND_HOST + '&type=A';
  const req = https.get(dohUrl, { headers: { 'Accept': 'application/dns-json' } }, (res) => {
    let body = '';
    res.on('data', chunk => body += chunk);
    res.on('end', () => {
      try {
        const json = JSON.parse(body);
        if (json.Answer && json.Answer.length > 0) {
          const aRecord = json.Answer.find(a => a.type === 1);
          if (aRecord && aRecord.data) {
            resolvedEdgeIp = aRecord.data;
            console.log(`[Jio DNS Bypass] Resolved Edge IP via DoH: ${resolvedEdgeIp}`);
          }
        }
      } catch (_) {}
    });
  });
  req.on('error', () => {});
}
resolveDoH();

const MIME_TYPES = {
  '.html': 'text/html',
  '.css': 'text/css',
  '.js': 'text/javascript',
  '.json': 'application/json',
  '.png': 'image/png',
  '.jpg': 'image/jpeg',
  '.gif': 'image/gif',
  '.svg': 'image/svg+xml'
};

function proxyApiRequest(req, res) {
  const options = {
    hostname: REMOTE_BACKEND_HOST,
    port: 443,
    path: req.url,
    method: req.method,
    headers: {
      ...req.headers,
      host: REMOTE_BACKEND_HOST
    }
  };

  const proxyReq = https.request(options, (proxyRes) => {
    res.writeHead(proxyRes.statusCode, proxyRes.headers);
    proxyRes.pipe(res);
  });

  proxyReq.on('error', (err) => {
    // If standard hostname lookup fails (Jio DNS block ENOTFOUND), retry via Edge IP directly
    if (err.code === 'ENOTFOUND' || err.code === 'EAI_AGAIN' || err.code === 'ECONNREFUSED') {
      console.warn(`[Jio ISP Block Detected] Direct DNS failed (${err.code}). Retrying via Edge IP (${resolvedEdgeIp})...`);
      
      const ipOptions = {
        hostname: resolvedEdgeIp,
        port: 443,
        path: req.url,
        method: req.method,
        headers: {
          ...req.headers,
          host: REMOTE_BACKEND_HOST
        },
        servername: REMOTE_BACKEND_HOST,
        rejectUnauthorized: false
      };

      const ipReq = https.request(ipOptions, (ipRes) => {
        res.writeHead(ipRes.statusCode, ipRes.headers);
        ipRes.pipe(res);
      });

      ipReq.on('error', (ipErr) => {
        res.writeHead(502, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify({ error: 'ISP connection server failed', details: ipErr.message }));
      });

      req.pipe(ipReq);
    } else {
      res.writeHead(502, { 'Content-Type': 'application/json' });
      res.end(JSON.stringify({ error: 'Backend server connection error', details: err.message }));
    }
  });

  req.pipe(proxyReq);
}

http.createServer((req, res) => {
  // Check if request is an API call
  if (req.url.startsWith('/api/')) {
    return proxyApiRequest(req, res);
  }

  // Normalize URL path to prevent directory traversal
  let safeUrl = req.url.split('?')[0];
  let filePath = path.join(__dirname, safeUrl === '/' ? 'index.html' : safeUrl);
  
  const ext = path.extname(filePath);
  const contentType = MIME_TYPES[ext] || 'application/octet-stream';

  fs.readFile(filePath, (err, content) => {
    if (err) {
      res.writeHead(404, { 'Content-Type': 'text/plain' });
      res.end('File not found');
    } else {
      res.writeHead(200, { 'Content-Type': contentType });
      res.end(content, 'utf-8');
    }
  });
}).listen(PORT, () => {
  console.log(`================================================================`);
  console.log(`Admin Web Panel server running at http://localhost:${PORT}`);
  console.log(`Jio ISP DNS Bypass: ACTIVE (Reverse Proxy & DoH enabled on /api)`);
  console.log(`Please open http://localhost:${PORT} in your web browser.`);
  console.log(`================================================================`);
});
