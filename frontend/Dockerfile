FROM node:22-alpine

WORKDIR /app
COPY package*.json ./
RUN npm install
COPY . .

ENV PORT=3005
ENV HOST=0.0.0.0
ENV REACT_APP_API_URL=http://localhost:3006/api

RUN npm run build
RUN npm install -g serve

EXPOSE 3005
CMD ["serve", "-s", "build", "-l", "3005"]
