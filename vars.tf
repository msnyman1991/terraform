#AWS CREDENTIALS
variable "region" {
  default = "eu-west-1"
}

variable "access_key" {
  default = ""
}

variable "secret_key" {
  default = ""
}

#EC2
variable "instance_type" {
  default = "t2.medium"
}

variable "volume_size" {
  default = "20"
}

#RDS MYSQL DB
variable "instance_class" {
  default = "db.t2.micro"
}

variable "name" {
  default = "mydatabase"
}

variable "username" {
  default = "admin"
}

variable "password" {
  default = ""
}
