# syntax=docker/dockerfile:1
# Build context is this folder (only nginx.conf is used from it). The frontend
# repo comes in as the named context `signestate` (FE_DIR in docker-compose.yml),
# so no path here depends on what either folder is called.

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

# ---- api: json-server + uploads (signestate/server.js) ----
FROM node:24-alpine AS api
WORKDIR /app
ENV NODE_ENV=production
# json-server is a devDependency, so reuse the full install from `deps`.
COPY --from=deps /app/node_modules ./node_modules
COPY --from=signestate package.json server.js ./
# server.js imports the notary slot logic it shares with the frontend tests.
COPY --from=signestate scripts/notary-slots.mjs ./scripts/
# server.js resolves db.json and public/uploads against the working directory,
# so running from /app/data keeps all mutable state under one path. A named
# volume mounted there is seeded with this db.json the first time it's created.
COPY --from=signestate db.json ./data/db.json
RUN mkdir -p data/public/uploads && chown -R node:node data
USER node
WORKDIR /app/data
EXPOSE 3001
CMD ["node", "/app/server.js"]
