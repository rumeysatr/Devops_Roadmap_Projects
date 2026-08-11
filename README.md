# 🚀 DevOps Roadmap Projects

This repository collects the DevOps projects I've built while following the [roadmap.sh](https://roadmap.sh/devops) learning path. To keep things organized and to match how the roadmap itself is structured, my work is split across three branches by difficulty: a foundation-focused **Beginner** branch, an **Intermediate** branch built around Infrastructure as Code and automation, and the **main** branch where I practice CI/CD.

## 📂 Repository Structure & Branches

| Branch | Focus | What's inside |
| --- | --- | --- |
| **[`Beginner-Projects`](https://github.com/rumeysatr/Devops_Roadmap_Projects/tree/Beginner-Projects)** | Linux, shell & cloud foundations | Server setup, bash tooling, systemd, Docker, an EC2 instance |
| **[`Intermediate-Projects`](https://github.com/rumeysatr/Devops_Roadmap_Projects/tree/Intermediate-Projects)** | IaC, configuration management & CI/CD | Terraform, Ansible, and an end-to-end deployment pipeline on AWS |
| **[`main`](https://github.com/rumeysatr/Devops_Roadmap_Projects/tree/main)** | CI/CD in practice | An automated static-site deployment with GitHub Actions (this branch) |

---

## 🟢 Beginner-Projects Branch

Foundational hands-on work that builds up from a single Linux box to a live cloud-hosted site.

- **[`devops-foundations`](https://github.com/rumeysatr/Devops_Roadmap_Projects/tree/Beginner-Projects/devops-foundations)** — A three-phase project: provisioning and hardening a DigitalOcean Ubuntu droplet with Ed25519 SSH keys, UFW and fail2ban; serving a static site with Nginx and automating deploys with a bash + rsync script; then pointing a custom domain at it and securing it with Let's Encrypt.
- **[`server_performance_stats`](https://github.com/rumeysatr/Devops_Roadmap_Projects/tree/Beginner-Projects/server_performance_stats)** — A bash script that reports live CPU, memory and disk usage plus the top processes by CPU and memory.
- **[`log_archive_tool`](https://github.com/rumeysatr/Devops_Roadmap_Projects/tree/Beginner-Projects/log_archive_tool)** — A bash utility that compresses a directory's `.log` files into a timestamped `tar.gz` archive and keeps a history log.
- **[`nginx_log_analyser`](https://github.com/rumeysatr/Devops_Roadmap_Projects/tree/Beginner-Projects/nginx_log_analyser)** — A bash script that parses an Nginx access log to surface the top IPs, requested paths, status codes and user agents.
- **[`dummy_systemd_service`](https://github.com/rumeysatr/Devops_Roadmap_Projects/tree/Beginner-Projects/dummy_systemd_service)** — A "dummy" long-running service used to learn `systemd`: writing a unit file, enabling the service and inspecting its status and journal logs.
- **[`basic_dockerfile`](https://github.com/rumeysatr/Devops_Roadmap_Projects/tree/Beginner-Projects/basic_dockerfile)** — A minimal `alpine:latest` Docker image that prints a greeting, with an argument-aware entrypoint.
- **[`ec2_instance`](https://github.com/rumeysatr/Devops_Roadmap_Projects/tree/Beginner-Projects/ec2_instance)** — Launching an Ubuntu EC2 instance on AWS, connecting over SSH with a key pair, and serving a static page with Nginx over a public IP.

---

## 🟡 Intermediate-Projects Branch

Projects that move from manually configuring servers to defining infrastructure and deployments as code.

- **[`IaC-on-aws`](https://github.com/rumeysatr/Devops_Roadmap_Projects/tree/Intermediate-Projects/IaC-on-aws)** — Terraform provisions an isolated AWS network (custom VPC, public subnet, internet gateway, route table, security group and key pair) and an Ubuntu EC2 instance, then an Ansible playbook connects and installs Nginx. All connection details are loaded from a gitignored `.env`.
- **[`configuration-management`](https://github.com/rumeysatr/Devops_Roadmap_Projects/tree/Intermediate-Projects/configuration-management)** — An idiomatic Ansible setup using the roles pattern (`base`, `nginx`, `app`, `ssh`) to harden a server, serve a static website and add an authorized SSH key.
- **[`nodejs-service-deployment`](https://github.com/rumeysatr/Devops_Roadmap_Projects/tree/Intermediate-Projects/nodejs-service-deployment)** — An end-to-end pipeline: Terraform brings up the AWS EC2 host, Ansible installs and configures a Node.js/Express app behind an Nginx reverse proxy managed by systemd, and a GitHub Actions workflow deploys the app on every push to `main` with a health check.

---

## 🔵 main Branch — Featured: CI/CD with GitHub Actions

The project living in this branch demonstrates the automated deployment of a static website:

1. Whenever an update is pushed to the `index.html` file,
2. the workflow defined in [`.github/workflows/deploy.yml`](.github/workflows/deploy.yml) is triggered,
3. and the changes are automatically packaged and deployed live to GitHub Pages.

🔗 **Live site:** https://rumeysatr.github.io/Devops_Roadmap_Projects/
