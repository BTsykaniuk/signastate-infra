.PHONY: help up down ps logs logs-fe logs-be rebuild-all rebuild-fe rebuild-be

# docker compose picks up docker-compose.yml and .env from this folder.
COMPOSE := docker compose

# Service names in docker-compose.yml.
FE := web
BE := api

help:
	@echo "Available commands:"
	@echo ""
	@echo "  Stack:"
	@echo "    make up                   - Start everything (builds images on the first run)"
	@echo "    make down                 - Stop and remove containers (volumes are kept)"
	@echo "    make ps                   - Show service status"
	@echo "    make logs                 - Tail logs of all services"
	@echo "    make logs-fe              - Tail frontend ($(FE)) logs"
	@echo "    make logs-be              - Tail backend ($(BE)) logs"
	@echo ""
	@echo "  Rebuild (picks up code and .env changes):"
	@echo "    make rebuild-all          - Rebuild FE + BE images and restart them"
	@echo "    make rebuild-fe           - Rebuild and restart the frontend only"
	@echo "    make rebuild-be           - Rebuild and restart the backend only"

# ── Stack ─────────────────────────────────────────────────────────────────────

up:
	$(COMPOSE) up -d

down:
	$(COMPOSE) down

ps:
	$(COMPOSE) ps

logs:
	$(COMPOSE) logs -f

logs-fe:
	$(COMPOSE) logs -f $(FE)

logs-be:
	$(COMPOSE) logs -f $(BE)

# ── Rebuild ───────────────────────────────────────────────────────────────────

rebuild-all:
	$(COMPOSE) up -d --build

# --no-deps leaves the other services (and Traefik) running untouched.
rebuild-fe:
	$(COMPOSE) up -d --build --no-deps $(FE)

rebuild-be:
	$(COMPOSE) up -d --build --no-deps $(BE)
