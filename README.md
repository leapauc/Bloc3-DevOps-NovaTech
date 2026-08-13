# HRFlow — Plateforme RH SaaS

Plateforme de gestion RH pour les PME françaises.

## 🛠️ Stack

| Domaine | Technologies |
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
### en local
```bash
docker compose --env-file .env.local up --build -d
```

### documentation API via le conteneur docker
L'api-gateway et les services ont chacun leur documentation :

| Service | URL de la documentation Swagger |
| --- | --- |
| API Gateway | [http://localhost:3006/api-docs](http://localhost:3006/api-docs) |
| Auth | [http://localhost:3001/api-docs](http://localhost:3001/api-docs) |
| Congés | [http://localhost:3003/api-docs](http://localhost:3003/api-docs) |
| Paie | [http://localhost:3002/api-docs](http://localhost:3002/api-docs) |
| Recrutement | [http://localhost:3004/api-docs](http://localhost:3004/api-docs) |


## Déploiement
Voir Théo.

## Architecture



```mermaid
flowchart LR

    U["👤 Utilisateur"]
    F["🎨 React 18<br/>Frontend"]
    G["🚪 API Gateway<br/>Node.js / Express"]

    A["🔐 Auth"]
    P["💰 Paie"]
    C["🏖️ Congés"]
    R["👥 Recrutement"]

    DB[("🐘 PostgreSQL")]
    REDIS[("⚡ Redis")]

    T["🏗️ Terraform<br/>Infrastructure as Code"]
    AWS["☁️ AWS"]

    U --> F
    F -->|"HTTP / REST"| G

    G --> A
    G --> P
    G --> C
    G --> R

    A --> DB
    P --> DB
    C --> DB
    R --> DB

    A --> REDIS
    P --> REDIS
    C --> REDIS
    R --> REDIS

    T -.->|"Provisionne"| AWS
    AWS -.-> F
    AWS -.-> G
    AWS -.-> A
    AWS -.-> P
    AWS -.-> C
    AWS -.-> R
    AWS -.-> DB
    AWS -.-> REDIS
```

## Tests
TODO

---
*Dernière mise à jour : mars 2022*
