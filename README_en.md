# HRFlow — Plateforme RH SaaS


[🇫🇷 Français](README.md) · [🇬🇧 English](README_en.md)

SaaS HR management platform for French SMEs.

## 🛠️ Tech Stack

| Domain | Technologies |
|---|---|
| 🎨 **Frontend** | React 18 |
| ⚙️ **Backend** | Node.js · Express |
| 🗄️ **Database** | PostgreSQL |
| ⚡ **Cache** | Redis |
| ☁️ **Cloud** | AWS |
| 🏗️ **Infrastructure as Code** | Terraform |

<p align="center">
  <img src="https://img.shields.io/badge/React_18-20232A?style=for-the-badge&logo=react&logoColor=61DAFB" />
  <img src="https://img.shields.io/badge/Node.js-339933?style=for-the-badge&logo=node.js&logoColor=white" />
  <img src="https://img.shields.io/badge/Express-000000?style=for-the-badge&logo=express&logoColor=white" />
  <img src="https://img.shields.io/badge/PostgreSQL-4169E1?style=for-the-badge&logo=postgresql&logoColor=white" />
  <img src="https://img.shields.io/badge/Redis-DC382D?style=for-the-badge&logo=redis&logoColor=white" />
  <img src="https://img.shields.io/badge/AWS-232F3E?style=for-the-badge&logo=amazonwebservices&logoColor=white" />
  <img src="https://img.shields.io/badge/Terraform-844FBA?style=for-the-badge&logo=terraform&logoColor=white" />
</p>


## Configuration

The project uses environment variables for its configuration.

### Environnement variables

| Variable | Description | Example |
|---|---|---|
| `NODE_ENV` | Runtime environnement | `test` |
| `DB_NAME` | PostgreSQL database name | `hrflow_test` |
| `DB_USER` | PostgreSQL user | `hrflow` |
| `DB_PORT` | PostgreSQL port | `5434` |
| `GATEWAY_HOST_PORT` | API Gateway port | `3006` |
| `FRONTEND_HOST_PORT` | Frontend port | `3007` |
| `CORS_ALLOWED_ORIGINS` | Origins allowed by CORS | `http://localhost:3007` |
| `REACT_APP_API_URL` | API URL used by the frontend | `http://localhost:3006/api` |
| `JWT_EXPIRY` | JWT validity duration | `24h` |

### Secrets

The following variables contain sensitive information and **must never be committed to the repository** :

- `AWS_ACCESS_KEY_ID`
- `AWS_REGION`
- `AWS_SECRET_ACCESS_KEY`
- `DB_PASSWORD`
- `JWT_REFRESH_SECRET`
- `JWT_SECRET`
- `REDIS_PASSWORD`
- `STRIPE_SECRET_KEY`

For local development, create a .env file based on the .env.example file.

Secrets used by CI/CD environments must be configured in the repository's **GitHub Actions Secrets**.

## Installation
### en local
```bash
docker compose --env-file .env.local up --build -d
```

### documentation API via le conteneur docker
The API Gateway and each service provide their own Swagger documentation:

| Service | Swagger Documentation URL |
| --- | --- |
| API Gateway | [http://localhost:3006/api-docs](http://localhost:3006/api-docs) |
| Auth | [http://localhost:3001/api-docs](http://localhost:3001/api-docs) |
| Congés | [http://localhost:3003/api-docs](http://localhost:3003/api-docs) |
| Paie | [http://localhost:3002/api-docs](http://localhost:3002/api-docs) |
| Recrutement | [http://localhost:3004/api-docs](http://localhost:3004/api-docs) |


## Déploiement
See Théo.

## Architecture

<p align="center">
  <img src="./docs/imgs/architecture.png" alt="HRFlow Architecture" width="900">
</p>

## Tests
TODO

---
Last updated: August 2026