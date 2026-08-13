FROM node:22-alpine

# Définir le répertoire de travail comme /app/services/auth
WORKDIR /app/services/auth

# Copier les fichiers package.json et package-lock.json
COPY services/auth/package*.json ./

# Installer les dépendances
RUN npm ci --omit=dev

# Copier le reste des fichiers
COPY services/auth/src ./src
COPY services/auth/swagger.js ./

# Exposer le port
EXPOSE 3001

# Lancer l'application depuis /app/services/auth
CMD ["node", "src/index.js"]