provider "aws" {
  access_key = var.access_key
  secret_key = var.secret_key
  region     = var.region
}

#VPC
resource "aws_vpc" "aws-playground-dev-vpc" {
    cidr_block = "10.0.0.0/16"
    enable_dns_support = "true"
    enable_dns_hostnames = "true"
    enable_classiclink = "false"
    instance_tenancy = "default"

    tags = {
      service = "DEV"
    }       
}

#SUBNETS
resource "aws_subnet" "PUB-1" {
    vpc_id = aws_vpc.aws-playground-dev-vpc.id
    cidr_block = "10.0.1.0/24"
    map_public_ip_on_launch = "true"
    availability_zone = "eu-west-1a"
}

resource "aws_subnet" "PVT-1" {
    vpc_id = aws_vpc.aws-playground-dev-vpc.id
    cidr_block = "10.0.2.0/24"
    map_public_ip_on_launch = "false"
    availability_zone = "eu-west-1b"     
}

resource "aws_subnet" "DATA-1" {
    vpc_id = aws_vpc.aws-playground-dev-vpc.id
    cidr_block = "10.0.3.0/24"
    map_public_ip_on_launch = "false"
    availability_zone = "eu-west-1c"  
}

#EC2 SECURITY GROUP
resource "aws_security_group" "nginx_sg" {
  name        = "allow_http_https"
  description = "Allow http and https inbound traffic"
  vpc_id      = aws_vpc.aws-playground-dev-vpc.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["10.0.2.0/24"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["10.0.2.0/24"]
  }

  egress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    cidr_blocks     = ["0.0.0.0/0"]
  }
}

#VPC ENDPOINTS FOR SSM
resource "aws_vpc_endpoint" "ssm" {
  vpc_id            = aws_vpc.aws-playground-dev-vpc.id
  service_name      = "com.amazonaws.eu-west-1.ssm"
  vpc_endpoint_type = "Interface"

  security_group_ids = [aws_security_group.nginx_sg.id]

  subnet_ids          = [aws_subnet.PUB-1.id,aws_subnet.PVT-1.id,aws_subnet.DATA-1.id]
  private_dns_enabled = true
}

resource "aws_vpc_endpoint" "ec2messages" {
  vpc_id            = aws_vpc.aws-playground-dev-vpc.id
  service_name      = "com.amazonaws.eu-west-1.ec2messages"
  vpc_endpoint_type = "Interface"

  security_group_ids = [aws_security_group.nginx_sg.id]

  subnet_ids          = [aws_subnet.PUB-1.id,aws_subnet.PVT-1.id,aws_subnet.DATA-1.id]
  private_dns_enabled = true
}

resource "aws_vpc_endpoint" "ssmmessages" {
  vpc_id            = aws_vpc.aws-playground-dev-vpc.id
  service_name      = "com.amazonaws.eu-west-1.ssmmessages"
  vpc_endpoint_type = "Interface"

  security_group_ids = [aws_security_group.nginx_sg.id]

  subnet_ids          = [aws_subnet.PUB-1.id,aws_subnet.PVT-1.id,aws_subnet.DATA-1.id]
  private_dns_enabled = true
}

#INTERNET GATEWAY
resource "aws_internet_gateway" "my_internet_gateway" {
  vpc_id = aws_vpc.aws-playground-dev-vpc.id
    tags = {
    Name = "MAIN"
  }
}

#ROUTE TABLE
resource "aws_route_table" "my_route_table" {
  vpc_id = aws_vpc.aws-playground-dev-vpc.id
   
    route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.my_internet_gateway.id
   
  }
}

resource "aws_route" "my_route" {
  route_table_id            = aws_route_table.my_route_table.id
  destination_cidr_block    = "0.0.0.0/0"
  gateway_id = aws_internet_gateway.my_internet_gateway.id
}

resource "aws_route_table_association" "my_rt_association" {
  subnet_id      = aws_subnet.PVT-1.id
  route_table_id = aws_route_table.my_route_table.id
 }

#SSM IAM ROLE
 resource "aws_iam_instance_profile" "test_profile" {
  name = "MY_IAM_INSTANCE_PROFILE"
  role = "SSM_EC2_ACCESS_ROLE"
}

resource "aws_iam_role" "SSM_EC2_ACCESS_ROLE" {
  name = "SSM_EC2_ACCESS_ROLE"

  assume_role_policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
POLICY
}

#SSM EC2 POLICY
resource "aws_iam_role_policy_attachment" "test-attach" {
  role       = "SSM_EC2_ACCESS_ROLE"
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2RoleforSSM"
  depends_on = [aws_iam_role.SSM_EC2_ACCESS_ROLE]
}

