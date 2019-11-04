#!/usr/bin/env bash

export INSTANCE_ID=`curl -s http://169.254.169.254/latest/meta-data/instance-id`
export availability_zone="$(curl -s http://169.254.169.254/latest/meta-data/placement/availability-zone)"
export local_ipv4="$(curl -s http://169.254.169.254/latest/meta-data/local-ipv4)"

# Download binaries into some temporary directory
curl -L "${hashi_tools_rpm}" > /tmp/hashitools.rpm

rpm -ivh /tmp/hashitools.rpm
yum install epel-release -y && yum install jq -y && yum install python-pip -y
pip install awscli --upgrade

cat << EOF > /etc/consul.d/consul.hcl
datacenter          = "${datacenter}"
server              = true
leave_on_terminate  = true
bootstrap_expect    = ${bootstrap_expect}
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

performance {
    raft_multiplier = 1
}

acl {
  enabled        = true
  %{ if bootstrap }default_policy = "allow"%{ else }default_policy = "deny"%{ endif }

  tokens {
    master = "${master_token}"%{ if !bootstrap }
    agent  = "${agent_server_token}"%{ endif }
  }
}

encrypt = "${gossip_key}"
EOF

cat << EOF > /etc/consul.d/autopilot.hcl
autopilot {%{ if redundancy_zones }
  redundancy_zone_tag = "az"%{ endif }
  upgrade_version_tag = "consul_cluster_version"
}
EOF
 %{ if redundancy_zones }
cat << EOF > /etc/consul.d/redundancy_zone.hcl
node_meta = {
    az = "$${availability_zone}"
}
EOF
%{ endif }

cat << EOF > /etc/consul.d/cluster_version.hcl
node_meta = {
    consul_cluster_version = "${consul_cluster_version}"
}
EOF
%{ if bootstrap }
cat << EOF > /home/centos/bootstrap_tokens.sh
#!/bin/bash
export CONSUL_HTTP_TOKEN=${master_token}

echo '
node_prefix "" {
  policy = "write"
}
service_prefix "" {
  policy = "read"
}
agent_prefix "" {
  policy = "write"
}' | consul acl policy create -name consul-agent-vault

echo '
node_prefix "" {
  policy = "write"
}
service_prefix "" {
  policy = "read"
}
service "consul" {
  policy = "write"
}
agent_prefix "" {
  policy = "write"
}' | consul acl policy create -name consul-agent-server

echo '
key_prefix "vault/" {
  policy = "write"
}
service "vault" {
  policy = "write"
}
session_prefix "" {
  policy = "write"
}
node_prefix "" {
  policy = "write"
}
agent_prefix "" {
  policy = "write"
}' | consul acl policy create -name vault

echo '
acl = "write"
key "consul-snapshot/lock" {
 policy = "write"
}
session_prefix "" {
 policy = "write"
}
service "consul-snapshot" {
 policy = "write"
}' | consul acl policy create -name snapshot_agent

consul acl token create -description "consul agent vault token" -policy-name consul-agent-vault -secret "${agent_vault_token}"
consul acl token create -description "consul agent server token" -policy-name consul-agent-vault -secret "${agent_server_token}"
consul acl token create -description "vault application token" -policy-name vault -secret "${vault_app_token}"
consul acl token create -description "consul snapshot agent" -policy-name snapshot_agent -secret "${snapshot_token}"
EOF

chmod +x /home/centos/bootstrap_tokens.sh
%{ endif }
%{ if consul_cluster_version == "0.0.2"}
cat << EOF > /home/centos/anonymous_token.sh
#!/bin/bash
export CONSUL_HTTP_TOKEN=${master_token}
echo '
node_prefix "" {
  policy = "read"
}
service_prefix "" {
  policy = "read"
}
session_prefix "" {
  policy = "read"
}
agent_prefix "" {
  policy = "read"
}
query_prefix "" {
  policy = "read"
}
operator_prefix "" {
  policy = "read"
}' |  consul acl policy create -name anonymous
consul acl token update -id anonymous -policy-name anonymous
EOF

chmod +x /home/centos/anonymous_token.sh
%{ endif }
chown -R consul:consul /etc/consul.d
chmod -R 640 /etc/consul.d/*

systemctl daemon-reload
systemctl enable consul
systemctl start consul

while true; do
    curl -s http://127.0.0.1:8500/v1/catalog/service/consul | jq -e . && break
    sleep 1
done

until [[ $TOTAL -ge ${total_nodes} ]]; do
    TOTAL=`curl -s http://127.0.0.1:8500/v1/catalog/service/consul | jq -er 'map(select(.NodeMeta.consul_cluster_version == "${consul_cluster_version}")) | length'`
    sleep 5
    echo "Current New Node Count: $TOTAL"
done

until [[ $LEADER -eq 1 ]]; do
    LEADER=0
    export NEW_NODE_IDS=`curl -s http://127.0.0.1:8500/v1/catalog/service/consul | jq -r 'map(select(.NodeMeta.consul_cluster_version == "${consul_cluster_version}")) | .[].ID'`
    until [[ $VOTERS -eq ${bootstrap_expect} ]]; do
        VOTERS=0
        for ID in $NEW_NODE_IDS; do
            echo "Checking $ID"
            curl -s http://127.0.0.1:8500/v1/operator/autopilot/health | jq -e ".Servers[] | select(.ID == \"$ID\" and .Voter == true)" && let "VOTERS+=1" && echo "Current Voters: $VOTERS"
            sleep 2
        done
    done
    curl -s http://127.0.0.1:8500/v1/operator/autopilot/health | jq -e ".Servers[] | select(.Voter == true) | .ID" && let "LEADER+=1" && echo "Leader Found"
    sleep 2
done

echo "$INSTANCE_ID determined all nodes to be healthy and ready to go <3"
echo "Waiting 10 seconds for leadership to catch up on consul clients....."
sleep 10

while true; do
    aws autoscaling complete-lifecycle-action --lifecycle-action-result CONTINUE --instance-id $INSTANCE_ID --lifecycle-hook-name consul_health --auto-scaling-group-name "${asg_name}" --region ${datacenter} && break
    sleep 1
done