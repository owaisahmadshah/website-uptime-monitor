#!/usr/bin/env bash
# Setup script: checks requirements, creates folders, sets permissions,
# and (optionally) installs the cron jobs.
# Usage: ./install.sh [--yes] [--uninstall] [-h|--help]

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MARKER="# website-uptime-monitor"

ASSUME_YES=false
UNINSTALL=false

usage() {
  cat <<USAGE
Usage: ./install.sh [--yes] [--uninstall]
  --yes        do not ask, install the cron jobs
  --uninstall  remove the cron jobs added by this script
  -h, --help   show this help
USAGE
}

check_requirements() {
  local missing=false
  for tool in curl awk; do
    if ! command -v "$tool" >/dev/null 2>&1; then
      echo "Error: $tool is required but not installed." >&2
      missing=true
    fi
  done
  if [[ "${BASH_VERSINFO[0]}" -lt 4 ]]; then
    echo "Error: Bash 4 or newer is required (found ${BASH_VERSION})." >&2
    missing=true
  fi
  [[ "$missing" == true ]] && exit 1
  echo "Requirements OK (curl, awk, Bash ${BASH_VERSION%%[^0-9.]*})."
}

create_folders() {
  local dir
  for dir in logs logs/state logs/archive reports; do
    mkdir -p "$SCRIPT_DIR/$dir"
  done
  echo "Folders ready: logs, logs/state, logs/archive, reports."
}

set_permissions() {
  local f
  for f in "$SCRIPT_DIR"/*.sh "$SCRIPT_DIR"/lib/*.sh "$SCRIPT_DIR"/tests/*.sh; do
    [[ -f "$f" ]] && chmod +x "$f"
  done
  echo "Scripts are executable."
}

require_crontab() {
  if ! command -v crontab >/dev/null 2>&1; then
    echo "Error: crontab command not found. Install cron to use scheduling." >&2
    exit 1
  fi
}

# Write the current crontab, minus our lines, into the file given as $1
write_clean_crontab() {
  crontab -l 2>/dev/null | grep -v 'website-uptime-monitor' > "$1"
}

install_cron() {
  require_crontab
  local tmp
  tmp=$(mktemp) || exit 1
  trap 'rm -f "$tmp"' RETURN

  write_clean_crontab "$tmp"

  # % must be written as \% inside a cron line
  {
    echo "*/5 * * * * /bin/bash \"$SCRIPT_DIR/monitor.sh\" >> \"$SCRIPT_DIR/logs/cron.log\" 2>&1 $MARKER"
    echo "0 0 * * * /bin/bash \"$SCRIPT_DIR/cleanup.sh\" >> \"$SCRIPT_DIR/logs/cron.log\" 2>&1 $MARKER"
    echo "0 8 * * * /bin/bash \"$SCRIPT_DIR/report.sh\" -d \$(date -d yesterday +\\%F) $MARKER"
  } >> "$tmp"

  if crontab "$tmp"; then
    echo "Cron jobs installed (monitor every 5 min, cleanup at 00:00, report at 08:00)."
  else
    echo "Error: could not install the cron jobs." >&2
    exit 1
  fi
}

uninstall_cron() {
  require_crontab
  local tmp
  tmp=$(mktemp) || exit 1
  trap 'rm -f "$tmp"' RETURN

  write_clean_crontab "$tmp"
  if crontab "$tmp"; then
    echo "Cron jobs removed."
  else
    echo "Error: could not update the crontab." >&2
    exit 1
  fi
}

main() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --yes|-y)    ASSUME_YES=true ;;
      --uninstall) UNINSTALL=true ;;
      -h|--help)   usage; exit 0 ;;
      *) echo "Error: Unknown option $1" >&2; usage >&2; exit 1 ;;
    esac
    shift
  done

  if [[ "$UNINSTALL" == true ]]; then
    uninstall_cron
    exit 0
  fi

  check_requirements
  create_folders
  set_permissions

  if [[ "$ASSUME_YES" == true ]]; then
    install_cron
  else
    local answer=""
    read -r -p "Add the cron jobs now? [y/N] " answer
    if [[ "$answer" =~ ^[Yy]([Ee][Ss])?$ ]]; then
      install_cron
    else
      echo "Skipped cron jobs. Run ./install.sh --yes later to add them."
    fi
  fi

  echo "Done."
}

main "$@"
