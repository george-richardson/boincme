locals {
  time = "${formatdate("YYYYMMDD-hhmm", timestamp())}"
  ami_name = "boincme-${local.time}"
}

source "amazon-ebs" "agent" {

  # Resulting AMI Options
  ami_name = local.ami_name
  snapshot_tags = {
    Name = local.ami_name
  }

  # Builder Options
  instance_type = "t3a.large"
  source_ami_filter {
    filters = {
      virtualization-type = "hvm"
      name                = "ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"
      root-device-type    = "ebs"
    }
    owners      = ["099720109477"]
    most_recent = true
  }

  run_tags = {
    Name = "boincme-builder-${local.time}"
  }

  vpc_filter {
    filters = {
      isDefault = true
    }
  }

  subnet_filter {
    random = true
  }

  temporary_iam_instance_profile_policy_document {
    Statement {
      Action = [
        "ssm:UpdateInstanceInformation",
        "ssmmessages:CreateControlChannel",
        "ssmmessages:CreateDataChannel",
        "ssmmessages:OpenControlChannel",
        "ssmmessages:OpenDataChannel"
      ]
      Effect   = "Allow"
      Resource = ["*"]
    }
    Statement {
      Action   = ["s3:GetEncryptionConfiguration"]
      Effect   = "Allow"
      Resource = ["*"]
    }
    Version = "2012-10-17"
  }

  # SSH
  ssh_interface = "session_manager"
  ssh_username  = "ubuntu"
}

build {
  sources = ["source.amazon-ebs.agent"]

  provisioner "file" {
    source = "./boinc-config/"
    destination = "/tmp"
  }

  provisioner "shell" {
    script = "./provision.sh"
  }
}