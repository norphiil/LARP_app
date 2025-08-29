# Makefile pour simplifier les commandes Docker

# Variables
COMPOSE_FILE := docker-compose.yml
DEV_COMPOSE_FILE := docker-compose.dev.yml
BACKEND_SERVICE := flutter-backend
DEV_BACKEND_SERVICE := flutter-backend-dev

# Commandes par défaut
.PHONY: help
help: ## Afficher cette aide
	@echo "Commandes disponibles :"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}'

# Development
.PHONY: dev-build
dev-build: ## Construire l'image de développement
	docker-compose -f $(DEV_COMPOSE_FILE) build

.PHONY: dev-up
dev-up: ## Démarrer en mode développement
	docker-compose -f $(DEV_COMPOSE_FILE) up

.PHONY: dev-up-d
dev-up-d: ## Démarrer en arrière-plan en mode développement
	docker-compose -f $(DEV_COMPOSE_FILE) up -d

.PHONY: dev-down
dev-down: ## Arrêter les services de développement
	docker-compose -f $(DEV_COMPOSE_FILE) down

.PHONY: dev-logs
dev-logs: ## Voir les logs du développement
	docker-compose -f $(DEV_COMPOSE_FILE) logs -f

.PHONY: dev-restart
dev-restart: ## Redémarrer les services de développement
	docker-compose -f $(DEV_COMPOSE_FILE) restart

# Production
.PHONY: build
build: ## Construire l'image de production
	docker-compose -f $(COMPOSE_FILE) build

.PHONY: up
up: ## Démarrer en production
	docker-compose -f $(COMPOSE_FILE) up

.PHONY: up-d
up-d: ## Démarrer en arrière-plan en production
	docker-compose -f $(COMPOSE_FILE) up -d

.PHONY: down
down: ## Arrêter les services de production
	docker-compose -f $(COMPOSE_FILE) down

.PHONY: logs
logs: ## Voir les logs de production
	docker-compose -f $(COMPOSE_FILE) logs -f

.PHONY: restart
restart: ## Redémarrer les services de production
	docker-compose -f $(COMPOSE_FILE) restart

# Gestion des données
.PHONY: backup
backup: ## Sauvegarder la base de données
	docker-compose -f $(COMPOSE_FILE) exec $(BACKEND_SERVICE) cp /app/data/database.db /app/data/database-backup-$$(date +%Y%m%d_%H%M%S).db

.PHONY: clean
clean: ## Nettoyer les images et volumes inutilisés
	docker system prune -f
	docker volume prune -f

.PHONY: clean-all
clean-all: ## Nettoyer tout (ATTENTION: supprime tous les volumes)
	docker-compose -f $(COMPOSE_FILE) down -v
	docker-compose -f $(DEV_COMPOSE_FILE) down -v
	docker system prune -af
	docker volume prune -f

# Debug et maintenance
.PHONY: shell
shell: ## Ouvrir un shell dans le conteneur de production
	docker-compose -f $(COMPOSE_FILE) exec $(BACKEND_SERVICE) sh

.PHONY: dev-shell
dev-shell: ## Ouvrir un shell dans le conteneur de développement
	docker-compose -f $(DEV_COMPOSE_FILE) exec $(DEV_BACKEND_SERVICE) sh

.PHONY: health
health: ## Vérifier la santé du service
	curl -f http://localhost:3000/health || echo "Service not healthy"

.PHONY: status
status: ## Afficher le statut des conteneurs
	docker-compose -f $(COMPOSE_FILE) ps
