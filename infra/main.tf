# ---------------------------------------------------------------------------------------------------------------------
# 1. PROVIDER & CONFIGURAÇÕES GERAIS
# ---------------------------------------------------------------------------------------------------------------------
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  # Estado local - não requer AWS real para o desafio
  #backend "s3" {
  # bucket = "biotech-x-terraform-state"
  # key    = "prod/terraform.tfstate"
  # region = "us-east-1"
  #}
}

provider "aws" {
  region                      = "us-east-1"
  skip_credentials_validation = true
  skip_metadata_api_check     = true
  skip_region_validation      = true
  skip_requesting_account_id  = true

  # Para demonstração - não requer AWS real
  access_key = "demo-access-key"
  secret_key = "demo-secret-key"

  default_tags {
    tags = {
      Project     = "Biotech-X"
      Environment = "Production"
      ManagedBy   = "Terraform"
    }
  }
}

# Variáveis Locais para padronização
locals {
  app_name = "biotech-x-platform"
}

# ---------------------------------------------------------------------------------------------------------------------
# 2. NETWORKING (VPC, Subnets, Gateway)
# ---------------------------------------------------------------------------------------------------------------------
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags                 = { Name = "${local.app_name}-vpc" }
}

# Subnets Públicas (Load Balancers, NAT)
resource "aws_subnet" "public_1a" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = true
  tags                    = { Name = "${local.app_name}-public-1a", "kubernetes.io/role/elb" = "1" }
}

resource "aws_subnet" "public_1b" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = "us-east-1b"
  map_public_ip_on_launch = true
  tags                    = { Name = "${local.app_name}-public-1b", "kubernetes.io/role/elb" = "1" }
}

# Subnets Privadas (Apps EKS, Batch)
resource "aws_subnet" "private_1a" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.10.0/24"
  availability_zone = "us-east-1a"
  tags              = { Name = "${local.app_name}-private-1a", "kubernetes.io/role/internal-elb" = "1" }
}

resource "aws_subnet" "private_1b" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.11.0/24"
  availability_zone = "us-east-1b"
  tags              = { Name = "${local.app_name}-private-1b", "kubernetes.io/role/internal-elb" = "1" }
}

# Internet Gateway & Route Tables
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
}

