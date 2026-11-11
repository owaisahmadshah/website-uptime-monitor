#!/bin/bash

source "./lib/utils.sh"

# Configuration files
site_conf="./config/sites.conf"
monitor_conf="./config/monitor.conf"

TIMEOUT=5
RETRIES=3

[[ -f "$site_conf" ]] || { echo "Error: $site_conf is missing!" >&2; exit 1; }
[[ -f "$monitor_conf" ]] || { echo "Error: $monitor_conf is missing!" >&2; exit 1; }

while IFS= read -r URL; do
  URL="${URL%$'\r'}"

  # Empty lines
  [[ -z "$URL" ]] && continue

  # Strip leading whitespaces
  shopt -s extglob
  URL="${URL##*([[:space:]])}"

  if [[ -z "$URL" || "$URL" == \#* ]]; then
    continue
  fi

  if ! validate_url "$URL"; then
    echo "Invalid URL: $URL"
    continue
  fi

  status_code=000
  response_time="timeout"
  status="DOWN"

  for _ in {1..RETRIES}
  do
    RESPONSE=$(curl --connect-timeout 2 --max-time "$TIMEOUT" -s -w "\n%{http_code} %{time_total}" "$URL")

    METADATA=$(echo "$RESPONSE" | tail -n1)

    status_code=$(echo "$METADATA" | awk '{print $1}')
    response_time=$(echo "$METADATA" | awk '{printf "%.0f", $2 * 1000}')

    [[ "$status_code" -ge 200 && "$status_code" -lt 400 ]] && break
  done

  if [[ "$status_code" -lt 200 || "$status_code" -ge 400 ]]; then
    echo "Server is down, and responded with status code: $status_code and response time: $response_time"
    continue
  fi

  echo "✅ Success! Server responded with status code: $status_code and reponse time: $response_time"


done < "$site_conf"
