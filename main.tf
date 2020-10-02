#
# Key Pair Creation
#
resource "aws_key_pair" "public_key" {
  key_name   = "${var.userid}_public_key"
  public_key = file("~/.ssh/id_rsa.pub")
}
#
# provider creation
#
provider "aws" {
  region  = var.region
}
#
# vpc creation
#
resource "aws_vpc" "vpc1" {
  cidr_block       = var.vpc1-cidr

  enable_dns_hostnames = true
  enable_dns_support =true
  instance_tenancy ="default"
  tags = {
    Name = "${var.userid}-vpc"
  }
}
#
# subnet creation
#
resource "aws_subnet" "subnet1" {
  vpc_id            = aws_vpc.vpc1.id
  availability_zone = var.az1
  cidr_block        = var.subnet1-cidr

  tags  = {
    Name = "${var.userid}-subnet1"
  }
}

resource "aws_subnet" "subnet2" {
  vpc_id            = aws_vpc.vpc1.id
  availability_zone = var.az2
  cidr_block        = var.subnet2-cidr

  tags  = {
    Name = "${var.userid}-subnet2"
  }
}
#
# internet gateway creation
#
resource "aws_internet_gateway" "igw1" {
  vpc_id = aws_vpc.vpc1.id

  tags = {
    Name = "${var.userid}-igw1"
  }
}
#
# routing table creation
#
resource "aws_route_table" "rt1" {
  vpc_id = aws_vpc.vpc1.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw1.id
  }

  tags = {
    Name = "${var.userid}-rt1"
  }
}

resource "aws_route_table_association" "rt1_subnet1" {
  subnet_id      = aws_subnet.subnet1.id
  route_table_id = aws_route_table.rt1.id
}

resource "aws_route_table_association" "rt1_subnet2" {
  subnet_id      = aws_subnet.subnet2.id
  route_table_id = aws_route_table.rt1.id
}
#
# default security group creation for alb
#
resource "aws_default_security_group" "sg1_default" {
  vpc_id = aws_vpc.vpc1.id

  ingress {
    from_port = 80
    to_port   = 80
    protocol  = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.userid}-sg1_default"
  }
}
#
# alb, alb target group, alb listener creation
#
resource "aws_alb" "alb1" {
    name = "${var.userid}-alb1"
    internal = false
    security_groups = [aws_security_group.sg1_ec2.id]
    subnets = [
        aws_subnet.subnet1.id,
        aws_subnet.subnet2.id
    ]
    tags = {
        Name = "${var.userid}-ALB1"
    }
    lifecycle { create_before_destroy = true }
}

resource "aws_alb_target_group" "tg1" {
    name = "${var.userid}-tg1"
    port = 80
    protocol = "HTTP"
    vpc_id = aws_vpc.vpc1.id
    health_check {
        interval = 30
        path = "/"
        healthy_threshold = 3
        unhealthy_threshold = 3
    }
    tags = { Name = "${var.userid}-tg1" }
}

resource "aws_alb_listener" "alb1-listener" {
    load_balancer_arn = aws_alb.alb1.arn
    port = "80"
    protocol = "HTTP"
    default_action {
        target_group_arn = aws_alb_target_group.tg1.arn
        type = "forward"
    }
}
#
# ec2 security group creation
#
resource "aws_security_group" "sg1_ec2" {
  name        = "allow_http_ssh"
  description = "Allow HTTP/SSH inbound connections"
  vpc_id = aws_vpc.vpc1.id

  //allow http 80 port from alb
  ingress { 
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  //allow ssh 22 port from my_ip(cloud9)
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.cloud9-cidr]
  }

  egress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    cidr_blocks     = ["0.0.0.0/0"]
  }

  tags = {
    Name = "Allow HTTP/SSH Security Group"
  }
}
#
# ec2 autoscaling configuration
#
resource "aws_iam_instance_profile" "instance-profile" {
  name = "${var.userid}-instance-profile"
  role = aws_iam_role.WebAppRole.name
}

