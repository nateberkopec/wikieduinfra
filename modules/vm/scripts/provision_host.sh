#!/usr/bin/env bash

sudo apt-get update -qq

sudo apt-get install -yq --no-install-recommends \
  apt-transport-https \
  ca-certificates \
  curl \
  gnupg \
  lsb-release \
  jq

# Install Nomad, systemctl services, Consul

sudo apt-get install -yq --no-install-recommends software-properties-common

curl -fsSL https://apt.releases.hashicorp.com/gpg | sudo apt-key add -
sudo apt-add-repository "deb [arch=amd64] https://apt.releases.hashicorp.com $(lsb_release -cs) main"
sudo apt-get update -qq

# Consul

sudo apt-get install -yq --no-install-recommends consul

sudo mkdir -p /etc/clusterconfig
sudo chown -R $USER /etc/clusterconfig
cd /etc/clusterconfig
consul tls ca create
consul tls cert create -server
consul tls cert create -client
mkdir consul-agent-certs
cp consul-agent-ca.pem ./consul-agent-certs
cp dc1-client-consul* ./consul-agent-certs

sudo touch /etc/systemd/system/consulserver.service
sudo touch /etc/consul.d/envfile
sudo echo "[Unit]
Description=Consul Server
Documentation=https://www.consul.io/docs
Wants=network-online.target
After=network-online.target

[Service]
ExecReload=/bin/kill -HUP \$MAINPID
ExecStart=consul agent -config-file /etc/consul.d/server.hcl
KillMode=process
KillSignal=SIGINT
LimitNOFILE=infinity
LimitNPROC=infinity
Restart=on-failure
RestartSec=2
StartLimitBurst=3
StartLimitIntervalSec=10
TasksMax=infinity
EnvironmentFile=/etc/consul.d/envfile

[Install]
WantedBy=multi-user.target" | sudo tee /etc/systemd/system/consulserver.service

sudo mkdir --parents /etc/consul.d
sudo chmod 700 /etc/consul.d
sudo touch /etc/consul.d/server.hcl

sudo echo "
bind_addr = \"{{ GetInterfaceIP \\\"eth0\\\" }}\"
client_addr = \"{{ GetInterfaceIP \\\"eth0\\\" }} 127.0.0.1\"
bootstrap_expect = 1
server = true
encrypt = \"$2\"
ui_config = { enabled = true }
data_dir= \"/tmp/consul\"
node_name = \"server1\"
ports {
  grpc = 8502
  https = 8501
  http = -1
}
connect {
  enabled = true
}
acl = {
  enabled = true
  default_policy = \"deny\"
  enable_token_persistence = true

  tokens {
    master = \"$1\"
  }
}

verify_incoming_rpc = true
verify_incoming_https = false
verify_outgoing = true
verify_server_hostname = true
ca_file = \"/etc/clusterconfig/consul-agent-certs/consul-agent-ca.pem\"
cert_file = \"/etc/clusterconfig/dc1-server-consul-0.pem\"
key_file = \"/etc/clusterconfig/dc1-server-consul-0-key.pem\"
auto_encrypt {
  allow_tls = true
}
" | sudo tee /etc/consul.d/server.hcl

sudo systemctl enable consulserver
sudo systemctl start consulserver

# Nomad
sudo apt-get install -yq --no-install-recommends nomad

sudo touch /etc/systemd/system/nomadserver.service
sudo echo "[Unit]
Description=Nomad
Documentation=https://www.nomadproject.io/docs
Wants=network-online.target
After=network-online.target

[Service]
ExecReload=/bin/kill -HUP \$MAINPID
ExecStart=nomad agent -config /etc/nomad.d/server.hcl
KillMode=process
KillSignal=SIGINT
LimitNOFILE=infinity
LimitNPROC=infinity
Restart=on-failure
RestartSec=2
StartLimitBurst=3
StartLimitIntervalSec=10
TasksMax=infinity

[Install]
WantedBy=multi-user.target" | sudo tee /etc/systemd/system/nomadserver.service

IP_ADDR=$(hostname --all-ip-addresses | awk '{print $1}')
consul tls ca create -domain=nomad -name-constraint
consul tls cert create -server -domain nomad -additional-ipaddress=$IP_ADDR -additional-ipaddress=$4 -dc=global
consul tls cert create -client -domain nomad -additional-ipaddress=$IP_ADDR -additional-ipaddress=$4 -dc=global
mkdir nomad-agent-certs
cp nomad-agent-ca.pem ./nomad-agent-certs
mv global-client* ./nomad-agent-certs

sudo mkdir --parents /etc/nomad.d
sudo chmod 700 /etc/nomad.d

sudo touch /etc/nomad.d/server.hcl
sudo echo "server {
  enabled = true
  bootstrap_expect = 1
  encrypt = \"$2\"
}

datacenter = \"dc1\"
data_dir = \"/opt/nomad\"

acl {
  enabled = true
}

bind_addr = \"{{ GetInterfaceIP \\\"eth0\\\" }}\"

consul {
  checks_use_advertise = true
  address = \"127.0.0.1:8501\"
  ssl = true
  token = \"$1\"

  ca_file = \"/etc/clusterconfig/consul-agent-certs/consul-agent-ca.pem\"
  cert_file = \"/etc/clusterconfig/consul-agent-certs/dc1-client-consul-0.pem\"
  key_file = \"/etc/clusterconfig/consul-agent-certs/dc1-client-consul-0-key.pem\"
}

tls {
  http = true
  rpc = true

  ca_file = \"/etc/clusterconfig/nomad-agent-ca.pem\"
  cert_file = \"/etc/clusterconfig/global-server-nomad-0.pem\"
  key_file = \"/etc/clusterconfig/global-server-nomad-0-key.pem\"

  verify_server_hostname = true
  verify_https_client = false
}
" | sudo tee /etc/nomad.d/server.hcl

sudo systemctl enable nomadserver
sudo systemctl start nomadserver
sleep 5
nomad acl bootstrap -address=https://$IP_ADDR:4646 -ca-cert=nomad-agent-ca.pem 2>&1 | tee bootstrap.token

# NR Agent

# Add the New Relic Infrastructure Agent gpg key \
curl -s https://download.newrelic.com/infrastructure_agent/gpg/newrelic-infra.gpg | sudo apt-key add - && \
\
# Create a configuration file and add your license key \
echo "license_key: $3\n display_name: linode-server" | sudo tee -a /etc/newrelic-infra.yml && \
\
# Create the agent’s apt repository \
printf "deb [arch=amd64] https://download.newrelic.com/infrastructure_agent/linux/apt buster main" | sudo tee -a /etc/apt/sources.list.d/newrelic-infra.list && \
\
# Update your apt cache \
sudo apt-get update && \
\
# Run the installation script \
sudo apt-get install newrelic-infra -y