#EC2 INSTANCE NGINX
	resource "aws_instance" "nginx_server" {
	ami = "ami-040ba9174949f6de4"
	instance_type = var.instance_type
	subnet_id = aws_subnet.PVT-1.id
    security_groups = [aws_security_group.nginx_sg.id]
    iam_instance_profile = "MY_IAM_INSTANCE_PROFILE"
    depends_on = [aws_iam_role.SSM_EC2_ACCESS_ROLE,
      aws_vpc_endpoint.ssm,
      aws_vpc_endpoint.ec2messages,
      aws_vpc_endpoint.ssmmessages
      ]
	  	user_data = <<-EOF
          #! /bin/bash 
          cd /tmp
          sudo yum install -y https://s3.amazonaws.com/ec2-downloads-windows/SSMAgent/latest/linux_amd64/amazon-ssm-agent.rpm
          sudo systemctl start amazon-ssm-agent
          sudo amazon-linux-extras install nginx1.12
          sudo service nginx start
          curl "https://s3.amazonaws.com/session-manager-downloads/plugin/latest/linux_64bit/session-manager-plugin.rpm" -o "session-manager-plugin.rpm"
          sudo yum install -y session-manager-plugin.rpm
	EOF

	root_block_device {
    volume_size           = var.volume_size
    volume_type           = "standard"
    delete_on_termination = "true"
  }
}

#R53 DOMAIN
resource "aws_route53_zone" "private" {
  name = "aws-playground.com"

  vpc {
    vpc_id = aws_vpc.aws-playground-dev-vpc.id
    vpc_region = var.region
  }
}

/*
#Private CA
resource "aws_acm_certificate" "cert" {
  domain_name       = "aws-playground.com"
  validation_method = "DNS"
}

data "aws_route53_zone" "zone" {
  name         = "aws-playground.com"
  private_zone = false
}

resource "aws_route53_record" "cert_validation" {
  name    = aws_acm_certificate.cert.domain_validation_options.0.resource_record_name
  type    = aws_acm_certificate.cert.domain_validation_options.0.resource_record_type
  zone_id = data.aws_route53_zone.zone.id
  records = [aws_acm_certificate.cert.domain_validation_options.0.resource_record_value]
  ttl     = 60
}

resource "aws_acm_certificate_validation" "cert" {
  certificate_arn         = aws_acm_certificate.cert.arn
  validation_record_fqdns = [aws_route53_record.cert_validation.fqdn]
}

resource "aws_lb_listener" "front_end" {
  certificate_arn = aws_acm_certificate_validation.cert.certificate_arn
}
*/

#S3 BUCKET FOR ELB LOGS
resource "aws_s3_bucket" "aws-playground-dev-elb-access-logs" {
    bucket = "aws-playground-dev-elb-access-logs"
 
    versioning {
      enabled = true
    }
 }

resource "aws_s3_bucket_policy" "aws-playground-dev-elb-access-logs-policy" {
  bucket = aws_s3_bucket.aws-playground-dev-elb-access-logs.id
  depends_on = [aws_s3_bucket.aws-playground-dev-elb-access-logs]

  policy = <<POLICY
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Principal": {
                "AWS": "arn:aws:iam::156460612806:root"
            },
            "Action": "s3:PutObject",
            "Resource": "arn:aws:s3:::aws-playground-dev-elb-access-logs/logs/*"
        }
    ]
}
POLICY
}

#ELB
resource "aws_elb" "aws-playground-elb" {
  depends_on = [aws_s3_bucket_policy.aws-playground-dev-elb-access-logs-policy]
  name               = "aws-playground-elb"
  subnets            = [aws_subnet.PVT-1.id]

    access_logs {
    bucket        = "aws-playground-dev-elb-access-logs"
    bucket_prefix = "logs"
    interval      = 60
  }

  listener {
    instance_port     = 8000
    instance_protocol = "http"
    lb_port           = 80
    lb_protocol       = "http"
  }

  listener {
    instance_port      = 8000
    instance_protocol  = "http"
    lb_port            = 443
    lb_protocol        = "https"
    ssl_certificate_id = "arn:aws:acm:eu-west-1:470211349934:certificate/6d16a44b-7b02-4c4b-8195-cc15be34a55e"
  }

  health_check {
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 3
    target              = "HTTP:8000/"
    interval            = 30
  }

  instances                   = [aws_instance.nginx_server.id]
  cross_zone_load_balancing   = true
  idle_timeout                = 400
  connection_draining         = true
  connection_draining_timeout = 400

 }

#RDS MYSQL DB
resource "aws_db_subnet_group" "data" {
  name       = "data"
  subnet_ids = [aws_subnet.DATA-1.id,aws_subnet.PVT-1.id]

  tags = {
    Name = "MYSQL DB SUBNET GROUP"
  }
}

resource "aws_db_instance" "default" {
  allocated_storage    = 20
  storage_type         = "gp2"
  engine               = "mysql"
  engine_version       = "5.7"
  instance_class       = var.instance_class
  name                 = var.name
  username             = var.username
  password             = var.password
  parameter_group_name = "default.mysql5.7"
  db_subnet_group_name = "data"
  skip_final_snapshot = "true"
  depends_on = [aws_db_subnet_group.data]
}

#OUTPUTS
output "aws_mysql_db_instance_username" {
  value = aws_db_instance.default.username
}

output "aws_msyql_db_instance_password" {
  value = aws_db_instance.default.password
}

output "aws_mysql_db_instance_endpoint" {
  value = aws_db_instance.default.endpoint
}

output "aws_elb_dns" {
  value = aws_elb.aws-playground-elb.dns_name
}