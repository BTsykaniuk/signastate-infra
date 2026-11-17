.PHONY: help up down ps logs logs-fe logs-be rebuild-all rebuild-fe rebuild-be reset-demo

# docker compose picks up docker-compose.yml and .env from this folder.
COMPOSE := docker compose

# Service names in docker-compose.yml, grouped by the repo they're built from:
# signestate gives the SPA and its demo API server, signastate-be the FastAPI backend.
FE := web api
BE := backend

help:
	@echo "Available commands:"
	@echo ""
	@echo "  Stack:"
	@echo "    make up                   - Start everything (builds images on the first run)"
	@echo "    make down                 - Stop and remove containers (volumes are kept)"
	@echo "    make ps                   - Show service status"
	@echo "    make logs                 - Tail logs of all services"
	@echo "    make logs-fe              - Tail frontend logs ($(FE))"
	@echo "    make logs-be              - Tail backend logs ($(BE), migrate)"
	@echo ""
	@echo "  Rebuild (picks up code and .env changes):"
	@echo "    make rebuild-all          - Rebuild FE + BE images, migrate, restart them"
	@echo "    make rebuild-fe           - Rebuild and restart the frontend only ($(FE))"
	@echo "    make rebuild-be           - Rebuild the backend, run migrations, restart it"
	@echo ""
	@echo "  Demo data:"
	@echo "    make reset-demo           - Reseed the demo database from the catalog (keeps uploads)"

# ── Stack ─────────────────────────────────────────────────────────────────────

up:
	$(COMPOSE) up -d

down:
	$(COMPOSE) down

ps:
	$(COMPOSE) ps -a

logs:
	$(COMPOSE) logs -f

logs-fe:
	$(COMPOSE) logs -f $(FE)

logs-be:
	$(COMPOSE) logs -f $(BE) migrate

# ── Rebuild ───────────────────────────────────────────────────────────────────

rebuild-all:
	$(COMPOSE) up -d --build

# --no-deps leaves the other services (and Traefik) running untouched.
rebuild-fe:
	$(COMPOSE) up -d --build --no-deps $(FE)

# No --no-deps here: the backend depends on migrate (and migrate on postgres),
# so this rebuilds both images and applies migrations before the new backend starts.
rebuild-be:
	$(COMPOSE) up -d --build $(BE)

# ── Demo data ─────────────────────────────────────────────────────────────────

# The api container seeds demo/db.json from the frontend's db.json only when the
# file is missing, so catalog changes in a new deploy need this to show up.
# Demo accounts, sessions and purchases are reset too.
reset-demo:
	$(COMPOSE) exec api rm -f /app/data/demo/db.json
	$(COMPOSE) restart api
