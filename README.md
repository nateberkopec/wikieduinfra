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