# syntax=docker/dockerfile:1
# Build context is this folder (only nginx.conf and api-trust-proxy.cjs are
# used from it). The frontend repo comes in as the named context `signestate`
# (FE_DIR in docker-compose.yml), so no path here depends on what either folder
# is called.

# ---- deps: install the full dependency tree once, shared by build and api ----
FROM node:24-alpine AS deps
WORKDIR /app
RUN npm install -g pnpm@11
COPY --from=signestate package.json pnpm-lock.yaml pnpm-workspace.yaml ./
RUN pnpm install --frozen-lockfile

# ---- build: compile the Vite app into static files ----
FROM deps AS build
# VITE_* values are inlined into the bundle at build time, so they must be
# build args rather than runtime env vars.
ARG VITE_GOOGLE_MAPS_API_KEY=""
ARG VITE_GOOGLE_MAPS_MAP_ID="DEMO_MAP_ID"
# A named context only honours a .dockerignore inside itself, and the frontend
# repo has none, so its local-only files are left out here instead.
COPY --from=signestate \
     --exclude=**/node_modules --exclude=**/dist --exclude=**/dist-ssr \
     --exclude=**/.git --exclude=**/.env --exclude=**/.env.* \
     --exclude=public/uploads --exclude=.scratch --exclude=.vscode --exclude=.idea \
     --exclude=**/.DS_Store --exclude=**/*.log \
     . ./
RUN pnpm build

# ---- web: serve the built SPA with nginx ----
FROM nginx:1.29-alpine AS web
COPY nginx.conf /etc/nginx/conf.d/default.conf
COPY --from=build /app/dist /usr/share/nginx/html

# ---- api: the frontend's Node server (signestate/server.js) ----
FROM node:24-alpine AS api
WORKDIR /app
ENV NODE_ENV=production
# json-server is a devDependency, so reuse the full install from `deps`.
COPY --from=deps /app/node_modules ./node_modules
# db.json is the sample catalog the demo database is seeded from (read only).
COPY --from=signestate package.json server.js db.json ./
# server.js imports modules from scripts/, and scripts/loan-requests.mjs imports
# a schema from src/ (a .ts file, which Node 24 runs by stripping its types).
# Both folders are copied whole so a new import there doesn't break the server.
COPY --from=signestate scripts ./scripts
COPY --from=signestate src ./src
COPY api-trust-proxy.cjs ./
# Mutable state lives under /app/data, where docker-compose.yml mounts a volume:
# the demo database (seeded from /app/db.json when the file is missing) and
# uploads. These paths assume BACKEND_MODE=demo (set in docker-compose.yml).
ENV SIGNESTATE_DB_FILE=/app/data/demo/db.json \
    SIGNESTATE_PUBLIC_DIR=/app/data/public
RUN mkdir -p data/demo data/public/uploads && chown -R node:node data
USER node
EXPOSE 3001
CMD ["node", "--require", "./api-trust-proxy.cjs", "server.js"]
