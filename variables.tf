variable "aws_region" {
  description = "The region where the infrastructure should be deployed to"
  type        = string
  default     = "us-east-1"
}

variable "accountid" {
  type        = string
}

variable "vpc_id" {
  type        = string
}

variable "eks_cluster_name" {
  type        = string
}

variable "eks_cluster_version" {
  type        = string
}

variable "eks_subnet_ids" {
  type        = list
}

variable "eks_control_plane_subnet_ids" {
  type        = list
}

variable "eks_instance_types" {
  type        = list
}

variable "eks_iam_role_name" {
  type        = string
}

variable "eks_ami_type" {
  type        = string
}

variable "eks_cluster_endpoint_public_access_cidrs" {
  type        = string
}

variable "lastname_namespace" {
  type        = string
}

variable "owner_tag" {
  type        = string
}

variable "category_tag" {
  type        = string
}
