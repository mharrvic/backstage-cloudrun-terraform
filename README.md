# [Terraform with CloudRun backstage](https://www.mharrvic.com/notes/backstage-deploy-with-cloudrun-via-terraform)

## Requirements

- Terraform CLI - [https://developer.hashicorp.com/terraform/cli/commands](https://developer.hashicorp.com/terraform/cli/commands)
  - If you are using M1 mac and having a trouble setting up, you can follow this GIST [https://gist.github.com/mharrvic/12b46934c608b0e21d6dd3e9fdeb1669](https://gist.github.com/mharrvic/12b46934c608b0e21d6dd3e9fdeb1669)
- GCLOUD CLI - [https://cloud.google.com/sdk/gcloud](https://cloud.google.com/sdk/gcloud)

## Get Started

Setup backstage app to your local machine [https://backstage.io/docs/getting-started/create-an-app](https://backstage.io/docs/getting-started/create-an-app)

1. Set Variables (for a more readable command), paste this to your terminal

   ```bash
   export PROJECT_ID=your-gcp-project-id
   export REGION=us-west1
   export REPO_NAME=backstage
   ```

2. Enable GCloud API Services

   ```bash
   gcloud services enable \
   	artifactregistry.googleapis.com/ \
   	run.googleapis.com/ \
   	compute.googleapis.com/ \
   	vpcaccess.googleapis.com/ \
   	servicenetworking.googleapis.com/ \
   	secretmanager.googleapis.com/ \
   	sqladmin.googleapis.com/ \
   	cloudbuild.googleapis.com/
   ```

3. Create artifact registry (to store the backstage docker image)

   ```bash
   gcloud artifacts repositories create ${REPO_NAME} --repository-format=docker \
   --location=${REGION} --description="Docker image for backstage"
   ```

4. Create a secret value for environment variables

   ```bash
   gcloud secrets create POSTGRES_PASSWORD \
       --replication-policy="automatic"
   echo -n "your-db-password-here" | \
       gcloud secrets versions add POSTGRES_PASSWORD --data-file=-
   ```

5. Authenticate Docker config

   ```bash
   gcloud auth configure-docker ${REGION}-docker.pkg.dev
   ```

6. Build and Push the docker image to the artifact registry (locally)

   ```bash
   # From root folder

   # Build the backstage application first
   yarn build:all

   # Build the docker image and tag it to the artifact repository
   docker build . -f packages/backend/Dockerfile --tag ${REGION}-docker.pkg.dev/${PROJECT_ID}/${REPO_NAME}/${REPO_NAME}:dev

   #  Push the docker image
   docker push ${REGION}-docker.pkg.dev/${PROJECT_ID}/${REPO_NAME}/${REPO_NAME}:dev
   ```

7. Optional: Docker build and push using cloudbuild. Make sure to do `yarn build:all` first

   ```bash
   # Create a new file: cloudbuild.yaml and paste this:

   steps:
     # Docker Build
     - name: 'gcr.io/cloud-builders/docker'
       args: ['pull', 'docker/dockerfile:experimental']
     - name: 'gcr.io/cloud-builders/docker'
       args:
         [
           'build',
           '.',
           '-f',
           'packages/backend/Dockerfile',
           '-t',
           'us-west1-docker.pkg.dev/your-project-id/your-repository/your-repository:dev',
         ]
       env:
         - 'DOCKER_BUILDKIT=1'

       # Docker Push
     - name: 'gcr.io/cloud-builders/docker'
       args:
         [
           'push',
           'us-west1-docker.pkg.dev/your-project-id/your-repository/your-repository:dev',
         ]

   # Sumbit the config using gcloud cli:
   gcloud builds submit --config cloudbuild.yaml
   ```

   I preferred this one since it does the build and push directly from google cloud, with lesser bandwidth usage when used locally. Win-win if you have a slow internet connection or your docker is fucking you up haha.

## Terraform

Now that we already have an artifact registry repository with backstage image, we can now start working with Infrastructure as Code with Terraform.

Let’s create a `deployment` folder to our root directory, and create `environments/dev` and `modules` folder.

Under `environments/dev`, create `terraform.tfvars` file to store our local variables and add these:

```bash
project                      = "your-gcp-project-id"
region                       = "us-west1"
zone                         = "us-west1-a"
artifact_registry_url        = "us-west1-docker.pkg.dev"
artifact_registry_repository = "backstage"
```

Create `variables.tf` file for our input variables to be passed to our module

```bash
variable "project" {
  type        = string
  description = "The project ID to deploy to"
}

variable "region" {
  type        = string
  description = "The region to deploy to"
}

variable "zone" {
  type        = string
  description = "The zone to deploy to"
}

variable "artifact_registry_url" {
  type        = string
  description = "The URL of the Artifact Registry repository"
}

variable "artifact_registry_repository" {
  type        = string
  description = "The name of the Artifact Registry repository"
}
```

Create `main.tf` file to describe our main infrastructure

```bash
provider "google" {
  project = var.project
}

# Modules will be here
```

The current folder tree should look something like this:

```bash
├── environments
│   └── dev
│       ├── main.tf
│       ├── terraform.tfvars
│       └── variables.tf
└── modules
```

### VPC Module

We will use [VPC](https://cloud.google.com/vpc) to secure our resources and data, and isolate our network from the public internet.

Create `vpc` folder under `modules` directory and create three files: `main.tf` `outputs.tf` `variables.tf`

```bash
└── modules
    └── vpc
        ├── main.tf
        ├── outputs.tf
        └── variables.tf
```

Open the `variables.tf` and add these(feel free to update some of the IP ranges):

```bash
variable "region" {
  type        = string
  description = "The region to deploy to"
}

variable "project_id" {
  type        = string
  description = "The project ID to deploy to"
}

variable "subnet_ip" {
  type        = string
  description = "The IP and CIDR range of the subnet being created"
  default     = "10.0.0.0/16"
}

variable "serverless_vpc_ip_cidr_range" {
  type        = string
  description = "Serverless VPC Connector IP CIDR range"
  default     = "10.8.0.0/28"
}

variable "network_name" {
  type        = string
  description = "Network name"
  default     = "backstage-main"
}
```

Open the `[main.tf](http://main.tf)` let’s leverage the vpc module from google

```bash
module "vpc_network" {
  source  = "terraform-google-modules/network/google"
  version = "~> 6.0"

  network_name = var.network_name
  project_id   = var.project_id

  subnets = [
      {
        subnet_name           = "${module.vpc_network.network_name}-subnetwork"
        subnet_ip             = var.subnet_ip
        subnet_region         = var.region
        subnet_private_access = "true"
        subnet_flow_logs      = "false"
      }
    ]
}
```

Let’s add a GCE global address resource. This resource represents a static IP address that can be used to communicate with resources with our VPC network.

```bash
resource "google_compute_global_address" "backstage_private_ip_address" {
  provider = google-beta

  project       = var.project_id
  name          = "backstage-private-ip-address"
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  prefix_length = 16
  network       = "projects/${var.project_id}/global/networks/${module.vpc_network.network_name}"
}
```

Let’s add a Google Service Networking connection resource. This connection will allow resources in our VPC network to communicate with the service using the reserved peering ranges.

```bash
resource "google_service_networking_connection" "backstage_private_vpc_connection" {
  provider = google-beta

  network                 = "projects/${var.project_id}/global/networks/${module.vpc_network.network_name}"
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.backstage_private_ip_address.name]
}
```

Let's add a Serverless VPC Connector. This resource creates a connection between our VPC network and Google's Cloud Run(serverless) service, for our use case.

```bash
resource "google_vpc_access_connector" "connector" {
  name          = "backstage-connector"
  project       = var.project_id
  region        = var.region
  ip_cidr_range = var.serverless_vpc_ip_cidr_range
  network       = module.vpc_network.network_name
}
```

Our `main.tf` should look something like this:

```bash
module "vpc_network" {
  source  = "terraform-google-modules/network/google"
  version = "~> 6.0"

  network_name = var.network_name
  project_id   = var.project_id

  subnets = [
      {
        subnet_name           = "${module.vpc_network.network_name}-subnetwork"
        subnet_ip             = var.subnet_ip
        subnet_region         = var.region
        subnet_private_access = "true"
        subnet_flow_logs      = "false"
      }
    ]
}

resource "google_compute_global_address" "backstage_private_ip_address" {
  provider = google-beta

  project       = var.project_id
  name          = "backstage-private-ip-address"
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  prefix_length = 16
  network       = "projects/${var.project_id}/global/networks/${module.vpc_network.network_name}"
}

resource "google_service_networking_connection" "backstage_private_vpc_connection" {
  provider = google-beta

  network                 = "projects/${var.project_id}/global/networks/${module.vpc_network.network_name}"
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.backstage_private_ip_address.name]
}

resource "google_vpc_access_connector" "connector" {
  name          = "backstage-connector"
  project       = var.project_id
  region        = var.region
  ip_cidr_range = var.serverless_vpc_ip_cidr_range
  network       = module.vpc_network.network_name
}
```

Finally, let's create an `outputs.tf` file to make our infrastructure configuration available to other Terraform configurations.

```bash
output "vpc_network" {
  value       = module.vpc_network
  description = "Backstage VPC Network"
}

output "backstage_serverless_vpc_connector_name" {
  value       = google_vpc_access_connector.connector.name
  description = "Backstage Serverless VPC Connector"
}

output "backstage_private_vpc_connection" {
  value       = google_service_networking_connection.backstage_private_vpc_connection
  description = "Backstage Private VPC Connection"
}
```

### CloudSQL Module

We will be using Cloud SQL postgres for our database

Create `cloudsql` folder under `modules` directory and create three files: `main.tf` `outputs.tf` `variables.tf`

```bash
└── modules
    └── cloudsql
        ├── main.tf
        ├── outputs.tf
        └── variables.tf
```

Open the `variables.tf` and add these:

```bash
variable "project_id" {
  type        = string
  description = "GCP Project for Backstage"
}

variable "region" {
  type = string
}

variable "network_id" {
  type = string
}

variable "deletion_protection" {
  type        = bool
  description = "Sets delete_protection of the Instance"
  default     = false
}

variable "user_password" {
  type        = string
  description = "The password for the default user. If not set, a random one will be generated and available in the generated_user_password output variable."
}
```

Open the `main.tf` and add this Postgres resource with a private network connected to our VPC:

```bash
resource "google_sql_database_instance" "backstage" {
  provider         = google-beta
  project          = var.project_id
  name             = "backstage-db"
  database_version = "POSTGRES_14"
  region           = var.region

  settings {
    tier = "db-g1-small"
    ip_configuration {
      ipv4_enabled    = false
      private_network = var.network_id
      require_ssl     = true
    }
  }

  deletion_protection = var.deletion_protection
}
```

Create a database and database user and password

```bash
resource "random_id" "user-password" {
  byte_length = 8
}

resource "google_sql_database" "backstage_db" {
  project  = var.project_id
  name     = google_sql_database_instance.backstage.name
  instance = google_sql_database_instance.backstage.name
}

resource "google_sql_user" "backstage_user" {
  name     = "postgres"
  instance = google_sql_database_instance.backstage.name
  password = var.user_password == "" ? random_id.user-password.hex : var.user_password
}
```

Finally, let's create an `outputs.tf` file to make our infrastructure configuration available to other Terraform configurations.

```bash
output "sql_instance_name" {
  value       = google_sql_database_instance.backstage.name
  description = "Backstage sql instance name"
}

output "sql_instance_connection_name" {
  value       = google_sql_database_instance.backstage.connection_name
  description = "Backstage sql instance connection name"
}

output "generated_user_password" {
  description = "The auto generated default user password if no input password was provided"
  value       = random_id.user-password.hex
  sensitive   = true
}
```

### Secrets Module

We will securely store the postgres password with Secrets Manager

Create `secrets` folder under `modules` directory and create three files: `main.tf` `variables.tf`

```bash
└── modules
    └── secrets
        ├── main.tf
        └── variables.tf
```

Open the `variables.tf` and add the postgres_password variable

```bash
variable "postgres_password" {
  type        = string
  description = "Cloud SQL Postgres password"
}
```

Open the `main.tf` and add the secrets manager resource with the password generated from cloud SQL module

```bash
resource "google_secret_manager_secret" "postgres_password" {
  secret_id = "postgres-password"

  labels = {
    label = "postgres-password"
  }

  replication {
    automatic = true
  }
}

resource "google_secret_manager_secret_version" "postgres_password" {
  secret = google_secret_manager_secret.postgres_password.id

  secret_data = var.postgres_password
}
```

### IAM Module

We will create a service account for Cloud Run

Create `iam` folder under `modules` directory and create three files: `main.tf` `outputs.tf` `variables.tf`

```bash
└── modules
    └── iam
        ├── main.tf
				├── outputs.tf
        └── variables.tf
```

Open the `variables.tf` and add the project_id variable

```bash
variable "project_id" {
  type        = string
  description = "The project id for the Backstage"
}
```

Open the `main.tf` and add these service account resource together with each role

```bash
resource "google_service_account" "backstage" {
  project      = var.project_id
  account_id   = "backstage"
  display_name = "Backstage"
}

resource "google_project_iam_member" "backstage" {
  project = var.project_id
  for_each = toset([
    "roles/cloudsql.admin",
    "roles/run.admin",
    "roles/serviceusage.serviceUsageAdmin",
    "roles/iam.serviceAccountUser",
    "roles/secretmanager.secretAccessor",
  ])
  role   = each.key
  member = "serviceAccount:${google_service_account.backstage.email}"
}
```

Open the `outputs.tf` and add expose the service account email and id

```bash
output "backstage_service_account_email" {
  value       = google_service_account.backstage.email
  description = "Backstage service account email"
}

output "backstage_service_account_id" {
  value       = google_service_account.backstage.id
  description = "Backstage service account id"
}
```

### CloudRun Module

We will create a Cloud Run resource that is publicly available.

Create `cloudrun` folder under `modules` directory and create three files: `main.tf` `variables.tf`

```bash
└── modules
    └── cloudrun
        ├── main.tf
        └── variables.tf
```

Open the `variables.tf` and add the incoming variables

```bash
variable "project_id" {
  type        = string
  description = "GCP Project for Backstage"
}

variable "region" {
  type = string
}

variable "vpc_connector_name" {
  type        = string
  description = "Serverless VPC Connector"
}

variable "cloudsql_instance_name" {
  type        = string
  description = "Cloud SQL Instance Name"
}

variable "cloudsql_instance_connection_name" {
  type        = string
  description = "Cloud SQL Instance Connection Name"
}

variable "artifact_registry_url" {
  type        = string
  description = "Artifact Registry URL"
}

variable "artifact_repo" {
  type        = string
  description = "Artifact Registry Repo"
}

variable "service_account_email" {
  type        = string
  description = "Service Account Email"

}
```

Open `main.tf` and add the Cloud Run resource, together with the previously pushed Backstage image artifact. Our Cloud Run service is connected to Cloud SQL in a private connection. We can connect to our own VPC network, thanks to the Serverless VPC Connector. We are also securely connected to our Cloud SQL instance with Cloud SQL Proxy, without setting up an SSL certificate.

```bash
resource "google_cloud_run_service" "backstage" {
  provider = google-beta

  name     = "backstage"
  location = var.region
  project  = var.project_id

  template {
    spec {
      containers {
        image = "${var.artifact_registry_url}/${var.project_id}/${var.artifact_repo}/${var.artifact_repo}:dev"
        env {
          name  = "BACKSTAGE_BASE_URL"
          value = ""
        }
        env {
          name  = "POSTGRES_HOST"
          value = "/cloudsql/${var.cloudsql_instance_connection_name}"
        }
        env {
          name  = "POSTGRES_USER"
          value = "postgres"
        }
        env {
          name  = "POSTGRES_PORT"
          value = "5432"
        }
        env {
          name = "POSTGRES_PASSWORD"
          value_from {
            secret_key_ref {
              name = "postgres-password"
              key  = "latest"
            }
          }
        }
      }

      service_account_name = var.service_account_email
    }

    metadata {
      annotations = {
        "run.googleapis.com/cloudsql-instances"   = var.cloudsql_instance_connection_name
        "run.googleapis.com/client-name"          = "terraform"
        "run.googleapis.com/vpc-access-connector" = "projects/${var.project_id}/locations/${var.region}/connectors/${var.vpc_connector_name}"
        "run.googleapis.com/vpc-access-egress"    = "all-traffic"
      }
    }
  }

  traffic {
    percent         = 100
    latest_revision = true
  }

  autogenerate_revision_name = true
}
```

Let's add a publicly accessible IAM policy resource to enable us to access the Backstage service.

```bash
data "google_iam_policy" "noauth" {
  binding {
    role = "roles/run.invoker"
    members = [
      "allUsers",
    ]
  }
}

resource "google_cloud_run_service_iam_policy" "noauth" {
  location = var.region
  project  = var.project_id
  service  = google_cloud_run_service.backstage.name

  policy_data = data.google_iam_policy.noauth.policy_data
}
```

### Final Config

Let’s go back to our `main.tf` from `deployment/environment/dev` directory and add the modules.

```bash
provider "google" {
  project = var.project
}

module "vpc" {
  source     = "../../modules/vpc"
  region     = var.region
  project_id = var.project
}

module "cloudsql" {
  source        = "../../modules/cloudsql"
  region        = var.region
  project_id    = var.project
  network_id    = "projects/${var.project}/global/networks/${module.vpc.vpc_network.network_name}"
  user_password = ""
  depends_on = [
    module.vpc, module.vpc.backstage_private_vpc_connection
  ]
}

module "secrets" {
  source            = "../../modules/secrets"
  postgres_password = module.cloudsql.generated_user_password
  depends_on = [
    module.cloudsql
  ]
}

module "iam" {
  source     = "../../modules/iam"
  project_id = var.project
}
module "cloudrun" {
  source                            = "../../modules/cloudrun"
  project_id                        = var.project
  region                            = var.region
  vpc_connector_name                = module.vpc.backstage_serverless_vpc_connector_name
  artifact_registry_url             = var.artifact_registry_url
  artifact_repo                     = var.artifact_registry_repository
  cloudsql_instance_name            = module.cloudsql.sql_instance_name
  cloudsql_instance_connection_name = module.cloudsql.sql_instance_connection_name
  service_account_email             = module.iam.backstage_service_account_email

  depends_on = [
    module.cloudsql, module.vpc, module.secrets
  ]
}
```

Our final folder tree should look something like this:

```bash
├── deployment
│   ├── environments
│   │   └── dev
│   │       ├── main.tf
│   │       ├── terraform.tfvars
│   │       └── variables.tf
│   └── modules
│       ├── cloudrun
│       │   ├── main.tf
│       │   └── variables.tf
│       ├── cloudsql
│       │   ├── main.tf
│       │   ├── outputs.tf
│       │   └── variables.tf
│       ├── iam
│       │   ├── main.tf
│       │   ├── outputs.tf
│       │   └── variables.tf
│       ├── secrets
│       │   ├── main.tf
│       │   └── variables.tf
│       └── vpc
│           ├── main.tf
│           ├── outputs.tf
│           └── variables.tf
```

Initialize our Terraform config

```bash
cd deployment/environments/dev/

terraform init
```

Run **`terraform plan -out tfplan`**  to generate the execution plan

Run **`terraform apply tfplan`** to create or update infrastructure according to the execution plan

You should now be able to deploy your Backstage with Cloud Run via Terraform! Yey!

## CI/CD with Github Action (soon)

## External Techdocs (soon)

## Source Code

[Github Repo](https://github.com/mharrvic/backstage-cloudrun-terraform)
