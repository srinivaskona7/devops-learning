const http = require('http');
const os = require('os');

const port = process.env.PORT || 8080;

http.createServer((req, res) => {
  res.writeHead(200, { 'Content-Type': 'text/plain' });
  res.end(`Hello from distroless Node!\nHostname: ${os.hostname()}\n`);
}).listen(port, () => console.log(`listening on :${port}`));
