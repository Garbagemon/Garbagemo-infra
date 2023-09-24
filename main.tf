provider "aws" {
  region                   = "us-east-1"
  shared_credentials_files = ["~/.aws/credentials"]
  profile                  = "personal-general"
}

# Networking
module "vpc" {
  source = "terraform-aws-modules/vpc/aws"

  name = var.vpc_info.vpc_name
  cidr = var.vpc_info.vpc_cidr

  azs             = var.vpc_subnet_info.azs
  private_subnets = var.vpc_subnet_info.private_subnet_blocks
  public_subnets  = var.vpc_subnet_info.public_subnet_blocks

  map_public_ip_on_launch = true
  enable_nat_gateway      = true
  nat_eip_tags = {
    "Name" = "nat-EIP"
  }
  nat_gateway_tags = {
    "Name" = "natgw"
  }

  create_igw = true
  igw_tags = {
    "Name" = "igw-main"
  }
}

resource "aws_security_group" "allow_web_sg" {
  name   = "Allow SSH and HTTP from anywhere"
  vpc_id = module.vpc.vpc_id

  ingress {
    description = "SSH from anywhere"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "80 from anywhere"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "443 from anywhere"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }


  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# IAM

resource "aws_iam_policy" "allow_ssm_param" {
  name        = "AllowAccessToSSMParamStoreForVarsThatInPathGarbagemon"
  description = "See Name"

  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Sid" : "AllowReadingForParamStoreVarsThatBeginWithGarbagemon",
        "Effect" : "Allow",
        "Action" : [
          "ssm:DescribeParameters"
        ],
        "Resource" : "*"
      },
      {
        "Sid" : "AllowGetForParamStoreVarsThatBeginWithGarbagemon",
        "Effect" : "Allow",
        "Action" : [
          "ssm:GetParameter",
          "ssm:GetParameters",
          "ssm:GetParametersByPath"
        ],
        "Resource" : "arn:aws:ssm:us-east-1:373319509873:parameter/garbagemon/*"
      }
    ]
  })
}

resource "aws_iam_policy" "allow_kms_decrypt_key" {
  name        = "AllowAccessToDefaultSSMKey"
  description = "See Name"

  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Sid" : "AllowAccessToDefaultSSMKey",
        "Effect" : "Allow",
        "Action" : [
          "kms:Decrypt",
          "kms:Encrypt",
          "kms:GenerateDataKey*",
          "kms:DescribeKey"
        ],
        "Resource" : [
          "arn:aws:kms:us-east-1:373319509873:key/9aa6f00a-4524-4f41-b92a-cfa65422f99f"
        ]
      }
    ]
  })
}

resource "aws_iam_policy" "allow_rekog_detectLabels" {
  name        = "AllowRekogDetectLabels"
  description = "See Name"

  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Effect" : "Allow",
        "Action" : "rekognition:DetectLabels",
        "Resource" : "*"
      }
    ]
    }
  )
}

resource "aws_dynamodb_table" "user_data_db" {
  name = "garbagemon_userdata"

  billing_mode   = "PROVISIONED"
  read_capacity  = 5
  write_capacity = 5

  hash_key       = "userId"
  stream_enabled = false


  attribute {
    name = "userId"
    type = "S" # Data type for userId (String)
  }
}


resource "aws_iam_policy" "allow_dynamodb_access" {
  name        = "AllowDynamaDBAccess"
  description = "See Name"

  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Effect" : "Allow",
        "Action" : [
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "dynamodb:UpdateItem",
          "dynamodb:DeleteItem"
        ],
        "Resource" : "${aws_dynamodb_table.user_data_db.arn}"
      }
    ]
    }
  )

}

resource "aws_iam_role" "ec2_ssm_role" {
  name = "AllowEC2ToAccessParamStoreViaSSMAndDecryptViaKMSAndRekog"
  assume_role_policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Effect" : "Allow",
        "Principal" : {
          "Service" : "ec2.amazonaws.com"
        },
        "Action" : "sts:AssumeRole"
      }
    ]
  })
  managed_policy_arns = [
    aws_iam_policy.allow_kms_decrypt_key.arn,
    aws_iam_policy.allow_ssm_param.arn,
    aws_iam_policy.allow_rekog_detectLabels.arn,
    aws_iam_policy.allow_dynamodb_access.arn
  ]
}

resource "aws_iam_instance_profile" "ec2_ssm_profile" {
  name = "AllowEC2ToAccessParamStoreViaSSMAndDecryptViaKMS"
  role = aws_iam_role.ec2_ssm_role.name
}



resource "aws_launch_template" "launch_template" {
  name          = "garbagemon-expressjs-backend-launch-temp"
  image_id      = var.ami_info.ami
  instance_type = var.ami_info.instance_type

  iam_instance_profile {
    arn = aws_iam_instance_profile.ec2_ssm_profile.arn
  }

  network_interfaces {
    device_index    = 0
    security_groups = [aws_security_group.allow_web_sg.id]
  }
  tag_specifications {
    resource_type = "instance"

    tags = {
      Name = "ASG-Backend-VM"
    }
  }
}

# Application Load Balancer Resources

resource "aws_lb" "alb" {
  name               = "expressjs-backend-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.allow_web_sg.id]
  subnets            = [for i in module.vpc.public_subnets : i]
}

resource "aws_lb_target_group" "target_group" {
  name     = "expressjs-backend-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = module.vpc.vpc_id

  health_check {
    path    = "/health-check"
    matcher = 200
  }
}

resource "aws_lb_listener" "alb_listener" {
  load_balancer_arn = aws_lb.alb.arn
  # port              = "80"
  # protocol          = "HTTP"
  port            = "443"
  protocol        = "HTTPS"
  ssl_policy      = var.ssl_info.ssl_policy
  certificate_arn = var.ssl_info.certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.target_group.arn
  }
}

# ASG

resource "aws_autoscaling_group" "backend_asg" {
  name                = "backend-ASG"
  desired_capacity    = var.asg_info.desired_capacity
  max_size            = var.asg_info.max_size
  min_size            = var.asg_info.min_size
  vpc_zone_identifier = [for i in module.vpc.private_subnets : i]
  target_group_arns   = [aws_lb_target_group.target_group.arn]

  launch_template {
    id      = aws_launch_template.launch_template.id
    version = aws_launch_template.launch_template.latest_version
  }
}

# ASG Policy
resource "aws_cloudwatch_metric_alarm" "cpu_alarm" {
  alarm_name          = "backend-cpu-alarm"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = "2" # Number of consecutive periods the metric must be above the threshold
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = "60"
  statistic           = "Average"
  threshold           = "70" # CPU utilization threshold for scaling
  alarm_description   = "Scale up when CPU utilization is above 70%"
  alarm_actions       = [aws_autoscaling_policy.scale_up_policy.arn]

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.backend_asg.name
  }
}

resource "aws_autoscaling_policy" "scale_up_policy" {
  name                   = "scale-up-policy"
  policy_type            = "SimpleScaling"
  scaling_adjustment     = 1 # Increase desired capacity by 1 when triggered
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 300 # Cooldown period in seconds before triggering another scaling action
  autoscaling_group_name = aws_autoscaling_group.backend_asg.name
}


resource "aws_route53_record" "backend_mapping" {
  zone_id = var.r53_info.zone_id
  name    = "garbagemon.backend-aws.com"
  type    = "CNAME"
  ttl     = 60
  records = [aws_lb.alb.dns_name]
}


