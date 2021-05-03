# Wikiedu's Hashistack Setup

This repository contains the Terraform configuration for Wikiedu.

This configuration:

* **Creates a datacenter on Linode**, connected by Consul.
* **Creates a Nomad cluster**.
* **Spins up the necessary resources (redis, mariadb, memcached) for powering the [WikiEdu Rails app](https://github.com/WikiEducationFoundation/WikiEduDashboard)**.

## Steps to Spin Up a New Datacenter

### Create and provision the servers

1. Create a `secrets.tfvars` file in the `linode` and `nomadservers` directories. See `secrets.tfvars.example` and `variables.tf` for more information.
2. Ensure all binaries (below) are on your `PATH`
3. `terragrunt run-all init`
4. `terragrunt run-all apply`
   1. At this point, you can reach the Nomad UI by via `https://{nomad_server_ip_address}:4646`. The required ACL token Secret ID is the `nomad_mgmt_token`, also available on the Nomad server in `/root/bootstrap.token`.
5. Configure DNS
   1. Create an A record to point the rails domain to the nginx node's IP address
   2. Create an A record to point the docker domain to the nginx node's IP address as well
6. Run the provided ssl provision script (in `nomadserver` ) on the nginx node.

### Prepare the Rails app

7. Clone a fresh copy of the WikiEduDashboard app in a new directory
8. Create `application.yml` and `database.yml` to match what will run in the cloud. (These will be included in the Docker image that gets deployed.)
9. Install the gems and node modules, then build the production assets:
   1.  `bundle install`
   2.  `yarn install`
   3.  `yarn build`
10. Log in to docker
   4. `docker login <DOCKER_DOMAIN>`. User: 'docker', password: same the input to `htpasswd` when generating {docker_pass_encrypted}
11. Add nomad variables to your ENV
   5. `source nomadserver/nomad.sh` or similar, in the same shell used for the WikiEduDashboard waypoint commands below.
12. Run `waypoint init` to generate the job templates.
13. Build and deploy
    1.  `waypoint up` generates a Docker image, pushes it to the registry, and deploys it to all the web and sidekiq jobs
    2.  `waypoint build` just generates a Docker image and pushes it to the registry at the docker domain
    3.  `waypoint deploy` just deploys the latest image as a set of jobs for web and sidekiq

### Transfer data

14. Copy the database (unless starting from scratch)
    1.  Use SCP to transfer a gzipped copy of the database to the mariadb node (after adding an SSH pubkey from the source machine to the authorized_keys file on the node.)
    2.  Copy the database file into the mariadb container using `docker copy`
    3.  Log in to the docker container (eg `docker exec -it 0323b53c064e /bin/bash`
    4.  Unzip and import the database (eg `gunzip daily_dashboard_2021-04-26_01h16m_Monday.sql.gz`; `mysql -u wiki -p dashboard < daily_dashboard_2021-04-26_01h16m_Monday.sql`)
15. Copy the `/public/system` directory to the railsweb node.
    1.  This lives at `/var/www/dashboard/shared/public/system` for the Capistrano-deployed production server.
    2.  Get it to the node: `scp -r system/ 45.33.51.69:/root/database_transfer/`
    3.  Change the permissions so that the docker user can write to it: `chmod -R 777 system`
    4.  Get it into docker: `docker cp system 13a78c00206f:/workspace/public/`

## Binaries required

1. Waypoint (0.3) - https://www.waypointproject.io/
2. Terraform (0.15) - https://www.terraform.io/
3. Terragrunt (0.28.24) - https://terragrunt.gruntwork.io/
4. Consul - https://www.consul.io/ 
5. Nomad - https://www.nomadproject.io/
6. `ssh-keyscan`, `jq`, `scp` and `htpasswd` (provided by apache2-utils on Debian)

## Interacting with Terraform resources
When Terraform spins up virtual machines, it installs your SSH keys. You can SSH directly into root@IP_ADDRESS for any of the virtual machines. The most important ones — nginx and Nomad — are shown in the outputs of `terragrunt run-all apply`. (This command is idempotent, so you can run it with no changes in the project to see the current IPs.)

### Managing resources from multiple devices
To set up a new device to manage an existing (production) cluster of resources:

1. Clone the repository
2. Add the same SSH keys used to access the cluster (as specified in `linode/secrets.tfvars`)
   1. `chmod 600` the private key after copying it, or it may not work.
   2. With just the ssh key, you should be able to `ssh root@<rails domain>`, etc.
3. Copy all required state into the project directory
   1. Both `secrets.tfvars` files
   2. All 5 `terraform.tfstate` files
   3. The entire `certs` directory
   4. `nomadserver/nomad.sh` (modify the paths to the certs if necessary)
4. Run `terragrunt run-all apply`. If this works, everything is in order.

Note that running `terragrunt run-all apply` will only apply changes it detects based on files in the project directory, so if changes have been deployed that don't match the local project (for example, changes on another computer that weren't checked into git or are from a newer revision missing from the local repo) then no running services will be changed. To reset a service (eg, the nginx gateway), you can make a nonfunctional change (ie, add a comment) to the corresponding `.hcl.tmpl` file.

### Using Waypoint Exec

You may connect to any container running the rails app with `waypoint exec` (eg, `waypoint exec bash`).

However, once inside the container, you must prefix all commands with `/cnb/lifecycle/launcher` in order to set `$PATH` correctly and get all of your actually-installed Rubies/gems/etc, rather than using the system versions.

Useful commands:
* Get a production Rails console: `/cnb/lifecycle/launcher rails console`
### Scaling Strategy

**Rails and Sidekiq workloads**: If you're running out Sidekiq capacity (queues getting backed up) or Rails capacity (HTTP queue latency reported is unacceptable, say 150milliseconds or more), you should add additional "no volume" nodes by [increasing the task group `count`](https://www.nomadproject.io/docs/job-specification/group) to provide more resources, then change the `rails` jobspec file in the WikiEdu repo or use the [nomad job scale](https://www.nomadproject.io/docs/commands/job/scale) command.
* **More NGINX capacity** If Nginx is running out of CPU, resize the node (in `linode/main.tf`). This will take about 5 minutes and will cause hard downtime. You will then need to increase the cpu/memory allocation in the Nomad jobfile for Nginx.
* **More Redis or Memcache capacity**. Update the appropriate variables that control CPU/memory allocation. If that means that you have no available space in the cluster topology, provision additional nodes in `linode/main.tf`.
* **More MariaDB capacity**. Resize the node. This will cause hard downtime of 5 minutes or more. You will need to update the cpu/memory allocation in the mariadb job spec. It is intended that the mariadb job takes all of the resources on its node.
