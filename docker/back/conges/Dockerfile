FROM node:22-alpine

WORKDIR /app
COPY services/conges/package*.json ./services/conges/
RUN cd services/conges && npm install --omit=dev
COPY services/conges/src ./services/conges/src

EXPOSE 3003
CMD ["node", "services/conges/src/index.js"]
