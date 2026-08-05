# Configuration Management (Ansible)

Ansible playbook that configures a Linux server with a base setup, nginx, a
static website and an authorized SSH key. See `docs/en_subject.md` for the
full assignment.

## Roles

| Role    | Description                                                       |
| ------- | ---------------------------------------------------------------- |
| `base`  | Updates packages and installs base utilities + fail2ban          |
| `nginx` | Installs and configures nginx to serve the site                  |
| `app`   | Uploads and extracts the static website tarball                  |
| `ssh`   | Adds the public key from `roles/ssh/files/authorized_key.pub`    |

## Secret management

Server connection details (IP, SSH user, private key path) are **not** stored
in the repository. They live in a local `.env` file (gitignored) and are bound
to the playbook at runtime via environment-variable lookups in
[`group_vars/all.yml`](group_vars/all.yml).

1. Copy the template and fill in your values:
   ```bash
   cp .env.example .env
   ```
   `.env` contents:
   ```
   SERVER_IP=<your server IP>
   SSH_USER=ubuntu
   SSH_KEY_PATH=<path to your SSH private key>
   ```
2. Run the playbook — the wrapper loads `.env` automatically:
   ```bash
   ./run.sh
   ```

## Usage

```bash
# Run every role
./run.sh

# Run a single role (tags: base, nginx, app, ssh)
./run.sh --tags app
```

> The default cloud image user usually has passwordless `sudo`. If `become`
> prompts for a password, pass `--ask-become-pass` to `./run.sh`.
