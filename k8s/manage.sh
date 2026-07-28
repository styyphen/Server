#!/usr/bin/env bash
set -Eeuo pipefail

script_path="$(readlink -f "${BASH_SOURCE[0]}")"
repo_root="$(cd "$(dirname "$script_path")/.." && pwd)"
overlay="$repo_root/k8s/overlays/current"
gum_bin="${GUM_BIN:-gum}"
export KUBECONFIG="${KUBECONFIG:-$HOME/.kube/config}"
export K3S_CONFIG_FILE="${K3S_CONFIG_FILE:-/dev/null}"

have_gum() {
  [[ -t 0 && -t 1 ]] && command -v "$gum_bin" >/dev/null 2>&1
}

heading() {
  if have_gum; then
    "$gum_bin" style --bold --foreground 212 --border rounded --padding "0 2" "$1"
  else
    printf '\n== %s ==\n' "$1"
  fi
}

show_status() {
  heading "Standalone Kubernetes status"
  kubectl get nodes -o wide
  printf '\n'
  kubectl get pods -A
}

show_pods() {
  heading "Pods"
  kubectl get pods -A -o wide
}

show_workloads() {
  heading "Workloads"
  kubectl get deployments,statefulsets,daemonsets -A
}

show_services() {
  heading "Services and ingress"
  kubectl get services,ingresses -A -o wide
}

show_events() {
  heading "Recent warning events"
  kubectl get events -A --field-selector type=Warning --sort-by=.lastTimestamp | tail -80
}

show_logs() {
  if ! have_gum; then
    printf 'The logs command requires an interactive terminal with gum.\n' >&2
    return 2
  fi
  local namespace pod
  namespace="$(kubectl get namespaces -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}' | "$gum_bin" filter --placeholder "Select namespace")"
  [[ -n "$namespace" ]] || return 0
  pod="$(kubectl -n "$namespace" get pods -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}' | "$gum_bin" filter --placeholder "Select pod")"
  [[ -n "$pod" ]] || return 0
  kubectl -n "$namespace" logs "$pod" --all-containers --tail=300 --timestamps | "$gum_bin" pager
}

validate_overlay() {
  heading "Validate desired state"
  local rendered
  rendered="$(mktemp)"
  if kubectl kustomize "$overlay" >"$rendered" &&
     kubectl apply --dry-run=server -f "$rendered"; then
    rm -f "$rendered"
  else
    local result=$?
    rm -f "$rendered"
    return "$result"
  fi
}

apply_overlay() {
  if have_gum; then
    "$gum_bin" confirm "Apply the complete current overlay to this cluster?" || return 0
  else
    printf 'Refusing non-interactive apply. Run kube-manage from a terminal.\n' >&2
    return 2
  fi
  validate_overlay
  kubectl apply -k "$overlay"
}

monitoring_sites() {
  if ! have_gum; then
    printf 'The monitoring-sites command requires an interactive terminal with gum.\n' >&2
    return 2
  fi
  local site name namespace target forwarding url local_port server_address ssh_user ssh_command
  site="$("$gum_bin" choose --header "Select monitoring site" \
    "Gitea|platform-system|service/gitea|3000:3000|http://localhost:3000" \
    "SonarQube|cloud-emulators|service/sonarqube|9000:9000|http://localhost:9000" \
    "Full-stack demo|demo-apps|service/junior-fullstack-demo|8080:8080|http://localhost:8080" \
    "Grafana|observability|service/grafana|3001:3000|http://localhost:3001" \
    "Prometheus|observability|service/prometheus|9090:9090|http://localhost:9090" \
    "Alertmanager|observability|service/alertmanager|9093:9093|http://localhost:9093" \
    "Loki|observability|service/loki|3100:3100|http://localhost:3100" \
    "Tempo|observability|service/tempo|3200:3200|http://localhost:3200")"
  [[ -n "$site" ]] || return 0
  IFS='|' read -r name namespace target forwarding url <<<"$site"
  local_port="${forwarding%%:*}"
  heading "$name monitoring"

  if "$gum_bin" confirm "Is your browser on another computer connected over SSH?"; then
    if [[ -n "${SSH_CONNECTION:-}" ]]; then
      read -r _ _ server_address _ <<<"$SSH_CONNECTION"
    else
      server_address="$(hostname -I | awk '{print $1}')"
    fi
    ssh_user="${USER:-developer}"
    ssh_command="ssh -N -L ${local_port}:127.0.0.1:${local_port} ${ssh_user}@${server_address}"
    "$gum_bin" style --bold --foreground 214 "Run this in a second terminal on your browser computer:"
    printf '%s\n\nThen open %s.\n' "$ssh_command" "$url"
  else
    printf 'This site will be available only to a browser running on this server at %s.\n' "$url"
  fi

  printf 'Keep this command running; press Ctrl+C to stop the port-forward.\n'
  exec kubectl -n "$namespace" port-forward "$target" "$forwarding" --address 127.0.0.1
}

port_forward() {
  if ! have_gum; then
    printf 'The port-forward command requires an interactive terminal with gum.\n' >&2
    return 2
  fi
  local site name namespace target forwarding
  site="$("$gum_bin" choose --header "Select local verification site" \
    "Gitea|platform-system|service/gitea|3000:3000" \
    "SonarQube|cloud-emulators|service/sonarqube|9000:9000" \
    "Full-stack demo|demo-apps|service/junior-fullstack-demo|8080:8080" \
    "Prometheus|observability|service/prometheus|9090:9090" \
    "Grafana|observability|service/grafana|3001:3000" \
    "OpenTelemetry health|observability|deployment/otel-collector|13133:13133")"
  [[ -n "$site" ]] || return 0
  IFS='|' read -r name namespace target forwarding <<<"$site"
  heading "$name port-forward"
  printf 'Press Ctrl+C to stop.\n'
  exec kubectl -n "$namespace" port-forward "$target" "$forwarding" --address 127.0.0.1
}

run_command() {
  case "${1:-menu}" in
    status) show_status ;;
    pods) show_pods ;;
    workloads) show_workloads ;;
    services) show_services ;;
    events) show_events ;;
    logs) show_logs ;;
    validate) validate_overlay ;;
    apply) apply_overlay ;;
    monitoring) monitoring_sites ;;
    port-forward) port_forward ;;
    menu)
      if ! have_gum; then
        show_status
        return
      fi
      local choice
      choice="$("$gum_bin" choose --header "Kubernetes management" \
        "Status" "Pods" "Workloads" "Services and ingress" \
        "Warning events" "Pod logs" "Monitoring sites" "Validate desired state" \
        "Apply desired state" "Port-forward verification site")"
      case "$choice" in
        Status) show_status ;;
        Pods) show_pods ;;
        Workloads) show_workloads ;;
        "Services and ingress") show_services ;;
        "Warning events") show_events ;;
        "Pod logs") show_logs ;;
        "Monitoring sites") monitoring_sites ;;
        "Validate desired state") validate_overlay ;;
        "Apply desired state") apply_overlay ;;
        "Port-forward verification site") port_forward ;;
      esac
      ;;
    *)
      printf 'Usage: kube-manage [status|pods|workloads|services|events|logs|monitoring|validate|apply|port-forward]\n' >&2
      return 2
      ;;
  esac
}

command -v kubectl >/dev/null 2>&1 || {
  printf 'kubectl is required.\n' >&2
  exit 127
}

run_command "${1:-menu}"
