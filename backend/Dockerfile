# Multi-stage build pour optimiser l'image de production

# Stage 1: Base image avec les dépendances
FROM node:18-alpine AS base

# Installer les dépendances système nécessaires
RUN apk add --no-cache \
    sqlite \
    wget \
    curl \
    dumb-init

# Créer un utilisateur non-root pour la sécurité
RUN addgroup -g 1001 -S nodejs
RUN adduser -S nodejs -u 1001

# Définir le répertoire de travail
WORKDIR /app

# Copier les fichiers de dépendances
COPY package*.json ./

# Stage 2: Development
FROM base AS development
ENV NODE_ENV=development
RUN npm ci --include=dev
COPY . .
RUN chown -R nodejs:nodejs /app
USER nodejs
EXPOSE 3000 9229
CMD ["npm", "run", "dev"]

# Stage 3: Build pour la production
FROM base AS build
ENV NODE_ENV=production
RUN npm ci --only=production && npm cache clean --force

# Stage 4: Production finale
FROM node:18-alpine AS production

# Installer dumb-init pour la gestion des signaux
RUN apk add --no-cache dumb-init wget

# Créer un utilisateur non-root
RUN addgroup -g 1001 -S nodejs
RUN adduser -S nodejs -u 1001

# Définir le répertoire de travail
WORKDIR /app

# Copier les dépendances depuis le stage build
COPY --from=build --chown=nodejs:nodejs /app/node_modules ./node_modules

# Copier le code de l'application
COPY --chown=nodejs:nodejs . .

# Créer le répertoire pour la base de données avec les bonnes permissions
RUN mkdir -p data logs && chown -R nodejs:nodejs data logs

# Changer vers l'utilisateur non-root
USER nodejs

# Exposer le port
EXPOSE 3000

# Définir les variables d'environnement par défaut
ENV NODE_ENV=production
ENV PORT=3000
ENV DATABASE_PATH=/app/data/database.db

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=30s --retries=3 \
  CMD wget --no-verbose --tries=1 --spider http://localhost:3000/health || exit 1

# Utiliser dumb-init pour une gestion propre des signaux
ENTRYPOINT ["dumb-init", "--"]

# Commande pour démarrer l'application
CMD ["node", "server.js"]
