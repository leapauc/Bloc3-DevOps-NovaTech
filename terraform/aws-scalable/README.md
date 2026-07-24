# AWS scalable deployment with Terraform

This folder proposes a Terraform structure designed for differentiated scaling of the frontend, gateway and backend services.

## Structure

- `main.tf` : root composition of AWS resources and modules
- `variables.tf` : shared variables and per-service scaling inputs
- `outputs.tf` : outputs for endpoints and repository URLs
- `providers.tf` : AWS provider configuration
- `versions.tf` : required Terraform and provider versions
- `terraform.tfvars.example` : example values
- `modules/ecs_service/` : reusable ECS/Fargate service module

## Scaling strategy

Each service behind the gateway can be configured independently:
- `frontend` : internet-facing, public access
- `gateway` : internet-facing entry point, usually the most requested route
- `auth` : medium scale, authentication traffic
- `conges`, `paie`, `recrutement` : more specialized scaling, often lower traffic than gateway

## Recommended workflow

1. Configure AWS credentials
2. Copy `terraform.tfvars.example` to `terraform.tfvars`
3. Run `terraform init`
4. Run `terraform plan`
5. Run `terraform apply`

## Notes

This scaffold is intentionally modular so you can later tailor CPU, memory, autoscaling and target groups for each service independently.
