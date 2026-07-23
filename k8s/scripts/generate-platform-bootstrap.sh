#!/usr/bin/env bash
set -euo pipefail

output_dir="${1:?usage: generate-platform-bootstrap.sh OUTPUT_DIRECTORY}"
umask 077
mkdir -p "${output_dir}"

openssl genpkey -algorithm RSA -pkeyopt rsa_keygen_bits:3072 \
  -out "${output_dir}/platform-ca.key"
openssl req -x509 -new -sha256 -days 3650 \
  -key "${output_dir}/platform-ca.key" \
  -subj "/CN=Local Development Platform CA" \
  -addext "basicConstraints=critical,CA:TRUE" \
  -addext "keyUsage=critical,keyCertSign,cRLSign" \
  -out "${output_dir}/platform-ca.crt"

openssl genpkey -algorithm RSA -pkeyopt rsa_keygen_bits:3072 \
  -out "${output_dir}/platform-tls.key"
openssl req -new -sha256 \
  -key "${output_dir}/platform-tls.key" \
  -subj "/CN=gitea.dev.home.arpa" \
  -addext "subjectAltName=DNS:gitea.dev.home.arpa,DNS:registry.dev.home.arpa,IP:192.168.50.10" \
  -addext "keyUsage=critical,digitalSignature,keyEncipherment" \
  -addext "extendedKeyUsage=serverAuth" \
  -out "${output_dir}/platform-tls.csr"
openssl x509 -req -sha256 -days 825 \
  -in "${output_dir}/platform-tls.csr" \
  -CA "${output_dir}/platform-ca.crt" \
  -CAkey "${output_dir}/platform-ca.key" \
  -CAcreateserial \
  -copy_extensions copy \
  -out "${output_dir}/platform-tls.crt"

registry_password="$(openssl rand -base64 36 | tr -d '\n')"
htpasswd -Bbn registry "${registry_password}" > "${output_dir}/htpasswd"
printf 'username=registry\npassword=%s\n' "${registry_password}" \
  > "${output_dir}/registry-credentials.env"

printf 'secret-key=%s\ninternal-token=%s\nlfs-jwt-secret=%s\noauth2-jwt-secret=%s\n' \
  "$(openssl rand -hex 32)" \
  "$(openssl rand -hex 32)" \
  "$(openssl rand -hex 32)" \
  "$(openssl rand -hex 32)" \
  > "${output_dir}/gitea-secrets.env"
printf 'username=developer-admin\nemail=developer@dev.home.arpa\npassword=%s\n' \
  "$(openssl rand -base64 36 | tr -d '\n')" \
  > "${output_dir}/gitea-admin.env"

rm -f "${output_dir}/platform-tls.csr" "${output_dir}/platform-ca.srl"
chmod 600 "${output_dir}"/*
openssl verify -CAfile "${output_dir}/platform-ca.crt" \
  "${output_dir}/platform-tls.crt"
