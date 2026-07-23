#!/usr/bin/env bash
set -euo pipefail

output_dir="${1:?usage: rotate-registry-credentials.sh OUTPUT_DIRECTORY}"
umask 077
test ! -e "${output_dir}"
mkdir "${output_dir}"

password="$(openssl rand -base64 36 | tr -d '\n')"
htpasswd -Bbn registry "${password}" > "${output_dir}/htpasswd"
printf 'username=registry\npassword=%s\n' "${password}" \
  > "${output_dir}/registry-credentials.env"
chmod 600 "${output_dir}"/*
