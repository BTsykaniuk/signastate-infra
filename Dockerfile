# syntax=docker/dockerfile:1
# Build context is the parent folder (see docker-compose.yml): the app lives
# in ./signestate and this file in ./infra.

# ---- deps: install the full dependency tree once, shared by build and api ----
FROM node:24-alpine AS deps
WORKDIR /app
RUN npm install -g pnpm@11
COPY signestate/package.json signestate/pnpm-lock.yaml signestate/pnpm-workspace.yaml ./
RUN pnpm install --frozen-lockfile

# ---- build: compile the Vite app into static files ----
FROM deps AS build
# VITE_* values are inlined into the bundle at build time, so they must be
# build args rather than runtime env vars.
ARG VITE_GOOGLE_MAPS_API_KEY=""
ARG VITE_GOOGLE_MAPS_MAP_ID="DEMO_MAP_ID"
COPY signestate/ ./
RUN pnpm build

# ---- web: serve the built SPA with nginx ----
FROM nginx:1.29-alpine AS web
COPY infra/nginx.conf /etc/nginx/conf.d/default.conf
COPY --from=build /app/dist /usr/share/nginx/html

# ---- api: json-server + uploads (signestate/server.js) ----
FROM node:24-alpine AS api
WORKDIR /app
ENV NODE_ENV=production
# json-server is a devDependency, so reuse the full install from `deps`.
COPY --from=deps /app/node_modules ./node_modules
COPY signestate/package.json signestate/server.js ./
# server.js imports the notary slot logic it shares with the frontend tests.
COPY signestate/scripts/notary-slots.mjs ./scripts/
# server.js resolves db.json and public/uploads against the working directory,
# so running from /app/data keeps all mutable state under one path. A named
# volume mounted there is seeded with this db.json the first time it's created.
COPY signestate/db.json ./data/db.json
RUN mkdir -p data/public/uploads && chown -R node:node data
USER node
WORKDIR /app/data
EXPOSE 3001
CMD ["node", "/app/server.js"]
