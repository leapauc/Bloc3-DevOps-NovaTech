# HRFlow — Plateforme RH SaaS

Plateforme de gestion RH pour les PME françaises.

## Stack
- Frontend : React 18
- Backend : Node.js / Express
- BDD : PostgreSQL + Redis
- Infra : AWS

## Configuration

Le projet utilise des variables d'environnement pour sa configuration.

### Variables d'environnement

| Variable | Description | Exemple |
|---|---|---|
| `NODE_ENV` | Environnement d'exécution | `test` |
| `DB_NAME` | Nom de la base PostgreSQL | `hrflow_test` |
| `DB_USER` | Utilisateur PostgreSQL | `hrflow` |
| `DB_PORT` | Port PostgreSQL | `5434` |
| `GATEWAY_HOST_PORT` | Port du gateway | `3006` |
| `FRONTEND_HOST_PORT` | Port du frontend | `3007` |
| `CORS_ALLOWED_ORIGINS` | Origines autorisées par le CORS | `http://localhost:3007` |
| `REACT_APP_API_URL` | URL de l'API utilisée par le frontend | `http://localhost:3006/api` |
| `JWT_EXPIRY` | Durée de validité du JWT | `24h` |

### Secrets

Les variables suivantes sont sensibles et **ne doivent jamais être commitées dans le dépôt** :

- `AWS_ACCESS_KEY_ID`
- `AWS_REGION`
- `AWS_SECRET_ACCESS_KEY`
- `DB_PASSWORD`
- `JWT_REFRESH_SECRET`
- `JWT_SECRET`
- `REDIS_PASSWORD`
- `STRIPE_SECRET_KEY`

Pour le développement local, créez un fichier `.env` à partir du fichier `.env.example`.

Les secrets utilisés par les environnements CI/CD doivent être configurés dans les **GitHub Actions Secrets** du repository.

## Installation
```bash
docker compose --env-file .env.local up --build -d
```

## Déploiement
Voir Théo.

## Architecture
TODO — à documenter

## Tests
TODO

---
*Dernière mise à jour : mars 2022*
