#!/usr/bin/env bash
# Load secrets/config from .env into the environment, then run terraform or ansible.
#
#   ./run.sh tf <args>        e.g. ./run.sh tf plan | ./run.sh tf apply | ./run.sh tf destroy
#   ./run.sh ansible <args>   e.g. ./run.sh ansible
#
# Terraform picks the TF_VAR_* variables up automatically once they are in the
# environment; Ansible reads SERVER_IP / SSH_USER / SSH_KEY_PATH via lookup('env').
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

case "${1:-}" in
  tf)
    shift
    cd "$(dirname "$0")"
    terraform "$@"
    ;;
  ansible)
    shift
    : "${SERVER_IP:?SERVER_IP must be set in .env}"
    cd "$(dirname "$0")/ansible"
    ansible-playbook -i inventory.ini playbook.yml "$@"
    ;;
  *)
    echo "Usage: $0 {tf|ansible} [args]" >&2
    echo "  tf plan | tf apply | tf destroy   manage the AWS infrastructure" >&2
    echo "  ansible                           configure the EC2 host (Nginx)" >&2
    exit 1
    ;;
esac
