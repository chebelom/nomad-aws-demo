provider "aws" {
  region = var.region
}

data "aws_vpc" "default" {
  default = true
}

data "http" "myip" {
  url = "http://ipv4.icanhazip.com"
}

resource "aws_security_group" "nomad_ui_ingress" {
  name   = "${var.name}-ui-ingress"
  vpc_id = data.aws_vpc.default.id

  # Nomad
  ingress {
    from_port   = 4646
    to_port     = 4646
    protocol    = "tcp"
    cidr_blocks = [var.allowlist_ip, "${chomp(data.http.myip.response_body)}/32"]
  }

  ingress {
    from_port = 0
    to_port   = 0
    protocol  = "-1"
    self      = true
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "ssh_ingress" {
  name   = "${var.name}-ssh-ingress"
  vpc_id = data.aws_vpc.default.id

  # SSH
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.allowlist_ip, "${chomp(data.http.myip.response_body)}/32"]
  }

  ingress {
    from_port = 0
    to_port   = 0
    protocol  = "-1"
    self      = true
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "allow_all_internal" {
  name   = "${var.name}-allow-all-internal"
  vpc_id = data.aws_vpc.default.id

  ingress {
    from_port = 0
    to_port   = 0
    protocol  = "-1"
    self      = true
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "clients_ingress" {
  name   = "${var.name}-clients-ingress"
  vpc_id = data.aws_vpc.default.id

  ingress {
    from_port = 0
    to_port   = 0
    protocol  = "-1"
    self      = true
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Add application ingress rules here
  # These rules are applied only to the client nodes

  # nginx example
  # ingress {
  #   from_port   = 80
  #   to_port     = 80
  #   protocol    = "tcp"
  #   cidr_blocks = ["0.0.0.0/0"]
  # }
}

resource "aws_instance" "server" {
  ami                    = var.ami
  instance_type          = var.server_instance_type
  key_name               = var.key_name
  vpc_security_group_ids = [aws_security_group.nomad_ui_ingress.id, aws_security_group.ssh_ingress.id, aws_security_group.allow_all_internal.id]
  count                  = var.server_count
  user_data = templatefile("${path.module}/config/install-server.sh.tpl", {
    SERVER_NUMBER     = var.server_count
    RETRY_JOIN        = var.retry_join
    NOMAD_ENT         = var.nomad_ent
    NOMAD_LICENSE     = var.nomad_license
    DC                = var.nomad_dc
    ACL_ENABLED       = var.nomad_acl_enabled
    NOMAD_VERSION     = var.nomad_version
    NOMAD_TLS_ENABLED = var.nomad_tls_enabled
    NOMAD_CA_PEM                  = fileexists("${var.nomad_ca_pem}") ? file("${var.nomad_ca_pem}") : ""
    NOMAD_SERVER_PEM              = fileexists("${var.nomad_server_pem}") ? file("${var.nomad_server_pem}") : ""
    NOMAD_SERVER_KEY              = fileexists("${var.nomad_server_key}") ? file("${var.nomad_server_key}") : ""
    NOMAD_TLS_VERIFY_HTTPS_CLIENT = var.nomad_tls_verify_https_client
  })

  # instance tags
  # NomadAutoJoin is necessary for nodes to automatically join the cluster
  tags = merge(
    {
      "Name" = "${var.name}-server-${count.index}"
    },
    {
      "NomadAutoJoin" = "auto-join"
    },
    {
      "NomadType" = "server"
    }
  )

  root_block_device {
    volume_type           = "gp2"
    volume_size           = var.root_block_device_size
    delete_on_termination = "true"
  }

  iam_instance_profile = aws_iam_instance_profile.instance_profile.name

  metadata_options {
    http_endpoint          = "enabled"
    instance_metadata_tags = "enabled"
  }
}

resource "aws_instance" "client" {
  ami                    = var.ami
  instance_type          = var.client_instance_type
  key_name               = var.key_name
  vpc_security_group_ids = [aws_security_group.nomad_ui_ingress.id, aws_security_group.ssh_ingress.id, aws_security_group.clients_ingress.id, aws_security_group.allow_all_internal.id]
  count                  = var.client_count
  depends_on             = [aws_instance.server]

  # instance tags
  # NomadAutoJoin is necessary for nodes to automatically join the cluster
  tags = merge(
    {
      "Name" = "${var.name}-client-${count.index}"
    },
    {
      "NomadAutoJoin" = "auto-join"
    },
    {
      "NomadType" = "client"
    }
  )

  root_block_device {
    volume_type           = "gp2"
    volume_size           = var.root_block_device_size
    delete_on_termination = "true"
  }

  ebs_block_device {
    device_name           = "/dev/xvdd"
    volume_type           = "gp2"
    volume_size           = "50"
    delete_on_termination = "true"
  }


  user_data = templatefile("${path.module}/config/install-client.sh.tpl", {
    DC                = var.nomad_dc
    RETRY_JOIN        = var.retry_join
    NOMAD_ENT         = var.nomad_ent
    ACL_ENABLED       = var.nomad_acl_enabled
    NOMAD_VERSION     = var.nomad_version
    NOMAD_TLS_ENABLED = var.nomad_tls_enabled
    NOMAD_CA_PEM      = fileexists("${var.nomad_ca_pem}") ? file("${var.nomad_ca_pem}") : ""
    NOMAD_CLIENT_PEM              = fileexists("${var.nomad_client_pem}") ? file("${var.nomad_client_pem}") : ""
    NOMAD_CLIENT_KEY              = fileexists("${var.nomad_client_key}") ? file("${var.nomad_client_key}") : ""
    NOMAD_TLS_VERIFY_HTTPS_CLIENT = var.nomad_tls_verify_https_client
  })

  iam_instance_profile = aws_iam_instance_profile.instance_profile.name

  metadata_options {
    http_endpoint          = "enabled"
    instance_metadata_tags = "enabled"
  }
}

resource "aws_iam_instance_profile" "instance_profile" {
  name_prefix = var.name
  role        = aws_iam_role.instance_role.name
}

resource "aws_iam_role" "instance_role" {
  name_prefix        = var.name
  assume_role_policy = data.aws_iam_policy_document.instance_role.json
}

data "aws_iam_policy_document" "instance_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role_policy" "auto_discover_cluster" {
  name   = "${var.name}-auto-discover-cluster"
  role   = aws_iam_role.instance_role.id
  policy = data.aws_iam_policy_document.auto_discover_cluster.json
}

data "aws_iam_policy_document" "auto_discover_cluster" {
  statement {
    effect = "Allow"

    actions = [
      "ec2:DescribeInstances",
      "ec2:DescribeTags",
      "autoscaling:DescribeAutoScalingGroups",
    ]

    resources = ["*"]
  }
}