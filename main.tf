data "aws_region" "current" {}

resource "random_id" "consul_gossip_encryption_key" {
  byte_length = 32
}

data "template_file" "install_hashitools_consul" {
  template = file("${path.module}/scripts/install_hashitools_consul.sh.tpl")

  vars = {
    hashi_tools_rpm        = var.hashi_tools_rpm
    auto_join_tag          = var.auto_join_tag
    datacenter             = data.aws_region.current.name
    bootstrap_expect       = var.redundancy_zones ? length(split(",", var.subnets)) : var.consul_nodes
    total_nodes            = var.consul_nodes
    gossip_key             = random_id.consul_gossip_encryption_key.b64_std
    master_token           = random_uuid.consul_master_token.result
    agent_vault_token      = random_uuid.consul_agent_vault_token.result
    agent_server_token     = random_uuid.consul_agent_server_token.result
    vault_app_token        = random_uuid.consul_vault_app_token.result
    snapshot_token         = random_uuid.consul_snapshot_token.result
    consul_cluster_version = var.consul_cluster_version
    asg_name               = "${var.name_prefix}-consul-${var.consul_cluster_version}"
    redundancy_zones       = var.redundancy_zones
    bootstrap              = var.bootstrap
  }
}

data "template_file" "install_hashitools_vault" {
  template = file("${path.module}/scripts/install_hashitools_vault.sh.tpl")

  vars = {
    hashi_tools_rpm   = var.hashi_tools_rpm
    auto_join_tag     = var.auto_join_tag
    datacenter        = data.aws_region.current.name
    gossip_key        = random_id.consul_gossip_encryption_key.b64_std
    kms_key_id        = aws_kms_key.vault.key_id
    agent_vault_token = random_uuid.consul_agent_vault_token.result
    vault_app_token   = random_uuid.consul_vault_app_token.result
    snapshot_token    = random_uuid.consul_snapshot_token.result
    name_prefix       = var.name_prefix
    bootstrap         = var.bootstrap
  }
}

resource "aws_elb" "vault" {
  name                        = "${var.name_prefix}-vault-elb"
  connection_draining         = true
  connection_draining_timeout = 400
  internal                    = var.elb_internal
  subnets                     = split(",", var.subnets)
  security_groups             = toset([aws_security_group.vault_elb.id])

  listener {
    instance_port     = 8200
    instance_protocol = "tcp"
    lb_port           = 8200
    lb_protocol       = "tcp"
  }

  health_check {
    healthy_threshold   = 2
    unhealthy_threshold = 3
    timeout             = 5
    target              = var.bootstrap ? var.vault_elb_health_check : var.vault_elb_health_check_active
    interval            = 15
  }
}


resource "aws_autoscaling_group" "vault" {
  name                      = aws_launch_configuration.vault.name
  launch_configuration      = aws_launch_configuration.vault.name
  availability_zones        = split(",", var.availability_zones)
  min_size                  = var.vault_nodes
  max_size                  = var.vault_nodes
  desired_capacity          = var.vault_nodes
  min_elb_capacity          = 3
  wait_for_elb_capacity     = 3
  wait_for_capacity_timeout = "600s"
  health_check_grace_period = 300
  health_check_type         = var.bootstrap ? "EC2" : "ELB"
  vpc_zone_identifier       = split(",", var.subnets)
  load_balancers            = [aws_elb.vault.id]

  tags = [
    {
      key                 = "Name"
      value               = "${var.name_prefix}-vault"
      propagate_at_launch = true
    },
    {
      key                 = "Cluster-Version"
      value               = var.vault_cluster_version
      propagate_at_launch = true
    },
    {
      key                 = "owner"
      value               = var.owner
      propagate_at_launch = true
    },
    {
      key                 = "ttl"
      value               = var.ttl
      propagate_at_launch = true
    },
  ]

  lifecycle {
    create_before_destroy = true
  }
  depends_on = [aws_autoscaling_group.consul]
}

resource "aws_launch_configuration" "vault" {
  name                        = "${var.name_prefix}-vault-${var.vault_cluster_version}"
  image_id                    = var.ami
  instance_type               = var.instance_type
  key_name                    = var.key_name
  security_groups             = [aws_security_group.vault.id]
  user_data                   = data.template_file.install_hashitools_vault.rendered
  associate_public_ip_address = var.public_ip
  iam_instance_profile        = aws_iam_instance_profile.instance_profile.name
  root_block_device {
    volume_type = "io1"
    volume_size = 50
    iops        = "2500"
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_autoscaling_group" "consul" {
  name                      = aws_launch_configuration.consul.name
  launch_configuration      = aws_launch_configuration.consul.name
  availability_zones        = split(",", var.availability_zones)
  min_size                  = var.consul_nodes
  max_size                  = var.consul_nodes
  desired_capacity          = var.consul_nodes
  wait_for_capacity_timeout = "600s"
  health_check_grace_period = 15
  health_check_type         = "EC2"
  vpc_zone_identifier       = split(",", var.subnets)
  initial_lifecycle_hook {
    name                 = "consul_health"
    default_result       = "ABANDON"
    heartbeat_timeout    = 500
    lifecycle_transition = "autoscaling:EC2_INSTANCE_LAUNCHING"
  }

  tags = [
    {
      key                 = "Name"
      value               = "${var.name_prefix}-consul"
      propagate_at_launch = true
    },
    {
      key                 = "Cluster-Version"
      value               = var.consul_cluster_version
      propagate_at_launch = true
    },
    {
      key                 = "Environment-Name"
      value               = var.auto_join_tag
      propagate_at_launch = true
    },
    {
      key                 = "owner"
      value               = var.owner
      propagate_at_launch = true
    },
    {
      key                 = "ttl"
      value               = var.ttl
      propagate_at_launch = true
    },
  ]

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_launch_configuration" "consul" {
  name                        = "${var.name_prefix}-consul-${var.consul_cluster_version}"
  image_id                    = var.ami
  instance_type               = var.instance_type
  key_name                    = var.key_name
  security_groups             = [aws_security_group.vault.id]
  user_data                   = data.template_file.install_hashitools_consul.rendered
  associate_public_ip_address = var.public_ip
  iam_instance_profile        = aws_iam_instance_profile.instance_profile.name
  root_block_device {
    volume_type = "io1"
    volume_size = 100
    iops        = "5000"
  }

  lifecycle {
    create_before_destroy = true
  }
}