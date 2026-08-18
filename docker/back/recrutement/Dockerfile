FROM node:22-alpine

# Définir le répertoire de travail comme /app/services/recrutement
WORKDIR /app/services/recrutement

# Copier les fichiers package.json et package-lock.json
COPY services/recrutement/package*.json ./

# Installer les dépendances
RUN npm ci --omit=dev

# Copier le reste des fichiers
COPY services/recrutement/src ./src
COPY services/recrutement/swagger.js ./

# Exposer le port
EXPOSE 3004

# Lancer l'application depuis /app/services/recrutement
CMD ["node", "src/index.js"]