resource "aws_route_table_association" "public_1a" {
  subnet_id      = aws_subnet.public_1a.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "public_1b" {
  subnet_id      = aws_subnet.public_1b.id
  route_table_id = aws_route_table.public.id
}

# Nota: Em produção real, é necessário NAT Gateway para as subnets privadas acessarem a internet (download de pacotes/imagens).
# Omitido o recurso completo do NAT Gateway para simplificar o arquivo, mas a rota seria adicionada aqui.

# ---------------------------------------------------------------------------------------------------------------------
# 3. SEGURANÇA (Security Groups)
# ---------------------------------------------------------------------------------------------------------------------
resource "aws_security_group" "eks_nodes" {
  name        = "${local.app_name}-eks-nodes-sg"
  description = "Security group for EKS nodes"
  vpc_id      = aws_vpc.main.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "db_sg" {
  name        = "${local.app_name}-db-sg"
  description = "Security group for RDS"
  vpc_id      = aws_vpc.main.id

  # Permite entrada apenas dos nós do EKS e Batch
  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.eks_nodes.id]
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# 4. STORAGE & RETENTION (S3) - Requisito Crítico
# ---------------------------------------------------------------------------------------------------------------------
# Bucket de Entrada (Input) - Retenção de 365 dias
resource "aws_s3_bucket" "input_bucket" {
  bucket_prefix = "biotech-input-"
  force_destroy = true # Cuidado em produção
}

resource "aws_s3_bucket_lifecycle_configuration" "input_lifecycle" {
  bucket = aws_s3_bucket.input_bucket.id

  rule {
    id     = "expire-after-365-days"
    status = "Enabled"

    filter {
      prefix = ""
    }

    expiration {
      days = 365
    }
    # Otimização de custo: Move para IA após 30 dias
    transition {
      days          = 30
      storage_class = "STANDARD_IA"
    }
  }
}

# Bucket de Saída (Output) - Retenção de 5 anos
resource "aws_s3_bucket" "output_bucket" {
  bucket_prefix = "biotech-output-"
  force_destroy = true
}

resource "aws_s3_bucket_lifecycle_configuration" "output_lifecycle" {
  bucket = aws_s3_bucket.output_bucket.id

  rule {
    id     = "retain-5-years"
    status = "Enabled"

    filter {
      prefix = ""
    }

    expiration {
      days = 1825 # 5 anos
    }
    # Otimização extrema de custo: Glacier Deep Archive após 1 ano
    transition {
      days          = 365
      storage_class = "DEEP_ARCHIVE"
    }
  }
}

# Bloqueio de acesso público (Segurança)
resource "aws_s3_bucket_public_access_block" "block_public_input" {
  bucket                  = aws_s3_bucket.input_bucket.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# ---------------------------------------------------------------------------------------------------------------------
# 5. DATABASE (RDS PostgreSQL)
# ---------------------------------------------------------------------------------------------------------------------
resource "aws_db_subnet_group" "default" {
  name       = "${local.app_name}-db-subnet-group"
  subnet_ids = [aws_subnet.private_1a.id, aws_subnet.private_1b.id]
}

resource "aws_db_instance" "default" {
  identifier           = "${local.app_name}-db"
  allocated_storage    = 20
  storage_type         = "gp3"
  engine               = "postgres"
  engine_version       = "14"
  instance_class       = "db.t3.micro"
  db_name              = "biotech_db"
  username             = "admin_user"
  password             = "ChangeMeInProduction123!" # Em produção, usar AWS Secrets Manager
  parameter_group_name = "default.postgres14"
  skip_final_snapshot  = true
  multi_az             = true # Alta Disponibilidade (Requisito)

  vpc_security_group_ids = [aws_security_group.db_sg.id]
  db_subnet_group_name   = aws_db_subnet_group.default.name
}

# ---------------------------------------------------------------------------------------------------------------------
# 6. COMPUTE (EKS Cluster)
# ---------------------------------------------------------------------------------------------------------------------
# IAM Role para o Cluster
resource "aws_iam_role" "eks_cluster_role" {
  name = "${local.app_name}-eks-cluster-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "eks.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "eks_cluster_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.eks_cluster_role.name
}

resource "aws_eks_cluster" "main" {
  name     = "${local.app_name}-cluster"
  role_arn = aws_iam_role.eks_cluster_role.arn

  vpc_config {
    subnet_ids = [aws_subnet.public_1a.id, aws_subnet.public_1b.id, aws_subnet.private_1a.id, aws_subnet.private_1b.id]
  }
  depends_on = [aws_iam_role_policy_attachment.eks_cluster_policy]
}

# Node Group (Workers)
resource "aws_iam_role" "eks_node_role" {
  name = "${local.app_name}-eks-node-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "eks_worker_node_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.eks_node_role.name
}
resource "aws_iam_role_policy_attachment" "eks_cni_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.eks_node_role.name
}
resource "aws_iam_role_policy_attachment" "ecr_read_only" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.eks_node_role.name
}

resource "aws_eks_node_group" "main" {
  cluster_name    = aws_eks_cluster.main.name
  node_group_name = "general-nodes"
  node_role_arn   = aws_iam_role.eks_node_role.arn
  subnet_ids      = [aws_subnet.private_1a.id, aws_subnet.private_1b.id]

  scaling_config {
    desired_size = 2
    max_size     = 5
    min_size     = 1
  }

  instance_types = ["t3.medium"]

  depends_on = [
    aws_iam_role_policy_attachment.eks_worker_node_policy,
    aws_iam_role_policy_attachment.eks_cni_policy,
    aws_iam_role_policy_attachment.ecr_read_only,
  ]
}

# ---------------------------------------------------------------------------------------------------------------------
# 7. ASYNC PROCESSING (AWS Batch)
# ---------------------------------------------------------------------------------------------------------------------
# Service Role para o Batch
resource "aws_iam_role" "batch_service_role" {
  name = "${local.app_name}-batch-service-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "batch.amazonaws.com" }
    }]
  })
}
resource "aws_iam_role_policy_attachment" "batch_service_role" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSBatchServiceRole"
  role       = aws_iam_role.batch_service_role.name
}

