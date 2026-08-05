#!/usr/bin/env bash
# Load connection secrets from .env into the environment, then run the playbook.
# Any arguments passed are forwarded to ansible-playbook, e.g.:
#   ./run.sh                  # run all roles
#   ./run.sh --tags app       # run only the app role
set -euo pipefail

ENV_FILE="$(cd "$(dirname "$0")" && pwd)/.env"

if [[ ! -f "$ENV_FILE" ]]; then
  echo "Error: $ENV_FILE not found." >&2
  echo "Copy .env.example to .env and fill in your values:" >&2
  echo "  cp .env.example .env" >&2
  exit 1
fi

set -a
# shellcheck disable=SC1090
. "$ENV_FILE"
set +a

: "${SERVER_IP:?SERVER_IP must be set in .env}"

ansible-playbook setup.yml "$@"
