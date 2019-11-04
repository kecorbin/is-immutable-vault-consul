#!/usr/bin/env bash

export availability_zone="$(curl -s http://169.254.169.254/latest/meta-data/placement/availability-zone)"
export instance_id="$(curl -s http://169.254.169.254/latest/meta-data/instance-id)"
export local_ipv4="$(curl -s http://169.254.169.254/latest/meta-data/local-ipv4)"

# Download binaries into some temporary directory
curl -L "${hashi_tools_rpm}" > /tmp/hashitools.rpm

rpm -ivh /tmp/hashitools.rpm
yum install epel-release -y && yum install jq -y && yum install python-pip -y
pip install awscli --upgrade

cat << EOF > /etc/consul.d/consul.hcl
datacenter          = "${datacenter}"
data_dir            = "/opt/consul/data"
advertise_addr      = "$${local_ipv4}"
client_addr         = "127.0.0.1"
log_level           = "INFO"
ui                  = true

# AWS cloud join
retry_join          = ["provider=aws tag_key=Environment-Name tag_value=${auto_join_tag}"]

connect {
  enabled = true
}

acl {
  enabled        = true
  %{ if !bootstrap }default_policy = "deny"
  tokens {
    agent  = "${agent_vault_token}"
  }
  %{ else }default_policy = "allow"%{ endif }
}

encrypt = "${gossip_key}"
EOF

%{ if !bootstrap }
mkdir /etc/consul-snapshot.d/
cat << EOF > /etc/systemd/system/consul-snapshot.service
[Unit]
Description="HashiCorp Consul Snapshot Agent"
Documentation=https://www.consul.io/
Requires=network-online.target
After=consul.service
ConditionFileNotEmpty=/etc/consul-snapshot.d/consul-snapshot.json

[Service]
User=consul
Group=consul
ExecStart=/usr/local/bin/consul snapshot agent -config-dir=/etc/consul-snapshot.d/
KillMode=process
Restart=on-failure
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
EOF

cat << EOF > /etc/consul-snapshot.d/consul-snapshot.json
{
	"snapshot_agent": {
		"http_addr": "127.0.0.1:8500",
		"token": "${snapshot_token}",
		"datacenter": "${datacenter}",
		"snapshot": {
			"interval": "30m",
			"retain": 336,
			"deregister_after": "8h"
		},
		"aws_storage": {
			"s3_region": "${datacenter}",
			"s3_bucket": "${name_prefix}-consul-data"
		}
	}
}
EOF
chown -R consul:consul /etc/consul-snapshot.d
chmod -R 640 /etc/consul-snapshot.d/*%{ endif }
chown -R consul:consul /etc/consul.d

chmod -R 640 /etc/consul.d/*

systemctl daemon-reload
systemctl enable consul
systemctl start consul

while true; do
    curl http://127.0.0.1:8500/v1/catalog/service/consul && break
    sleep 5
done
%{ if !bootstrap }
systemctl enable consul-snapshot
systemctl start consul-snapshot%{ endif }

cat << EOF > /etc/vault.d/vault.hcl
disable_performance_standby = true
ui = true
storage "consul" {
  address = "127.0.0.1:8500"
  path    = "vault"
  %{ if !bootstrap }token   = "${vault_app_token}"%{ endif }
}
listener "tcp" {
  address     = "0.0.0.0:8200"
  tls_disable = 1
}
seal "awskms" {
  region     = "${datacenter}"
  kms_key_id = "${kms_key_id}"
}
EOF

systemctl enable vault
systemctl start vault