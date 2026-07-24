# Déploiement AWS via Terraform

Cette structure propose un point de départ pour déployer l’application HRFlow sur AWS avec Terraform.

## Architecture cible

- ECR : stockage des images Docker
- VPC + subnets + security groups
- ALB : exposition du front et du gateway
- ECS Fargate : exécution des services backend
- RDS PostgreSQL : base de données
- ElastiCache Redis : cache/session
- CloudWatch Logs : journalisation

## Arborescence proposée

- `main.tf` : ressources AWS principales
- `variables.tf` : variables d’entrée
- `outputs.tf` : sorties Terraform
- `providers.tf` : configuration du provider AWS
- `versions.tf` : version des providers
- `terraform.tfvars.example` : exemple de valeurs

## Procédure

1. Installer Terraform.
2. Configurer les credentials AWS via `aws configure` ou un profile.
3. Ajuster `terraform.tfvars`.
4. Lancer :

```sh
terraform init
terraform plan
terraform apply
```

5. Pousser les images construite dans ECR.
6. Déployer les services ECS.

## Remarques

Ce dossier est une base de départ. Tu devras ensuite:
- ajouter les task definitions détaillées pour chaque service backend,
- connecter les variables d’environnement JWT, DB et Redis,
- définir le pipeline CI/CD pour la construction des images.
