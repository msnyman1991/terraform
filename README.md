# Terraform Deployment for AWS environment

## Description

Deploys an AWS environment with Terraform V 0.12.15 using powershell on windows.

## Deployment Prerequisites

* Create a AWS account
* Use eu-west-1 as your region
* Create AWS IAM user with access and secret keys with correct permissions
* Remember to set variable values in vars.tf
* Import CA Cert in CA directory within the package into AWS Certificate Manager
* Update ARN for imported ELB CA Certificate in deploy_aws_env.tf and terraform_backend_state_config files

## Terrafrom State Management

Terraform state is stored within a S3 bucket named "aws-playground-dev-terraform-state-s3". The s3 bucket is created during the deployment.

## Deployment consists of the below scripts

The deployment contains the below scripts and should be run in the indicated order.

1. Configure vars.tf
1. terraform_s3_state_bucket.tf
1. teraform_backend_state_config.tf
1. deploy_aws_env.tf

## AWS Services used in the deployment

* EC2
* ELB
* ROUTE53
* RDS
* Managed Services (SSM)
* S3
* IAM
* AWS Certificate Manager

## Notes

To deploy the script, navigate to the working directory where the package was extracted and run the following commands in your terminal / powershell session.

* terraform init
* terraform plan
* terraform apply