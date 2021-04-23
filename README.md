# Wikiedu's Hashistack Setup

This repository contains the Terraform configuration for Wikiedu.

This configuration:

* **Creates a datacenter on Linode**, connected by Consul.
* **Creates a Nomad cluster**.
* **Spins up the necessary resources (redis, mariadb, memcached) for powering the [WikiEdu Rails app](https://github.com/WikiEducationFoundation/WikiEduDashboard)**.

## Steps to Spin Up a New Datacenter

1. Create a `secrets.tfvars` file in the `linode` and `nomadservers` directories. See `secrets.tfvars.example` and `variables.tf` for more information.
2. Ensure all binaries (below) are on your `PATH`
3. `terragrunt run-all init`
4. `terragrunt run-all apply`
   1. At this point, you can reach the Nomad UI by via `https://{nomad_server_ip_address}:4646`. The required ACL token Secret ID is on the Nomad server in `/root/bootstrap.token`. Log in via SSH to get it.
5. Configure DNS
   1. Create an A record to point the rails domain to the nginx node's IP address
   2. Create an A record to point the docker domain to the nginx node's IP address as well
6. Run the provided ssl provision script (in `nomadserver` ) on the nginx node.
7. `waypoint init && waypoint up` from the WikiEd project directory.

## Binaries required

1. Waypoint (0.3) - https://www.waypointproject.io/
2. Terraform (0.15) - https://www.terraform.io/
3. Terragrunt (0.28.24) - https://terragrunt.gruntwork.io/
4. Consul - https://www.consul.io/ 
5. `ssh-keyscan` and `scp` and `htpasswd` (provided by apache2-utils on Debian)

## Interacting with Terraform resources
When Terraform spins up virtual machines, it installs your SSH keys. You can SSH directly into root@IP_ADDRESS for any of the virtual machines. The most important ones — nginx and Nomad — are shown in the outputs of `terragrunt run-all apply`. (This command is idempotent, so you can run it with no changes in the project to see the current IPs.)


### Using Waypoint Exec

You may connect to any container running the rails app with `waypoint exec`.

However, once inside the container, you must prefix all commands with `/cnb/lifecycle/launcher` in order to set `$PATH` correctly and get all of your actually-installed Rubies/gems/etc, rather than using the system versions.

### Scaling Strategy

**Rails and Sidekiq workloads**: If you're running out Sidekiq capacity (queues getting backed up) or Rails capacity (HTTP queue latency reported is unacceptable, say 150milliseconds or more), you should add additional "no volume" nodes by [increasing the task group `count`](https://www.nomadproject.io/docs/job-specification/group) to provide more resources, then change the `rails` jobspec file in the WikiEdu repo or use the [nomad job scale](https://www.nomadproject.io/docs/commands/job/scale) command.
* **More NGINX capacity** If Nginx is running out of CPU, resize the node (in `linode/main.tf`). This will take about 5 minutes and will cause hard downtime. You will then need to increase the cpu/memory allocation in the Nomad jobfile for Nginx.
* **More Redis or Memcache capacity**. Update the appropriate variables that control CPU/memory allocation. If that means that you have no available space in the cluster topology, provision additional nodes in `linode/main.tf`.
* **More MariaDB capacity**. Resize the node. This will cause hard downtime of 5 minutes or more. You will need to update the cpu/memory allocation in the mariadb job spec. It is intended that the mariadb job takes all of the resources on its node.
