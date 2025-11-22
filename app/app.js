const http = require('http');

const PORT = process.env.PORT || 8080;
const MESSAGE = process.env.MESSAGE || 'Hello from EKS!';

const server = http.createServer((req, res) => {
  console.log(`${new Date().toISOString()} - ${req.method} ${req.url}`);

  if (req.url === '/health' || req.url === '/healthz') {
    res.writeHead(200, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({ status: 'healthy', timestamp: new Date().toISOString() }));
    return;
  }

  res.writeHead(200, { 'Content-Type': 'text/html' });
  res.end(`
    <!DOCTYPE html>
    <html>
    <head>
      <title>EKS Ready</title>
      <style>
        body {
          font-family: Arial, sans-serif;
          display: flex;
          justify-content: center;
          align-items: center;
          height: 100vh;
          margin: 0;
          background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
          color: white;
        }
        .container {
          text-align: center;
          padding: 2rem;
          background: rgba(255, 255, 255, 0.1);
          border-radius: 10px;
          backdrop-filter: blur(10px);
        }
        h1 { margin: 0 0 1rem 0; font-size: 3rem; }
        p { margin: 0.5rem 0; font-size: 1.2rem; }
        .info { font-size: 0.9rem; opacity: 0.8; margin-top: 2rem; }
      </style>
    </head>
    <body>
      <div class="container">
        <h1>🚀 ${MESSAGE}</h1>
        <p>Hostname: ${require('os').hostname()}</p>
        <p>Platform: ${process.platform}</p>
        <p>Node.js: ${process.version}</p>
        <div class="info">
          <p>Powered by Amazon EKS</p>
          <p>From Senora.dev</p>
        </div>
      </div>
    </body>
    </html>
  `);
});

server.listen(PORT, '0.0.0.0', () => {
  console.log(`Server running on port ${PORT}`);
  console.log(`Message: ${MESSAGE}`);
});

// Graceful shutdown
process.on('SIGTERM', () => {
  console.log('SIGTERM received, closing server...');
  server.close(() => {
    console.log('Server closed');
    process.exit(0);
  });
});
