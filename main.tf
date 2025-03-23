## Module is called to read the vpc id value
/*
module "vpc_id" {
  source  = "./vpc_id"
  aws_region = var.aws_region
}
*/
## Module is called to launch the EKS cluster with specified requirements
/*
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 19.0"

  vpc_id                   = var.vpc_id
  subnet_ids               = var.eks_subnet_ids
  control_plane_subnet_ids = var.eks_control_plane_subnet_ids

## Cluster name should be your last name . 
## The custom value is read from terraform.tfvars 

  cluster_name    = var.eks_cluster_name

## Kubernetes version 1.27
## The value is read from terraform.tfvars 

  cluster_version = var.eks_cluster_version

  cluster_addons = {

    coredns = {
      most_recent = true
    }
  
    kube-proxy = {
      most_recent = true
    }
    vpc-cni = {
      most_recent = true
    }
  }

## Create a unique cluster service role for the cluster
## The custom value is read from terraform.tfvars 

  create_iam_role = true
  iam_role_name = var.eks_iam_role_name

  cluster_endpoint_private_access = true

  cluster_endpoint_public_access = true

## EKS Managed Node Group(s)
  eks_managed_node_group_defaults = {

## Nodes should be CPU Optimized
## The Compute nodes are configured for EKS

    compute = {
      instance_types = var.eks_instance_types
    }

## Amazon EKS optimized AMI
## EKS optimized AMI version is set and read from terraform.tfvars

      ami_type = var.eks_ami_type
  }

  eks_managed_node_groups = {
    blue = {}
    green = {

## Node group – max size 6, min size 3, desired size 4

      min_size     = 1
      max_size     = 2
      desired_size = 1

      instance_types = var.eks_instance_types
      capacity_type  = "SPOT"
    }
  }

  tags = {
    OWNER = var.owner_tag
    CATEGORY   = var.category_tag
  }
}
*/

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.31"

  cluster_name    = "rajuru"
  cluster_version = "1.31"

  # Optional
  cluster_endpoint_public_access = true

  # Optional: Adds the current caller identity as an administrator via cluster access entry
  enable_cluster_creator_admin_permissions = true

  cluster_compute_config = {
    enabled    = true
    node_pools = ["general-purpose"]
  }

  vpc_id     = var.vpc_id
  subnet_ids = var.eks_subnet_ids

  tags = {
    Environment = "dev"
    Terraform   = "true"
  }
}

## The EKS cluster context is being set using null_resource
## Kubernetes Namespace is being created with name set to lastname
## The custom value is read from terraform.tfvars 

resource "null_resource" "update-kubeconfig-create-namespace" {

  provisioner "local-exec" {
    command     = "aws eks update-kubeconfig --region ${var.aws_region} --name ${var.eks_cluster_name}"
  }

  provisioner "local-exec" {
    command     = "kubectl create namespace ${var.lastname_namespace}"
  }

  provisioner "local-exec" {
    command     = "kubectl get namespace ${var.lastname_namespace}"
  }

  depends_on = [
    module.eks  
  ]
}

## Setting the below value after namespace is created. 
## Private with exception of this CIDR block - 196.182.32.48/32 
## The CIDR value is read from terraform.tfvars
/*

resource "null_resource" "update-publicAccessCidrs" {
  triggers = {
    always_run = "${timestamp()}"
  }

  provisioner "local-exec" {
    command     = "aws eks update-cluster-config --region ${var.aws_region} --name ${var.eks_cluster_name} --resources-vpc-config publicAccessCidrs=${var.eks_cluster_endpoint_public_access_cidrs}"
  }
  depends_on = [
    module.eks,
    null_resource.update-kubeconfig-create-namespace
  ]
}
*/


