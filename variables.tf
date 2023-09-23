variable "vpc_info" {
  type = map(any)
  default = {
    "vpc_name" = "core_vpc"
    "vpc_cidr" = "10.0.0.0/16"
  }
}

variable "vpc_subnet_info" {
  type = map(list(string))
  default = {
    "azs"                   = ["us-east-1a", "us-east-1b"]
    "private_subnet_blocks" = ["10.0.128.0/18", "10.0.192.0/18"]
    "public_subnet_blocks"  = ["10.0.0.0/18", "10.0.64.0/18"]
  }
}

variable "ami_info" {
  type = map(string)
  default = {
    "ami"           = "ami-07a08a4db68024330"
    "instance_type" = "t2.micro"
  }
}

variable "ssl_info" {
  type = map(string)
  default = {
    "ssl_policy"      = "ELBSecurityPolicy-TLS13-1-2-2021-06"
    "certificate_arn" = "arn:aws:acm:us-east-1:373319509873:certificate/ef26f7f5-7467-4631-bade-a0a2af7a8221"
  }
}

variable "asg_info" {
  type = map(any)
  default = {
    desired_capacity = 1
    max_size         = 4
    min_size         = 1
  }
}

variable "r53_info" {
  type = map(any)
  default = {
    zone_id = "Z09701283QE4WGGR7BYQV"
  }
}
