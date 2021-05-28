#!/usr/bin/env bash
sudo apt-get update -qq

sudo apt-get install -yq --no-install-recommends \
  apt-transport-https \
  ca-certificates \
  curl \
  gnupg \
  lsb-release \
  jq \
  software-properties-common

# AGENT ONLY - Docker

curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor | sudo tee /usr/share/keyrings/docker-archive-keyring.gpg

echo \
  "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/debian \
  $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

sudo apt-get update -qq
sudo apt-get install -yq --no-install-recommends docker-ce docker-ce-cli containerd.io
sudo groupadd docker
sudo usermod -aG docker $USER
docker run hello-world

# AGENT ONLY - CNI plugins

curl -L -o cni-plugins.tgz "https://github.com/containernetworking/plugins/releases/download/v0.9.0/cni-plugins-linux-$( [ $(uname -m) = aarch64 ] && echo arm64 || echo amd64)"-v0.9.0.tgz
sudo mkdir -p /opt/cni/bin
sudo tar -C /opt/cni/bin -xzf cni-plugins.tgz

sudo echo 1 > /proc/sys/net/bridge/bridge-nf-call-arptables
sudo echo 1 > /proc/sys/net/bridge/bridge-nf-call-ip6tables
sudo echo 1 > /proc/sys/net/bridge/bridge-nf-call-iptables

sudo echo "net.bridge.bridge-nf-call-arptables = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1" | sudo tee /etc/sysctl.d/cni

# Consul

curl -fsSL https://apt.releases.hashicorp.com/gpg | sudo apt-key add -
sudo apt-add-repository "deb [arch=amd64] https://apt.releases.hashicorp.com $(lsb_release -cs) main"
sudo apt-get update && sudo apt-get install -yq --no-install-recommends consul

sudo touch /etc/systemd/system/consulclient.service
sudo echo "[Unit]
Description=Consul Client
Documentation=https://www.consul.io/docs
Wants=network-online.target
After=network-online.target

[Service]
ExecReload=/bin/kill -HUP \$MAINPID
ExecStart=consul agent -config-file /etc/consul.d/client.hcl
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
WantedBy=multi-user.target" | sudo tee /etc/systemd/system/consulclient.service

sudo mkdir --parents /etc/consul.d
sudo chmod 700 /etc/consul.d

sudo touch /etc/consul.d/client.hcl

sudo echo "
bind_addr = \"{{ GetInterfaceIP \\\"eth0\\\" }}\"
data_dir= \"/tmp/consul\"
node_name = \"node-$1\"
ports {
  grpc = 8502
}
connect {
  enabled = true
}
encrypt = \"$3\"
acl = {
  enabled = true
  default_policy = \"deny\"
  enable_token_persistence = true

  tokens = {
    default = \"$2\"
  }
}

verify_incoming = false,
verify_outgoing = true,
verify_server_hostname = true,
ca_file = \"/etc/clusterconfig/consul-agent-certs/consul-agent-ca.pem\",
auto_encrypt = {
  tls = true
}

retry_join = [\"$4\"]
" | sudo tee /etc/consul.d/client.hcl

sudo systemctl enable consulclient
sudo systemctl start consulclient

# Nomad Agent

sudo apt-get install -yq --no-install-recommends nomad

sudo touch /etc/systemd/system/nomadclient.service
sudo echo "[Unit]
Description=Nomad Client
Documentation=https://www.nomadproject.io/docs
Wants=network-online.target
After=network-online.target

[Service]
ExecReload=/bin/kill -HUP \$MAINPID
ExecStart=nomad agent -config /etc/nomad.d/client.hcl
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
WantedBy=multi-user.target" | sudo tee /etc/systemd/system/nomadclient.service

sudo mkdir --parents /etc/nomad.d
sudo chmod 700 /etc/nomad.d
sudo touch /etc/nomad.d/client.hcl

# Config must be installed by another script.

# NR Agent

# Add the New Relic Infrastructure Agent gpg key \
curl -s https://download.newrelic.com/infrastructure_agent/gpg/newrelic-infra.gpg | sudo apt-key add - && \
\
# Create a configuration file and add your license key \
echo "license_key: $5\n display_name: linode-node-$1" | sudo tee -a /etc/newrelic-infra.yml && \
\
# Create the agent’s apt repository \
printf "deb [arch=amd64] https://download.newrelic.com/infrastructure_agent/linux/apt buster main" | sudo tee -a /etc/apt/sources.list.d/newrelic-infra.list && \
\
# Update your apt cache \
sudo apt-get update && \
\
# Run the installation script \
sudo apt-get install newrelic-infra -y