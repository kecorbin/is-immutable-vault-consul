# Deploy Vault to AWS with Consul Storage Backend

This folder contains a Terraform module for deploying Vault to AWS (within a VPC) along with Consul as the storage backend. It currently requires the use of CentOS/RHEL 7 but could easily be adapted to support Ubuntu in the Future.

It takes a blue/green approach to managing the Consul/Vault ASG deployments along with leveraging Consul AutoPilot to support seamless upgrade transitions and health checks to validate consul is healthy before moving to the next phase of deployment.

The Terraform code will create the following resources in a VPC and subnet that you specify in the designated AWS region:
* IAM instance profile, IAM role, IAM policy, and associated IAM policy documents
* An AWS auto scaling group with 3 EC2 instances running Vault on RHEL 7 or CentOS 7 (depending on the AMI passed to the ami variable)
* An AWS auto scaling group with 3 EC2 instances running Consul on RHEL 7 or CentOS 7 (depending on the AMI passed to the ami variable)
* 2 AWS launch configurations
* 1 AWS Elastic Load Balancers for Vault
* 2 AWS security groups, one for the Vault and Consul EC2 instances and one for the ELB.
* Security Group Rules to control ingress and egress for the instances and the ELB. These attempt to limit most traffic to inside and between the two security groups, but do allow the following broader access:
   * inbound SSH access on port 22 from anywhere
   * inbound access to the ELBs on ports 8200 for Vault
   * outbound calls on port 80/443 to anywhere (so that the installation scripts can download the vault and consul binaries and reach yum repositories)
   * After installation, those broader security group rules could be made tighter.
* Consul ACL seeds for the various tokens required to protect vault/consul.
* Consul Gossip Encryption Key generation
* Mutual TLS for Consul communication between Consul Servers/Vault Nodes(wip)
* Consul Snapshot Agent Running on Vault nodes as a highly available service dumping snapshots to S3
* TLS for Vault has been left out as this will be customer specific and will typically require internally trusted certificates from AD/Venafi/AWS ACM/or a different CA.

You can deploy this in either a public or a private subnet.  But you must set elb_internal and public_ip as instructed below in both cases. The VPC should have at least 3 subnets for high availability.

## Preparation
1. On a Linux or Mac system, export your AWS keys and AWS default region as variables. On Windows, you would use set instead of export. You can also export AWS_SESSION_TOKEN if you need to use an MFA token to provision resources in AWS.

```
export AWS_ACCESS_KEY_ID=<your_aws_key>
export AWS_SECRET_ACCESS_KEY=<your_aws_secret_key>
export AWS_DEFAULT_REGION=us-east-2
export AWS_SESSION_TOKEN=<your_token>
```
2. Copy the file vault.auto.tfvars.example to vault.auto.tfvars and provide appropriate values for the variables.

The AMI is currently set to the latest Centos 7 1901 image from us-east-2
hashi_tools_rpm needs to be set to publicly available download link for the enterprise binaries.

Set instance_type to the appropriate EC2 type(m5.large recommended for production).

The consul_cluster_version/vault_cluster_version can be used to trigger rolling upgrades of either Vault or Consul.  It's important to increment these values anytime you make changes that would trigger the user_data/launch config values to be updated for either.

During initial bootstrap you will want these set at 0.0.1, and the bootstrap value set to true.  Following the deployment you will need to perform a bootstrap initialization process outlined below.  Then you will increment the version to 0.0.2 and set bootstrap to false.

key_name should be the name of an existing AWS keypair in your AWS account in the designated region. Use the name as it is shown in the AWS Console.  You need a copy of the corresponding private key on your local workstation.

name_prefix can be anything you want; they affect the names of some of the resources.

vpc_id should be the id of the VPC into which you want to deploy Vault.

subnets should be the ids of the 3 subnets in your AWS VPC

If using a public subnet, use the following for elb_internal and public_ip:
elb_internal = false
public_ip = true

If using a private subnet, use the following for elb_internal and public_ip:
elb_internal = true
public_ip = false
However, you will need an additional bastion host deployed within the same VPC to SSH into the Consul/Vault Nodes to complete the bootstrap process.

## Deployment
To deploy with Terraform, simply run the following two commands:

```
terraform init
terraform apply
```
When the second command asks you if you want to proceed, type "yes" to confirm.

You should get outputs at the end of the apply showing something like the following:
```
Outputs:
vault_address = http://benchmark-vault-elb-783003639.us-east-1.elb.amazonaws.com:8200
vault_elb_security_group = sg-09ee1199992b803f7
vault_security_group = sg-0a4c0e2f499e2e0cf
```

You will be able to use the Vault ELB URL after you complete the bootstrap process.

1. In the AWS Console, find and select your Vault instances and pick one.
2. Determine the public or private(if using bastion) ip address to use to connect to the instance.
3. ssh -i ~/.ssh/id_my_aws_key centos@ip.ip.ip.ip
4. On the Vault server, run the following commands:

```
export VAULT_ADDR=http://127.0.0.1:8200
vault operator init -recovery-shares=1 -recovery-threshold=1
```
The init command will show you your root token and unseal key. (In a real production environment, you would specify a larger key threshold `-recovery-shares=5 -recovery-threshold=3` and use PGP/keybase encryption to protect the values). These will be important for going through the subsequent configuration processes and need to be protected/kept in a safe place.

1. In the AWS Console, find and select your Consul instances and pick one.
2. Determine the public or private(if using bastion) ip address to use to connect to the instance.
3. ssh -i ~/.ssh/id_my_aws_key centos@ip.ip.ip.ip
4. On the Consul server, run the following commands:

```
/home/centos/bootstrap_tokens.sh
```

Now you need to increment your TF variables for consul_cluster_version/vault_cluster_version to 0.0.2 and set bootstrap to false and run an additional apply.
```
terraform apply
```
Following the next deployment you should be able to reach your Vault UI/API via the elb address listed in the outputs.

Now, Optionally you can update the Consul anonymous token ACL policy to include some basic functionality to support DNS queries and other basic read only operational commands.
This script will only be available during consul_cluster_version 0.0.2

1. In the AWS Console, find and select your Consul instances and pick one.
2. Determine the public or private(if using bastion) ip address to use to connect to the instance.
3. ssh -i ~/.ssh/id_my_aws_key centos@ip.ip.ip.ip
4. On the Consul server, run the following commands:

```
/home/centos/anonymous_token.sh
```