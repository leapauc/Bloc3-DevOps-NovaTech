FROM node:22-alpine

# Définir le répertoire de travail comme /app/services/paie
WORKDIR /app/services/paie

# Copier les fichiers package.json et package-lock.json
COPY services/paie/package*.json ./

# Installer les dépendances
RUN npm ci --omit=dev

# Copier le reste des fichiers
COPY services/paie/src ./src
COPY services/paie/swagger.js ./

# Exposer le port
EXPOSE 3002

# Lancer l'application depuis /app/services/paie
CMD ["node", "src/index.js"]