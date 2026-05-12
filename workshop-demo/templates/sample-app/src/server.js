const http = require("http");
const { buildMessage } = require("./app");

const port = process.env.PORT || 8080;

const server = http.createServer((request, response) => {
    if (request.url === "/health") {
        response.writeHead(200, { "Content-Type": "application/json" });
        response.end(JSON.stringify({ status: "ok" }));
        return;
    }

    response.writeHead(200, { "Content-Type": "application/json" });
    response.end(JSON.stringify({ message: buildMessage() }));
});

server.listen(port, () => {
    console.log(`Server listening on port ${port}`);
});