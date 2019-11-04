output "vault_address" {
  value = "http://${aws_elb.vault.dns_name}:8200"
}

// Can be used to add additional SG rules to Vault instances.
output "vault_security_group" {
  value = aws_security_group.vault.id
}

// Can be used to add additional SG rules to the Vault ELB.
output "vault_elb_security_group" {
  value = aws_security_group.vault_elb.id
}

