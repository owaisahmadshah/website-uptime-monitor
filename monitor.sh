#!/usr/bin/env bash

source "./lib/utils.sh"
source "./lib/help.sh"

# Default configuration paths
SITE_CONF_DEFAULT="./config/sites.conf"
MONITOR_CONF_DEFAULT="./config/monitor.conf"

load_config() {
  local target_conf="${1:-$MONITOR_CONF_DEFAULT}"

  if [[ ! -f "$target_conf" ]]; then
    echo "Error: Configuration file missing at: $target_conf" >&2
    exit 1
  fi

  source "$target_conf"
}

parse_args() {
  local monitor_conf_path="$MONITOR_CONF_DEFAULT"
  local site_conf_path="$SITE_CONF_DEFAULT"

  while getopts ":c:s:h" opt; do
    case ${opt} in
      c) monitor_conf_path="$OPTARG" ;;
      s) site_conf_path="$OPTARG" ;;
      h)
        show_help
        exit 0
        ;;
      \?) 
        echo "Invalid option: -$OPTARG" >&2
        show_help
        exit 1 
        ;;
      :) 
        echo "Option -$OPTARG requires an argument." >&2
        exit 1 
        ;;
    esac
  done

  load_config "$monitor_conf_path"
  TARGET_SITE_CONF="$site_conf_path"
}

is_valid_entry() {
  local line="$1"

  # Empty line or a comment
  if [[ -z "$line" || "$line" == \#* ]]; then
    return 1
  fi

  if ! validate_url "$line"; then
    echo "Invalid URL: $line" >&2
    return 1
  fi
  return 0
}

check_target() {
  local url="$1"
  status_code=000
  response_time="timeout"

  for _ in $(seq 1 "${RETRIES:-3}"); do
    local response
    response=$(curl --connect-timeout 2 --max-time "${TIMEOUT:-5}" -s -w "\n%{http_code} %{time_total}" "$url")

    local metadata
    metadata=$(echo "$response" | tail -n1)

    status_code=$(echo "$metadata" | awk '{print $1}')
    response_time=$(echo "$metadata" | awk '{printf "%.0f", $2 * 1000}')

    [[ "$status_code" -ge 200 && "$status_code" -lt 400 ]] && break
  done

  if [[ "$status_code" -lt 200 || "$status_code" -ge 400 ]]; then
    echo "❌ Server down: $url (Status: $status_code, Time: ${response_time}ms)"
    return 1
  fi

  echo "✅ Success: $url (Status: $status_code, Time: ${response_time}ms)"
  return 0
}

process_sites() {
  local site_file="$1"

  if [[ ! -f "$site_file" ]]; then
    echo "Error: Sites file missing at: $site_file" >&2
    exit 1
  fi

  while IFS= read -r raw_url || [[ -n "$raw_url" ]]; do
    shopt -s extglob
    local url="${raw_url%$'\r'}"
    url="${url##*([[:space:]])}"

    if is_valid_entry "$url"; then
      check_target "$url"
    fi
  done < "$site_file"
}

main() {
  parse_args "$@"
  process_sites "$TARGET_SITE_CONF"
}

main "$@"
