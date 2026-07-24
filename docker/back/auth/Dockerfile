FROM node:22-alpine

WORKDIR /app
COPY services/auth/package*.json ./services/auth/
RUN cd services/auth && npm install --omit=dev
COPY services/auth/src ./services/auth/src

EXPOSE 3001
CMD ["node", "services/auth/src/index.js"]
