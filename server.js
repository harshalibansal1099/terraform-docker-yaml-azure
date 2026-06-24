const http = require('http');
const server = http.createServer((req, res) => {
    res.writeHead(200, {'Content-Type': 'text/plain'});
    res.end('Hello Brother! Our Terraform Project is now LIVE via GITHUB ACTIONS & DOCKER! 🐳🚀\n');
});
server.listen(3000, '0.0.0.0');