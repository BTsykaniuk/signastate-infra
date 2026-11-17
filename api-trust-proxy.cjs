// Preloaded into the frontend's Node server (`node --require`, Dockerfile `api`
// stage). Traefik terminates TLS and forwards plain HTTP, so Express sees every
// request as http://. The demo API compares the browser's Origin
// (https://APP_DOMAIN) with `${req.protocol}://${host}`, so it refused every
// sign-in and write with a 403, and its session cookie lost `Secure`.
//
// With "trust proxy", Express reads the scheme from Traefik's X-Forwarded-Proto.
// Trusting private addresses is safe: the container publishes no port, so only
// Traefik, on the compose network, can reach it. server.js has no setting for
// this, so json-server's create() is wrapped instead. server.js imports the same
// CommonJS module, so it gets the wrapped function.
const jsonServer = require("json-server")

const create = jsonServer.create
jsonServer.create = (...args) => create(...args).set("trust proxy", "loopback, linklocal, uniquelocal")
