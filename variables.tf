variable "ami" {
  default     = "ami-0f2b4fc905b0bd1f1"
  description = "AMI for Vault instances"
}

variable "hashi_tools_rpm" {
  description = "S3 Path to HashiTool RPM download with enterprise binaries."
}

variable "bootstrap" {
  default     = true
  description = "Initial Bootstrap configurations"
}

variable "redundancy_zones" {
  default     = false
  description = "Leverage Redundancy Zones within Consul for additional non-voting nodes."
}

variable "public_ip" {
  default     = false
  description = "should ec2 instance have public ip?"
}

variable "name_prefix" {
  default     = "hashicorp"
  description = "prefix used in resource names"
}

variable "availability_zones" {
  default     = "us-east-2a,us-east-2b,us-east-2c"
  description = "Availability zones for launching the Vault instances"
}

variable "vault_elb_health_check" {
  default     = "HTTP:8200/v1/sys/health?activecode=200&standbycode=200&sealedcode=200&uninitcode=200"
  description = "Health check for Vault servers"
}

variable "vault_elb_health_check_active" {
  default     = "HTTP:8200/v1/sys/health?standbyok=true"
  description = "Health check for Vault servers"
}

variable "elb_internal" {
  default     = true
  description = "make LB internal or external"
}

variable "instance_type" {
  default     = "t3.medium"
  description = "Instance type for Vault and Consul instances"
}

variable "key_name" {
  default     = "default"
  description = "SSH key name for Vault and Consul instances"
}

variable "vault_nodes" {
  default     = "3"
  description = "number of Vault instances"
}

variable "consul_nodes" {
  default     = "3"
  description = "number of Consul instances"
}

variable "subnets" {
  description = "list of subnets to launch Vault within"
}

variable "vpc_id" {
  description = "VPC ID"
}

variable "owner" {
  description = "value of owner tag on EC2 instances"
}

variable "ttl" {
  description = "value of ttl tag on EC2 instances"
}

variable "auto_join_tag" {
  description = "value of ConsulAutoJoin tag used by Consul cluster"
}

variable "consul_cluster_version" {
  default     = "0.0.1"
  description = "Custom Version Tag for Upgrade Migrations"
}
variable "vault_cluster_version" {
  default     = "0.0.1"
  description = "Custom Version Tag for Upgrade Migrations"
}
