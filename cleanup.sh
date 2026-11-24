#!/usr/bin/env bash
# Log cleanup: removes log lines older than LOG_RETENTION_DAYS.
# Usage: ./cleanup.sh [--dry-run] [--compress] [-h|--help]

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MONITOR_CONF="$SCRIPT_DIR/config/monitor.conf"

DRY_RUN=false
COMPRESS=false

usage() {
  cat <<USAGE
Usage: ./cleanup.sh [--dry-run] [--compress]
  --dry-run   only show what would be removed, change nothing
  --compress  keep removed lines in logs/archive/ as .gz
  -h, --help  show this help
USAGE
}

load_config() {
  if [[ ! -f "$MONITOR_CONF" ]]; then
    echo "Error: Configuration file missing at: $MONITOR_CONF" >&2
    exit 1
  fi
  source "$MONITOR_CONF"

  if [[ "${LOG_DIR:-./logs}" != /* ]]; then
    LOG_DIR="$SCRIPT_DIR/${LOG_DIR#./}"
  fi

  RETENTION="${LOG_RETENTION_DAYS:-30}"
  if ! [[ "$RETENTION" =~ ^[0-9]+$ ]]; then
    echo "Error: LOG_RETENTION_DAYS must be a whole number (got: $RETENTION)." >&2
    exit 1
  fi
}

# Remove lines older than the cutoff from one log file.
# Lines that do not start with a date are kept, to be safe.
prune_log() {
  local file="$1" cutoff="$2"
  local name
  name=$(basename "$file")

  [[ -f "$file" ]] || { echo "$name: not found, skipping."; return 0; }

  local keep removed
  keep=$(mktemp "$file.keep.XXXXXX") || return 1
  removed=$(mktemp "$file.old.XXXXXX") || { rm -f "$keep"; return 1; }

  awk -v cutoff="$cutoff" -v keepf="$keep" -v oldf="$removed" '
    /^[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]/ && ("" substr($0,1,10)) < cutoff { print > oldf; next }
    { print > keepf }
  ' "$file"

  local n_old n_keep
  n_old=$(wc -l < "$removed" | tr -d ' ')
  n_keep=$(wc -l < "$keep" | tr -d ' ')

  if [[ "$n_old" -eq 0 ]]; then
    echo "$name: nothing older than $cutoff."
  elif [[ "$DRY_RUN" == true ]]; then
    echo "$name: would remove $n_old line(s), keep $n_keep (older than $cutoff)."
  else
    if [[ "$COMPRESS" == true ]]; then
      mkdir -p "$LOG_DIR/archive"
      # gzip streams can be concatenated, so repeated runs on one day append safely
      gzip -c "$removed" >> "$LOG_DIR/archive/${name%.log}_$(date +%F).log.gz"
    fi
    chmod --reference="$file" "$keep" 2>/dev/null
    mv "$keep" "$file"
    echo "$name: removed $n_old line(s), kept $n_keep (older than $cutoff)."
    keep=""
  fi

  rm -f ${keep:+"$keep"} "$removed"
}

# Old files are safe to delete by modified date only in archive/ and for cron.log.
prune_files() {
  local action=(-delete)
  [[ "$DRY_RUN" == true ]] && action=(-print)

  local old tag=""
  [[ "$DRY_RUN" == true ]] && tag="[dry-run] "
  if [[ -d "$LOG_DIR/archive" ]]; then
    old=$(find "$LOG_DIR/archive" -type f -mtime +"$RETENTION" "${action[@]}")
    [[ -n "$old" ]] && echo "$tagold archive files:" && echo "$old"
  fi
  old=$(find "$LOG_DIR" -maxdepth 1 -type f -name cron.log -mtime +"$RETENTION" "${action[@]}")
  [[ -n "$old" ]] && echo "$tagold cron.log:" && echo "$old"
  return 0
}

main() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --dry-run)  DRY_RUN=true ;;
      --compress) COMPRESS=true ;;
      -h|--help)  usage; exit 0 ;;
      *) echo "Error: Unknown option $1" >&2; usage >&2; exit 1 ;;
    esac
    shift
  done

  load_config

  local cutoff
  cutoff=$(date -d "$RETENTION days ago" +%F)
  [[ "$DRY_RUN" == true ]] && echo "[dry-run] No files will be changed."
  echo "Retention: $RETENTION days, cutoff date: $cutoff"

  prune_log "$LOG_DIR/uptime.log" "$cutoff"
  prune_log "$LOG_DIR/failure.log" "$cutoff"
  prune_files
}

main "$@"
