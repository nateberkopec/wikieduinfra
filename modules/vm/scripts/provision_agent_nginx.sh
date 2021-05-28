#!/usr/bin/env bash

sudo mkdir --parents /etc/letsencrypt

sudo echo "client {
  enabled = true

  host_volume \"nginx-etc-letsencrypt\" {
    path      = \"/etc/letsencrypt\"
    read_only = false
  }

  meta = {
    \"nginx_node\" = \"true\"
    \"reserved_node\" = \"true\"
  }
}

datacenter = \"dc1\"
data_dir = \"/opt/nomad\"
name = \"node-$1\"

acl {
  enabled = true
}

bind_addr = \"{{ GetInterfaceIP \\\"eth0\\\" }}\"

consul {
  checks_use_advertise = true
  token = \"$2\"

  ca_file = \"/etc/clusterconfig/consul-agent-certs/consul-agent-ca.pem\"
  cert_file = \"/etc/clusterconfig/consul-agent-certs/dc1-client-consul-0.pem\"
  key_file = \"/etc/clusterconfig/consul-agent-certs/dc1-client-consul-0-key.pem\"
}

tls {
  http = true
  rpc  = true

  ca_file = \"/etc/clusterconfig/nomad-agent-certs/nomad-agent-ca.pem\"
  cert_file = \"/etc/clusterconfig/nomad-agent-certs/global-client-nomad-0.pem\"
  key_file = \"/etc/clusterconfig/nomad-agent-certs/global-client-nomad-0-key.pem\"

  verify_server_hostname = true
  verify_https_client    = true
}
" | sudo tee /etc/nomad.d/client.hcl

sudo systemctl enable nomadclient
sudo systemctl start nomadclient

# Specific to bootstrapping the nginx node
# We need dummy certs and to DL the suggested SSL params
# otherwise nginx container will NOT start

domains=("$3" "$4")
rsa_key_size=4096
data_path="/etc/letsencrypt"
email="$5"

echo "### Downloading recommended TLS parameters ..."
curl -s https://raw.githubusercontent.com/certbot/certbot/master/certbot-nginx/certbot_nginx/_internal/tls_configs/options-ssl-nginx.conf | sudo tee "$data_path/options-ssl-nginx.conf"
curl -s https://raw.githubusercontent.com/certbot/certbot/master/certbot/certbot/ssl-dhparams.pem | sudo tee "$data_path/ssl-dhparams.pem"
echo

echo "### Creating dummy certificate for $domains ..."
for domain in "${domains[@]}"; do
  echo $domain
  domainpath="/etc/letsencrypt/dummy/$domain"
  sudo mkdir -p $domainpath
  sudo openssl req -x509 -nodes -newkey rsa:$rsa_key_size -days 1 -keyout "$domainpath/privkey.pem" -out "$domainpath/fullchain.pem" -subj "/CN=localhost"

  mainpath="/etc/letsencrypt/main/$domain"
  sudo mkdir -p /etc/letsencrypt/main
  sudo ln -s /etc/letsencrypt/dummy/$domain $mainpath
done

# ... now boot Nginx.
