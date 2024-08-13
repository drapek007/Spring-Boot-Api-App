provider "aws" {
  region = "us-west-2"
}

module "eks_dev" {
  source          = "terraform-aws-modules/eks/aws"
  cluster_name    = "dev-global-cluster-0"
  cluster_version = "1.29"
  subnets         = module.vpc_dev.public_subnets
  vpc_id          = module.vpc_dev.vpc_id
  node_groups = {
    dev_nodes = {
      desired_capacity = 3
      max_capacity     = 5
      min_capacity     = 3
      instance_type    = "t3.medium"
    }
  }
}

module "eks_prod" {
  source          = "terraform-aws-modules/eks/aws"
  cluster_name    = "prd-global-cluster-5"
  cluster_version = "1.29"
  subnets         = module.vpc_prod.public_subnets
  vpc_id          = module.vpc_prod.vpc_id
  node_groups = {
    prod_nodes = {
      desired_capacity = 3
      max_capacity     = 5
      min_capacity     = 3
      instance_type    = "t3.medium"
    }
  }
}

module "vpc_dev" {
  source  = "terraform-aws-modules/vpc/aws"
  name    = "dev-vpc"
  cidr    = "10.0.0.0/16"
  azs     = ["us-west-2a", "us-west-2b", "us-west-2c"]
  public_subnets = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
}

module "vpc_prod" {
  source  = "terraform-aws-modules/vpc/aws"
  name    = "prod-vpc"
  cidr    = "10.1.0.0/16"
  azs     = ["us-west-2a", "us-west-2b", "us-west-2c"]
  public_subnets = ["10.1.1.0/24", "10.1.2.0/24", "10.1.3.0/24"]
}

output "dev_cluster_name" {
  value = module.eks_dev.cluster_name
}

output "prod_cluster_name" {
  value = module.eks_prod.cluster_name
}

output "dev_kubeconfig" {
  value = module.eks_dev.kubeconfig
}

output "prod_kubeconfig" {
  value = module.eks_prod.kubeconfig
}



# Argo CD Installation on Dev Cluster
resource "kubernetes_namespace" "argocd_dev" {
  metadata {
    name = "argocd"
  }
  depends_on = [module.eks_dev]
}

resource "null_resource" "install_argocd_dev" {
  provisioner "local-exec" {
    command = <<EOT
      kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
      kubectl patch svc argocd-server -n argocd -p '{"spec": {"type": "LoadBalancer"}}'
    EOT
    environment = {
      KUBECONFIG = module.eks_dev.kubeconfig
    }
  }
  depends_on = [kubernetes_namespace.argocd_dev]
}

# Argo CD Installation on Prod Cluster
resource "kubernetes_namespace" "argocd_prod" {
  metadata {
    name = "argocd"
  }
  depends_on = [module.eks_prod]
}

resource "null_resource" "install_argocd_prod" {
  provisioner "local-exec" {
    command = <<EOT
      kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
      kubectl patch svc argocd-server -n argocd -p '{"spec": {"type": "LoadBalancer"}}'
    EOT
    environment = {
      KUBECONFIG = module.eks_prod.kubeconfig
    }
  }
  depends_on = [kubernetes_namespace.argocd_prod]
}
