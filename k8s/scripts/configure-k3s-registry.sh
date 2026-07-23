#!/usr/bin/env bash
set -euo pipefail

ca_file="${1:?usage: configure-k3s-registry.sh CA_FILE CREDENTIAL_ENV_FILE}"
credential_file="${2:?usage: configure-k3s-registry.sh CA_FILE CREDENTIAL_ENV_FILE}"

# shellcheck disable=SC1090
source "${credential_file}"
: "${username:?registry username is required}"
: "${password:?registry password is required}"

sudo install -o root -g root -m 0644 "${ca_file}" \
  /usr/local/share/ca-certificates/local-development-platform-ca.crt
sudo update-ca-certificates >/dev/null

if ! grep -q 'gitea\.dev\.home\.arpa' /etc/hosts; then
  printf '%s\n' \
    '192.168.50.10 gitea.dev.home.arpa registry.dev.home.arpa' |
    sudo tee -a /etc/hosts >/dev/null
fi

registry_config="$(mktemp)"
trap 'rm -f "${registry_config}"' EXIT
chmod 600 "${registry_config}"
printf '%s\n' \
  'mirrors:' \
  '  "registry.dev.home.arpa":' \
  '    endpoint:' \
  '      - "https://registry.dev.home.arpa"' \
  'configs:' \
  '  "registry.dev.home.arpa":' \
  '    auth:' \
  "      username: '${username}'" \
  "      password: '${password}'" \
  '    tls:' \
  '      ca_file: /usr/local/share/ca-certificates/local-development-platform-ca.crt' \
  > "${registry_config}"
sudo install -o root -g root -m 0600 "${registry_config}" \
  /etc/rancher/k3s/registries.yaml

sudo systemctl restart k3s
