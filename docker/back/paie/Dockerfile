FROM node:22-alpine

WORKDIR /app
COPY services/paie/package*.json ./services/paie/
RUN cd services/paie && npm install --omit=dev
COPY services/paie/src ./services/paie/src

EXPOSE 3002
CMD ["node", "services/paie/src/index.js"]
