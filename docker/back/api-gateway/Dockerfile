FROM node:22-alpine

# Définir le répertoire de travail comme /app/services/api-gateway
WORKDIR /app/services/api-gateway

# Copier les fichiers package.json et package-lock.json
COPY services/api-gateway/package*.json ./

# Installer les dépendances
RUN npm ci --omit=dev

# Copier le reste des fichiers
COPY services/api-gateway/src ./src
COPY services/api-gateway/swagger.js ./

# Exposer le port
EXPOSE 3000

# Lancer l'application depuis /app/services/api-gateway
CMD ["node", "src/index.js"]