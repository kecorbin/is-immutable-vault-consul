resource "random_uuid" "consul_master_token" {}
resource "random_uuid" "consul_agent_vault_token" {}
resource "random_uuid" "consul_agent_server_token" {}
resource "random_uuid" "consul_vault_app_token" {}
resource "random_uuid" "consul_snapshot_token" {}