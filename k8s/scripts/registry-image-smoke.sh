#!/usr/bin/env bash
set -euo pipefail

credential_file="${1:?usage: registry-image-smoke.sh CREDENTIAL_FILE SERVICE_IP}"
service_ip="${2:?usage: registry-image-smoke.sh CREDENTIAL_FILE SERVICE_IP}"

# shellcheck disable=SC1090
source "${credential_file}"
: "${username:?registry username is required}"
: "${password:?registry password is required}"

source_image="docker://docker.io/library/busybox:1.37.0"
internal_image="docker://${service_ip}:5000/phase-d/busybox:1.37.0"
external_image="registry.dev.home.arpa/phase-d/busybox:1.37.0"

timeout 180s skopeo copy \
  --override-arch amd64 \
  --dest-tls-verify=false \
  --dest-creds "${username}:${password}" \
  "${source_image}" \
  "${internal_image}" >/dev/null
timeout 120s sudo k3s crictl pull "${external_image}"