resource "aws_launch_configuration" "lc1" {
  name_prefix = "${var.userid}-autoscaling-instance-"
  iam_instance_profile = aws_iam_instance_profile.instance-profile.name

  image_id = var.ami-id
  instance_type = "t2.micro"
  key_name = aws_key_pair.public_key.key_name
  security_groups = [
    "${aws_security_group.sg1_ec2.id}",
    "${aws_default_security_group.sg1_default.id}",
  ]
  associate_public_ip_address = true
    
  lifecycle {
    create_before_destroy = true
  }
  user_data = <<EOF
    #!/bin/bash
    sudo yum update -y
    sudo yum install -y aws-cli
    sudo yum install -y git
    sudo yum install -y ruby
    cd /home/ec2-user/
    sudo wget https://aws-codedeploy-${var.region}.s3.amazonaws.com/latest/codedeploy-agent.noarch.rpm
    sudo yum -y install /home/ec2-user/codedeploy-agent.noarch.rpm
    sudo service codedeploy-agent start
	EOF
}
#
# autoscaling group creation
#
resource "aws_autoscaling_group" "asg1" {
  name = "${aws_launch_configuration.lc1.name}-asg1"

  min_size             = 1
  desired_capacity     = 2
  max_size             = 3

  health_check_type    = "ELB"

  launch_configuration = aws_launch_configuration.lc1.name

  enabled_metrics = [
    "GroupMinSize",
    "GroupMaxSize",
    "GroupDesiredCapacity",
    "GroupInServiceInstances",
    "GroupTotalInstances"
  ]

  metrics_granularity="1Minute"

  vpc_zone_identifier  = [
    aws_subnet.subnet1.id,
    aws_subnet.subnet2.id
  ]

  # Required to redeploy without an outage.
  lifecycle {
    create_before_destroy = true
  }

  tag {
    key                 = "Name"
    value               = "${var.userid}-instance-autoscaling"
    propagate_at_launch = true
  }
}

resource "aws_autoscaling_attachment" "asg1-attachment" {
  autoscaling_group_name = aws_autoscaling_group.asg1.id
  alb_target_group_arn   = aws_alb_target_group.tg1.arn
}
#
#  autoscaling policy by ALB Request Count Per Target
#
resource "aws_autoscaling_policy" "auto-scaling-policy" {
  name                      = "${var.userid}-instance-tracking-policy"
  policy_type               = "TargetTrackingScaling"
  autoscaling_group_name    = aws_autoscaling_group.asg1.name
  estimated_instance_warmup = 200

  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ALBRequestCountPerTarget"
      resource_label = "${aws_alb.alb1.arn_suffix}/${aws_alb_target_group.tg1.arn_suffix}"
    }
    
    target_value = "1" #ALBRequestCountPerTarget Request 1
  }
}
#
#
#
#
#
#########################################################
#  CICD Pipeline Creation
#########################################################
#
#
#
#
#
resource "aws_codecommit_repository" "WebAppRepo" {
  repository_name = "WebAppRepo"
  description     = "${var.userid}-WebApp-Repository"

  tags = {
    Name        = "${var.userid}-WebAppRepo"
    Creator     = var.userid
  }
}

resource "aws_codebuild_project" "devops-webapp-project" {
  name          = "${var.userid}-devops-webapp-project"
  description   = "test_codebuild_project"
  build_timeout = "5"
  service_role  = aws_iam_role.BuildTrustRole.arn

  artifacts {
    type = "S3"
    location = aws_s3_bucket.S3Bucket.bucket
    packaging = "ZIP"
    name = "WebAppOutputArtifact.zip"
  }

  environment {
    type  = "LINUX_CONTAINER"
    image = "aws/codebuild/java:openjdk-8"
    compute_type = "BUILD_GENERAL1_SMALL"
  }

  source {
    type            = "CODECOMMIT"
    location        = "https://git-codecommit.${var.region}.amazonaws.com/v1/repos/WebAppRepo"
  }

  tags = {
    Name        = "${var.userid}-devops-webapp-project"
    Environment = "Test"
  }
}

