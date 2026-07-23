#!/usr/bin/env sh
set -eu

if [ "$(id -u)" -ne 0 ]; then
  echo "Run as root on the Ubuntu server." >&2
  exit 1
fi

if [ ! -f /etc/rancher/k3s/config.yaml ]; then
  echo "Copy k8s/config/k3s-config.yaml to /etc/rancher/k3s/config.yaml first." >&2
  exit 1
fi

: "${INSTALL_K3S_VERSION:?Set INSTALL_K3S_VERSION to an explicitly approved K3s version.}"

curl --proto '=https' --tlsv1.2 -sfL https://get.k3s.io |
  INSTALL_K3S_VERSION="$INSTALL_K3S_VERSION" sh -

systemctl enable --now k3s
kubectl wait --for=condition=Ready node --all --timeout=180s
