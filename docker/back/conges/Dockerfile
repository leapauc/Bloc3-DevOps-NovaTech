FROM node:22-alpine

# Définir le répertoire de travail
WORKDIR /app/services/conges

# Copier les fichiers package.json et package-lock.json
COPY services/conges/package*.json ./

# Installer les dépendances (y compris swagger-jsdoc)
RUN npm ci --omit=dev

# Copier le reste des fichiers
COPY services/conges/src ./src
COPY services/conges/swagger.js ./

# Exposer le port
EXPOSE 3003

# Lancer l'application
CMD ["node", "src/index.js"]