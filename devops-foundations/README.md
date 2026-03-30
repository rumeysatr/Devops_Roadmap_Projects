# DevOps Foundations: Server Setup, Web Hosting, and DNS Management 🚀

This repository documents my hands-on journey through three foundational DevOps and Cloud Infrastructure projects. The primary goal was to build a secure, fully functional web server from scratch, automate the deployment process, and route public traffic using custom DNS records and SSL encryption.

## 📋 Table of Contents
1. [Project Overview](#-project-overview)
2. [Technologies Used](#-technologies-used)
3. [Phase 1: SSH Remote Server Setup](#phase-1-ssh-remote-server-setup)
4. [Phase 2: Static Site Server & Automation](#phase-2-static-site-server-automation)
5. [Phase 3: Basic DNS Setup & SSL](#phase-3-basic-dns-setup-ssl)
6. [Learning Outcomes](#-learning-outcomes)

---

## 🎯 Project Overview
This repository is a culmination of three distinct but interconnected projects:
* **Provisioning and Securing** a bare-metal Linux droplet.
* **Configuring** a web server to host static assets and automating deployments.
* **Managing DNS** to map a custom domain to the server and securing it with HTTPS.

---

## 🛠 Technologies Used
* **Cloud Provider:** DigitalOcean (Ubuntu VPS)
* **Web Server:** Nginx
* **Security:** SSH (Ed25519 Keys), UFW (Uncomplicated Firewall), Fail2ban
* **Automation & CI/CD:** Bash Scripting, Rsync
* **DNS & SSL:** Name.com, Let's Encrypt (Certbot)

---

## Phase 1: SSH Remote Server Setup 🔐
The objective of this phase was to provision a remote Linux server and secure it using SSH key authentication, disabling vulnerable password-based root logins.

**Key Implementations:**
1. Spun up an Ubuntu droplet on DigitalOcean.
2. Generated two separate `Ed25519` SSH key pairs locally.
3. Added the public keys to the remote server's `~/.ssh/authorized_keys` file.
4. Created an alias in the local `~/.ssh/config` file for quick and secure connections.
5. **Stretch Goal:** Installed and configured `fail2ban` to monitor authentication logs and automatically ban IP addresses exhibiting malicious signs (brute-force attacks).

**Connection Command:**
```bash
ssh droplet-server
```

---

## Phase 2: Static Site Server & Automation 🌐
This phase transitioned the secured server into a live web server capable of serving HTML/CSS content to the public, alongside creating an automated deployment pipeline.

**Key Implementations:**
1. Installed and enabled **Nginx**.
2. Configured the Uncomplicated Firewall (UFW) to allow web traffic (`sudo ufw allow 'Nginx Full'`).
3. Created a basic static website structure locally.
4. Wrote a bash script (`deploy.sh`) utilizing `rsync` over SSH to push local changes to the live `/var/www/html/` directory effortlessly.

**Deployment Script (`deploy.sh`):**
```bash
#!/bin/bash
echo "🚀 Deploying site to DigitalOcean droplet..."
rsync -avz -e ssh ./public/ root@<server-ip>:/var/www/html/
echo "✅ Deployment successful!"
```

---

## Phase 3: Basic DNS Setup & SSL 🌍
The final phase focused on Domain Name System (DNS) management to replace the raw IP address with a professional, human-readable custom domain, and securing the traffic.

**Key Implementations:**
1. Registered the custom domain `beautifulworld.dev` via Name.com using the GitHub Student Developer Pack.
2. Configured **A Records** in the DNS panel to point both the root domain (`@`) and the `www` subdomain to the DigitalOcean droplet's IP address (`<server-ip>`).
3. Updated the Nginx Server Block to listen for the specific domain names:
   ```nginx
   server {
       listen 80;
       server_name beautifulworld.dev www.beautifulworld.dev;
       root /var/www/html;
       index index.html;
   }
   ```
4. **SSL Configuration:** Since `.dev` domains require strict HTTPS (HSTS), installed **Certbot** and automatically provisioned a free SSL/TLS certificate from Let's Encrypt.

---

## 🧠 Learning Outcomes
By completing these interconnected projects, I gained practical, hands-on experience in:
- Linux system administration and remote server management.
- Hardening server security using SSH protocols and Intrusion Prevention Systems (Fail2ban).
- Configuring reverse proxies and web servers (Nginx).
- Automating file synchronization between local and remote environments (Rsync).
- Managing global DNS records, understanding propagation, and implementing HTTPS via Let's Encrypt.
```