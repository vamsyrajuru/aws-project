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

# Allocate an Elastic IP for NAT Gateway
resource "aws_eip" "nat_eip" {
  domain = "vpc"

  tags = {
    Name = "NatEIP"
  }
}

# Create a NAT Gateway in the Public Subnet
resource "aws_nat_gateway" "nat_gw" {
  allocation_id = aws_eip.nat_eip.id
  subnet_id     = var.avail_a_public_subnet_id

  tags = {
    Name = "MyNATGateway"
  }
}

# Create a Route Table for the Public Subnet
resource "aws_route_table" "public_rt" {
  vpc_id = var.vpc_id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = var.igw_id
  }

  tags = {
    Name = "PublicRouteTable"
  }
}

# Associate Public Subnet with Public Route Table
resource "aws_route_table_association" "public_assoc" {
  subnet_id      = var.avail_a_public_subnet_id
  route_table_id = aws_route_table.public_rt.id
}

# Create a Route Table for the Private Subnet
resource "aws_route_table" "private_rt" {
  vpc_id = var.vpc_id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat_gw.id
  }

  tags = {
    Name = "PrivateRouteTable"
  }
}

resource "time_sleep" "wait_30_seconds" {
  depends_on = [aws_route_table.private_rt]
  create_duration = "30s"
}

# Associate Private Subnet with Private Route Table
resource "aws_route_table_association" "private_assoc" {
  subnet_id      = var.private_subnet_id
  route_table_id = aws_route_table.private_rt.id
}

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

resource "aws_iam_role" "rajuru_iam_role" {
  name = "rajuru-fargate-profile-role"

  assume_role_policy = jsonencode({
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "eks-fargate-pods.amazonaws.com"
      }
    }]
    Version = "2012-10-17"
  })
}

resource "aws_iam_role_policy_attachment" "example-AmazonEKSFargatePodExecutionRolePolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSFargatePodExecutionRolePolicy"
  role       = aws_iam_role.rajuru_iam_role.name
}

resource "aws_eks_fargate_profile" "rajuru_fargate" {
  cluster_name           = "rajuru"
  fargate_profile_name   = "rajuru_fargate"
  pod_execution_role_arn = aws_iam_role.rajuru_iam_role.arn
  subnet_ids             = [var.private_subnet_id]

  selector {
    namespace = "rajuru"
  }
  depends_on = [ module.eks, aws_route_table_association.private_assoc ]
}



## Setting the below value after namespace is created. 
## Private with exception of this CIDR block - 196.182.32.48/32 
## The CIDR value is read from terraform.tfvars


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



