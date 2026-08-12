FROM node:22-alpine

WORKDIR /app
COPY services/api-gateway/package*.json ./services/api-gateway/
RUN cd services/api-gateway && npm ci --omit=dev
COPY services/api-gateway/src ./services/api-gateway/src

EXPOSE 3000
CMD ["node", "services/api-gateway/src/index.js"]