resource "aws_codedeploy_app" "CodedeployApp" {
  compute_platform = "Server"
  name             = "${var.userid}-DevOps-WebApp"
}

resource "aws_codedeploy_deployment_group" "CodedeployDeploymentGroup-Dev" {
  app_name              = aws_codedeploy_app.CodedeployApp.name
  deployment_group_name = "${var.userid}-CodedeployDeploymentGroup-Dev"
  service_role_arn      = aws_iam_role.DeployTrustRole.arn
  deployment_config_name = "CodeDeployDefault.OneAtATime"
  #deployment_config_name = "CodeDeployDefault.AllAtOnce"

  load_balancer_info {
    elb_info {
      name = aws_alb.alb1.name
    }
  }
  
  #ec2_tag_filter {
  #   key   = "Name"
  #   type  = "KEY_AND_VALUE"
  #   value = "${var.userid}-web-autoscaling-80"
  #}
  
  autoscaling_groups = [aws_autoscaling_group.asg1.name]
}

resource "aws_codepipeline" "CodePipeline" {
  name     = "${var.userid}-CodePipeline"
  role_arn = aws_iam_role.PipelineTrustRole.arn

  artifact_store {
    location = aws_s3_bucket.S3Bucket.bucket
    type     = "S3"
  }

  stage {
    name = "Source"

    action {
      name             = "Source"
      category         = "Source"
      owner            = "AWS"
      provider         = "CodeCommit"
      version          = "1"
      output_artifacts = ["source_output"]

      configuration = {
        RepositoryName   = "WebAppRepo"
        BranchName = "master"
        PollForSourceChanges = "false"
      }
    }
  }

  stage {
    name = "Build"

    action {
      name             = "Build"
      category         = "Build"
      owner            = "AWS"
      provider         = "CodeBuild"
      input_artifacts  = ["source_output"]
      output_artifacts = ["build_output"]
      version          = "1"

      configuration = {
        ProjectName = "${var.userid}-devops-webapp-project"
      }
    }
  }

  stage {
    name = "Deploy"

    action {
      name            = "Deploy"
      category        = "Deploy"
      owner           = "AWS"
      provider        = "CodeDeploy"
      input_artifacts = ["build_output"]
      version         = "1"

      configuration = {
        ApplicationName = "${var.userid}-DevOps-WebApp"
        DeploymentGroupName = "${var.userid}-CodedeployDeploymentGroup-Dev"
      }
    }
  }
}
#
#
#
#
#
#########################################################
#  CIDE Pipeline AWS Role Creation
#########################################################
#
#
#
#
#
#
# AWS Management Consol Account ID Import
#
data "aws_caller_identity" "current" {}
#
# S3 Bucket creation for CodePipeline
#
resource "aws_s3_bucket" "S3Bucket" {
    bucket  = "skcc-cicd-workshop-${var.region}-${var.userid}-${data.aws_caller_identity.current.account_id}"
    acl     = "private"
    
    versioning {
        enabled = true
    }
    
	tags = {
		Name = "CICDWorkshop-S3Bucket"
		Environment = "Dev"
	}
}
#
# Build Role Creation
#
resource "aws_iam_role" "BuildTrustRole" {
    name = "${var.userid}-BuildTrustRole"
    path = "/"
    
    assume_role_policy = <<-EOF
    {
        "Version": "2012-10-17",
        "Statement": [
            {
                "Sid": "1",
                "Effect": "Allow",
                "Principal": {
                    "Service": [
                        "codebuild.amazonaws.com"
                    ]
                },
                "Action": "sts:AssumeRole"
            }
        ]
    }
    EOF
    
    tags = {
        tag-key = "${var.userid}_BuildTrustRole"
    }
}

