resource "aws_security_group" "vault" {
  name        = "${var.name_prefix}-vault-sg"
  description = "Vault servers"
  vpc_id      = var.vpc_id
}

resource "aws_security_group_rule" "vault_ssh" {
  security_group_id = aws_security_group.vault.id
  type              = "ingress"
  from_port         = 22
  to_port           = 22
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
}

resource "aws_security_group_rule" "vault_external_egress_https" {
  security_group_id = aws_security_group.vault.id
  type              = "egress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
}

resource "aws_security_group_rule" "vault_external_egress_http" {
  security_group_id = aws_security_group.vault.id
  type              = "egress"
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
}

resource "aws_security_group_rule" "vault_internal_egress_tcp" {
  security_group_id        = aws_security_group.vault.id
  type                     = "egress"
  from_port                = 8200
  to_port                  = 8600
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.vault.id
}

resource "aws_security_group_rule" "vault_internal_egress_udp" {
  security_group_id        = aws_security_group.vault.id
  type                     = "egress"
  from_port                = 8200
  to_port                  = 8600
  protocol                 = "udp"
  source_security_group_id = aws_security_group.vault.id
}

resource "aws_security_group_rule" "vault_elb_access" {
  security_group_id        = aws_security_group.vault.id
  type                     = "ingress"
  from_port                = 8200
  to_port                  = 8200
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.vault_elb.id
}

resource "aws_security_group_rule" "vault_cluster" {
  security_group_id        = aws_security_group.vault.id
  type                     = "ingress"
  from_port                = 8201
  to_port                  = 8201
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.vault.id
}

// This rule allows Consul RPC.
resource "aws_security_group_rule" "consul_rpc" {
  security_group_id        = aws_security_group.vault.id
  type                     = "ingress"
  from_port                = 8300
  to_port                  = 8300
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.vault.id
}

// This rule allows Consul Serf TCP.
resource "aws_security_group_rule" "vault_consul_serf_tcp" {
  security_group_id        = aws_security_group.vault.id
  type                     = "ingress"
  from_port                = 8301
  to_port                  = 8302
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.vault.id
}

// This rule allows Consul Serf UDP.
resource "aws_security_group_rule" "vault_consul_serf_udp" {
  security_group_id        = aws_security_group.vault.id
  type                     = "ingress"
  from_port                = 8301
  to_port                  = 8302
  protocol                 = "udp"
  source_security_group_id = aws_security_group.vault.id
}

// This rule allows Consul API.
resource "aws_security_group_rule" "consul_api_tcp" {
  security_group_id        = aws_security_group.vault.id
  type                     = "ingress"
  from_port                = 8500
  to_port                  = 8500
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.vault.id
}

// This rule allows Consul DNS.
resource "aws_security_group_rule" "consul_dns_tcp" {
  security_group_id        = aws_security_group.vault.id
  type                     = "ingress"
  from_port                = 8600
  to_port                  = 8600
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.vault.id
}

// This rule allows Consul DNS.
resource "aws_security_group_rule" "consul_dns_udp" {
  security_group_id        = aws_security_group.vault.id
  type                     = "ingress"
  from_port                = 8600
  to_port                  = 8600
  protocol                 = "udp"
  source_security_group_id = aws_security_group.vault.id
}

resource "aws_security_group" "vault_elb" {
  name        = "${var.name_prefix}-vault-elb"
  description = "Vault ELB"
  vpc_id      = var.vpc_id
}

resource "aws_security_group_rule" "vault_elb_http" {
  security_group_id = aws_security_group.vault_elb.id
  type              = "ingress"
  from_port         = 8200
  to_port           = 8200
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
}

resource "aws_security_group_rule" "vault_elb_egress_to_vault" {
  security_group_id        = aws_security_group.vault_elb.id
  type                     = "egress"
  from_port                = 8200
  to_port                  = 8200
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.vault.id
}

resource "aws_security_group_rule" "vault_elb_egress_to_consul" {
  security_group_id        = aws_security_group.vault_elb.id
  type                     = "egress"
  from_port                = 8500
  to_port                  = 8500
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.vault.id
}
