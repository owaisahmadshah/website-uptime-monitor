#!/usr/bin/env bash

show_help() {
  echo "Usage: ./monitor.sh [-c CONFIG_PATH] [-s SITES_PATH] [-h]"
  echo ""
  echo "Options:"
  echo "  -c    Path to monitor.conf (Default: ./config/monitor.conf)"
  echo "  -s    Path to sites.conf   (Default: ./config/sites.conf)"
  echo "  -h    Show this help message"
}