resource "aws_iam_role_policy" "CodeBuildRolePolicy" {
    name = "${var.userid}-CodeBuildRolePolicy"
    role = aws_iam_role.BuildTrustRole.id

    policy = <<-EOF
    {
      "Version": "2012-10-17",
          "Statement": [
            {
              "Sid": "CloudWatchLogsPolicy",
              "Effect": "Allow",
              "Action": [
                "logs:CreateLogGroup",
                "logs:CreateLogStream",
                "logs:PutLogEvents"
              ],
              "Resource": [
                "*"
              ]
            },
            {
              "Sid": "CodeCommitPolicy",
              "Effect": "Allow",
              "Action": [
                "codecommit:GitPull"
              ],
              "Resource": [
                "*"
              ]
            },
            {
              "Sid": "S3GetObjectPolicy",
              "Effect": "Allow",
              "Action": [
                "s3:GetObject",
                "s3:GetObjectVersion"
              ],
              "Resource": [
                "*"
              ]
            },
            {
              "Sid": "S3PutObjectPolicy",
              "Effect": "Allow",
              "Action": [
                "s3:PutObject"
              ],
              "Resource": [
                "*"
              ]
            },
            {
              "Sid": "OtherPolicies",
              "Effect": "Allow",
              "Action": [
                "ssm:GetParameters",
                "ecr:*"
              ],
              "Resource": [
                "*"
              ]
            }
          ]
    }
    EOF
}

#
# Deploy Role Creation
#
resource "aws_iam_role" "DeployTrustRole" {
    name = "${var.userid}-DeployTrustRole"
    path = "/"
    
    assume_role_policy = <<-EOF
    {
        "Version": "2012-10-17",
        "Statement": [
            {
                "Sid" : "",
                "Effect" : "Allow",
                "Principal" : {
                    "Service": [
                        "codedeploy.amazonaws.com"
                    ]
                },
                "Action" : "sts:AssumeRole"
            }
        ]
    }
    EOF
}

resource "aws_iam_role_policy_attachment" "role_policy_attach_AWSCodeDeployRole" {
  role       = aws_iam_role.DeployTrustRole.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSCodeDeployRole"
}

#
# Pipeline Role Creation
#
resource "aws_iam_role" "PipelineTrustRole" {
    name = "${var.userid}-PipelineTrustRole"
    path = "/"
    
    assume_role_policy = <<-EOF
    {
        "Version": "2012-10-17",
        "Statement": [
            {
                "Sid": "1",
                "Effect": "Allow",
                "Principal": {
                    "Service": [
                        "codepipeline.amazonaws.com"
                    ]
                },
                "Action": "sts:AssumeRole"
            }
        ]
    }
    EOF
}

resource "aws_iam_role_policy" "CodePipelineRolePolicy" {
    name = "${var.userid}-CodePipelineRolePolicy"
    role = aws_iam_role.PipelineTrustRole.id

    policy = <<-EOF
    {
        "Version": "2012-10-17",
        "Statement": [
        {
            "Action": [
                "s3:*"
            ],
            "Resource": ["*"],
            "Effect": "Allow"
        },
        {
            "Action": [
                "codecommit:GetBranch",
                "codecommit:GetCommit",
                "codecommit:UploadArchive",
                "codecommit:GetUploadArchiveStatus",
                "codecommit:CancelUploadArchive"
            ],
            "Resource": "*",
            "Effect": "Allow"
        },
        {
            "Action": [
                "codepipeline:*",
                "iam:ListRoles",
                "iam:PassRole",
                "codedeploy:CreateDeployment",
                "codedeploy:GetApplicationRevision",
                "codedeploy:GetDeployment",
                "codedeploy:GetDeploymentConfig",
                "codedeploy:RegisterApplicationRevision",
                "lambda:*",
                "sns:*",
                "ecs:*",
                "ecr:*"
            ],
            "Resource": "*",
            "Effect": "Allow"
        },
        {
            "Action": [
                "codebuild:StartBuild",
                "codebuild:StopBuild",
                "codebuild:BatchGet*",
                "codebuild:Get*",
                "codebuild:List*",
                "codecommit:GetBranch",
                "codecommit:GetCommit",
                "codecommit:GetRepository",
                "codecommit:ListBranches",
                "s3:GetBucketLocation",
                "s3:ListAllMyBuckets"
            ],
            "Effect": "Allow",
            "Resource": "*"
        },
        {
            "Action": [
                "logs:GetLogEvents"
            ],
            "Effect": "Allow",
            "Resource": "arn:aws:logs:*:*:log-group:/aws/codebuild/*:log-stream:*"
        }]
    }
    EOF
}
#
# Lambda Role Creation
#
resource "aws_iam_role" "CodePipelineLambdaExecRole" {
    name = "${var.userid}-CodePipelineLambdaExecRole"
    path = "/"
    
    assume_role_policy = <<-EOF
    {
        "Version": "2012-10-17",
        "Statement": [
            {
                "Sid": "1",
                "Effect": "Allow",
                "Principal": {
                    "Service": [
                        "lambda.amazonaws.com"
                    ]
                },
                "Action": "sts:AssumeRole"
            }
        ]
    }
    EOF
}

