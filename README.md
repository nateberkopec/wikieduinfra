# Wikiedu's Hashistack Setup

This repository contains the Terraform configuration for Wikiedu.

This configuration:

* **Creates a datacenter on Linode**, connected by Consul.
* **Creates a Nomad cluster**.
* **Spins up the necessary resources (redis, mariadb, memcached) for powering the [WikiEdu Rails app](https://github.com/WikiEducationFoundation/WikiEduDashboard)**.

## Steps to Spin Up a New Datacenter

1. Create a `secrets.tfvars` file in the `linode` and `nomadservers` directories. See `secrets.tfvars.example` and `variables.tf` for more information.
1. Ensure all binaries (below) are on your `PATH`
1. `terragrunt run-all init`
1. `terragrunt run-all apply`
1. Point subdomains to the address of your new nginx node.
1. Run the provided ssl provision script (in `nomadserver` ) on the nginx node.
1. `waypoint init && waypoint up` from the WikiEd project directory.

## Binaries required

1. Waypoint (0.3)
2. Terraform (0.15)
3. Terragrunt (0.28.21)
4. `ssh-keyscan` and `scp`

### Using Waypoint Exec

You may connect to any container running the rails app with `waypoint exec`.

However, once inside the container, you must prefix all commands with `/cnb/lifecycle/launcher` in order to set `$PATH` correctly and get all of your actually-installed Rubies/gems/etc, rather than using the system versions.

### Scaling Strategy

**Rails and Sidekiq workloads**: If you're running out Sidekiq capacity (queues getting backed up) or Rails capacity (HTTP queue latency reported is unacceptable, say 150milliseconds or more), you should add additional "no volume" nodes by [increasing the task group `count`](https://www.nomadproject.io/docs/job-specification/group) to provide more resources, then change the `rails` jobspec file in the WikiEdu repo or use the [nomad job scale](https://www.nomadproject.io/docs/commands/job/scale) command.
* **More NGINX capacity** If Nginx is running out of CPU, resize the node (in `linode/main.tf`). This will take about 5 minutes and will cause hard downtime. You will then need to increase the cpu/memory allocation in the Nomad jobfile for Nginx.
* **More Redis or Memcache capacity**. Update the appropriate variables that control CPU/memory allocation. If that means that you have no available space in the cluster topology, provision additional nodes in `linode/main.tf`.
* **More MariaDB capacity**. Resize the node. This will cause hard downtime of 5 minutes or more. You will need to update the cpu/memory allocation in the mariadb job spec. It is intended that the mariadb job takes all of the resources on its node.