FROM node:22-alpine

WORKDIR /app
COPY frontend/package*.json ./frontend/
RUN cd frontend && npm install
COPY frontend ./frontend

ENV PORT=3005
ENV HOST=0.0.0.0
ENV REACT_APP_API_URL=http://localhost:3006/api

RUN cd frontend && npm run build
RUN npm install -g serve

EXPOSE 3005
CMD ["sh", "-c", "cd frontend && serve -s build -l 3005"]