resource "aws_iam_role_policy" "CodePipelineLambdaExecPolicy" {
    name = "${var.userid}-CodePipelineLambdaExecPolicy"
    role = aws_iam_role.CodePipelineLambdaExecRole.id

    policy = <<-EOF
    {
        "Version": "2012-10-17",
        "Statement": [
        {
            "Action": [
                "logs:CreateLogGroup",
                "logs:CreateLogStream",
                "logs:PutLogEvents"
            ],
            "Effect": "Allow",
            "Resource": "arn:aws:logs:*:*:*"
        },
        {
            "Action": [
                "codepipeline:PutJobSuccessResult",
                "codepipeline:PutJobFailureResult"
            ],
            "Effect": "Allow",
            "Resource": "*"
        }]
    }
    EOF
}
#
### IAM Role Createion (EC2 인스턴스에 WebApp 소스 입력 역할, 권한 부여)
#
resource "aws_iam_role" "WebAppRole" {
    name = "${var.userid}-WebAppRole"
    path = "/"
    
    assume_role_policy = <<-EOF
    {
        "Version": "2012-10-17",
        "Statement": [
            {
                "Sid": "",
                "Effect": "Allow",
                "Principal": {
                    "Service": "ec2.amazonaws.com"
                },
                "Action": "sts:AssumeRole"
            }
        ]
    }
    EOF
}

resource "aws_iam_role_policy" "WebAppRolePolicy" {
    name = "${var.userid}-BackendRole"
    role = aws_iam_role.WebAppRole.id

    policy = <<-EOF
    {
        "Version": "2012-10-17",
        "Statement": [
        {
            "Action": [
                "autoscaling:Describe*",
                "autoscaling:EnterStandby",
                "autoscaling:ExitStandby",
                "autoscaling:UpdateAutoScalingGroup"
            ],
            "Resource": "*",
            "Effect": "Allow"
        },
        {
            "Action": [
                "ec2:DescribeInstances",
                "ec2:DescribeInstanceStatus"
            ],
            "Resource": "*",
            "Effect": "Allow"
        },
        {
            "Action": [
                "s3:Get*",
                "s3:List*"
            ],
            "Resource": [
                "arn:aws:s3:::skcc-cicd-workshop-${var.region}-${var.userid}-${data.aws_caller_identity.current.account_id}",
                "arn:aws:s3:::skcc-cicd-workshop-${var.region}-${var.userid}-${data.aws_caller_identity.current.account_id}/*",
                "arn:aws:s3:::codepipeline-*"
            ],
            "Effect": "Allow"
        }]
    }
    EOF
}

resource "aws_iam_role_policy_attachment" "role_policy_attach_AWSCodeDeployReadOnlyAccess" {
  role       = aws_iam_role.WebAppRole.name
  policy_arn = "arn:aws:iam::aws:policy/AWSCodeDeployReadOnlyAccess"
}
resource "aws_iam_role_policy_attachment" "role_policy_attach_AmazonEC2ReadOnlyAccess" {
  role       = aws_iam_role.WebAppRole.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ReadOnlyAccess"
}