# Instance Profile para as EC2 do Batch
resource "aws_iam_role" "ecs_instance_role" {
  name = "${local.app_name}-batch-ecs-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
    }]
  })
}
resource "aws_iam_role_policy_attachment" "ecs_instance_role" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceforEC2Role"
  role       = aws_iam_role.ecs_instance_role.name
}
resource "aws_iam_instance_profile" "ecs_instance_role" {
  name = "${local.app_name}-batch-ecs-profile"
  role = aws_iam_role.ecs_instance_role.name
}

resource "aws_batch_compute_environment" "main" {
  compute_environment_name = "${local.app_name}-compute-env"
  type                     = "MANAGED"
  service_role             = aws_iam_role.batch_service_role.arn

  compute_resources {
    type                = "SPOT" # Otimização de Custo (FinOps)
    allocation_strategy = "BEST_FIT_PROGRESSIVE"
    bid_percentage      = 100
    ec2_key_pair        = ""
    image_id            = "ami-05655c267c89566dd" # Exemplo Amazon Linux 2 ECS Optimized
    instance_role       = aws_iam_instance_profile.ecs_instance_role.arn
    instance_type       = ["c5.large", "m5.large"]
    max_vcpus           = 128
    min_vcpus           = 0
    security_group_ids  = [aws_security_group.eks_nodes.id] # Reutilizando SG ou criar específico
    subnets             = [aws_subnet.private_1a.id, aws_subnet.private_1b.id]
    tags = {
      Type = "BatchWorker"
    }
  }
}

resource "aws_batch_job_queue" "main" {
  name     = "${local.app_name}-job-queue"
  state    = "ENABLED"
  priority = 1

  compute_environment_order {
    order               = 1
    compute_environment = aws_batch_compute_environment.main.arn
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# 8. CONTAINER REGISTRY (ECR)
# ---------------------------------------------------------------------------------------------------------------------
resource "aws_ecr_repository" "backend" {
  name                 = "biotech-backend"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }
}

resource "aws_ecr_repository" "frontend" {
  name                 = "biotech-frontend"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# 9. GITHUB ACTIONS OIDC (CI/CD Authentication)
# ---------------------------------------------------------------------------------------------------------------------
# OIDC Provider - Permite GitHub Actions autenticar na AWS sem access keys
resource "aws_iam_openid_connect_provider" "github_actions" {
  url = "https://token.actions.githubusercontent.com"

  client_id_list = ["sts.amazonaws.com"]

  # Thumbprint do GitHub Actions (válido até 2031)
  thumbprint_list = ["6938fd4d98bab03faadb97b34396831e3780aea1"]

  tags = { Name = "${local.app_name}-github-oidc" }
}

# IAM Role que o GitHub Actions vai assumir
resource "aws_iam_role" "github_actions_role" {
  name = "${local.app_name}-github-actions-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Federated = aws_iam_openid_connect_provider.github_actions.arn
      }
      Action = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
        }
        StringLike = {
          # Substitua pelo seu repositório GitHub
          "token.actions.githubusercontent.com:sub" = "repo:${var.github_repository}:*"
        }
      }
    }]
  })
}

# Políticas para o GitHub Actions (ECR + EKS)
resource "aws_iam_role_policy" "github_actions_ecr" {
  name = "ecr-push-policy"
  role = aws_iam_role.github_actions_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ecr:GetAuthorizationToken",
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:PutImage",
          "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy" "github_actions_eks" {
  name = "eks-deploy-policy"
  role = aws_iam_role.github_actions_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "eks:DescribeCluster",
          "eks:ListClusters"
        ]
        Resource = "*"
      }
    ]
  })
}
