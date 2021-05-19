# Run this on the nginx node, not inside the docker container for nginx
# Change below line to your desired domains
domains=("dashboard.wikiedu.org" "docker.wikiedu.org")
rsa_key_size=4096
data_path="/etc/letsencrypt"
email="sage@wikiedu.org" # Adding a valid address is strongly recommended

# To get or renew a LE cert:

for domain in "${domains[@]}"; do
  echo $domain
  domainpath="$data_path/var/$domain/certbot"
  mkdir -p $domainpath

  docker run -it -v "$data_path:$data_path" --rm --entrypoint "" certbot/certbot sh -c "certbot certonly --webroot -w $data_path/var/$domain/certbot -d $domain --email $email --rsa-key-size $rsa_key_size --non-interactive --agree-tos --force-renewal"
  if [ -f $data_path/live/$domain/fullchain.pem ]; then
    ln -sfn $data_path/live/$domain $data_path/main/$domain
  fi
done
