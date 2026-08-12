FROM node:22-alpine

WORKDIR /app
COPY services/recrutement/package*.json ./services/recrutement/
RUN cd services/recrutement && npm ci --omit=dev
COPY services/recrutement/src ./services/recrutement/src

EXPOSE 3004
CMD ["node", "services/recrutement/src/index.js"]
