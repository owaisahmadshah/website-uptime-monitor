# Website Uptime Monitor

A lightweight, modular, zero-dependency website monitoring and alerting tool written in pure **POSIX-compliant Bash**. Automatically monitors site health, tracks response times in milliseconds, sends state-change alerts, monitors SSL certificate validity, and generates analytical uptime reports.

## Features

- **Multi-Site Monitoring**: Efficiently checks all target URLs listed in `config/sites.conf`.

- **Precision Latency Tracking**: Captures HTTP total response time converted directly into milliseconds (`ms`).

- **State Change Alerts**: Triggers notifications (Email ) **only** when a site transitions (UP ➔ DOWN or DOWN ➔ UP) to eliminate spam.

- **Retry Logic**: Minimizes false alarms caused by transient network glitches by retrying failed checks up to a configurable `$RETRIES` count.

- **SSL Certificate Expiry Checks**: Dedicated SSL validator (`lib/ssl_check.sh`) monitors TLS certificate validity.

- **Log Retention & Rotation**: Automated cleanup of legacy log files using `cleanup.sh`.

- **Analytical Reporting**: Generates detailed metrics including uptime percentage, average latency, and total failure events using `report.sh`.

## Project Structure

```
website-uptime-monitor/
├── monitor.sh              # Main monitoring execution script
├── report.sh               # Uptime report generator CLI tool
├── cleanup.sh              # Log retention and state cleanup utility
├── install.sh              # Installer & environment setup script
├── LICENSE                 # MIT License
├── README.md               # Project documentation
├── requirements.md         # Full project functional specification
├── config/
│   ├── monitor.conf        # Global application settings
│   └── sites.conf          # List of target URLs to monitor
├── lib/
│   ├── alert.sh            # Email and Telegram notification functions
│   ├── help.sh             # Command-line usage & help menu helper
│   ├── ssl_check.sh        # SSL certificate validity inspector
│   └── utils.sh            # Shared utility and validation functions
├── logs/
│   ├── uptime.log          # Complete chronological log of all checks
│   ├── failure.log         # Filtered failure-only log
│   └── state/              # Persistent site state tracking files
├── reports/                # Destination folder for generated reports
└── tests/
    ├── generate_sample_log.sh # Mock log generator for testing
    ├── sample_uptime.log   # Sample dataset for testing report calculations
    └── test_cases.md       # Quality assurance test scenarios

```

## Installation & Setup

1. **Clone the Repository:**

   ```
   git clone https://github.com/your-username/website-uptime-monitor.git
   cd website-uptime-monitor
   ```

2. **Run the Installer:**
   Make `install.sh` executable and run it to setup required directory permissions and verify dependencies:

   ```
   chmod +x install.sh
   ./install.sh
   ```

## Configuration

### 1. `config/sites.conf`

List target URLs to monitor (one per line). Lines starting with `#` are treated as comments:

```
# Production Web Endpoints
https://www.google.com
https://www.github.com
https://example.com

# Disabled endpoints
# https://staging.example.internal

```

### 2. `config/monitor.conf`

Configure runtime parameters and notification settings:

```
# Monitoring Parameters
TIMEOUT=10                 # Maximum seconds to wait for cURL response
RETRIES=3                  # Number of retry attempts before marking DOWN
RETRY_DELAY=5              # Delay between retry attempts in seconds
SLOW_THRESHOLD_MS=2000     # Threshold (in ms) to mark a response as SLOW
LOG_RETENTION_DAYS=30      # Auto-purge logs older than N days

# Email Notifications
ENABLE_EMAIL=true
ALERT_EMAIL="admin@example.com"
```

## Usage

### Monitoring Script (`monitor.sh`)

```
# Run one check cycle using default configuration paths
./monitor.sh

# Run using a custom monitor configuration file
./monitor.sh -c ./config/custom_monitor.conf

# Run using a custom sites list
./monitor.sh -s ./config/production_sites.conf

# Display help menu
./monitor.sh -h
```

### Reporting Tool (`report.sh`)

```
# Generate overall report for all recorded logs
./report.sh

# Generate report for a specific date (YYYY-MM-DD)
./report.sh -d 2026-03-31

# Generate summary report for the last 7 days
./report.sh -w
```

### Log Cleanup (`cleanup.sh`)

Purges logs and temporary files older than the configured `LOG_RETENTION_DAYS`:

```
./cleanup.sh

```

## Sample Output

### Terminal Console Output

```
=====================================================
   WEBSITE UPTIME MONITOR  -  2026-03-31 14:30:02
=====================================================
Success: https://www.google.com (Status: 200, Time: 142ms)
Success: https://www.github.com (Status: 200, Time: 310ms)
Warning: https://example.com (Status: 200, Time: 2450ms) [SLOW]
Server down: https://broken-site.xyz (Status: 000, Time: timeout)
-----------------------------------------------------
Checked: 4 | Up: 2 | Slow: 1 | Down: 1

```

### Raw Log Structure (`logs/uptime.log`)

```
2026-03-31 14:30:02 | https://www.google.com | UP   | 200 | 142ms
2026-03-31 14:30:07 | https://broken-site.xyz | DOWN | 000 | timeout

```

## Cron Automation

To enable 24/7 background monitoring and automated reports, add the following cron jobs (`crontab -e`):

```
# Run monitoring check every 5 minutes
*/5 * * * * /bin/bash /path/to/website-uptime-monitor/monitor.sh >> /path/to/website-uptime-monitor/logs/cron.log 2>&1

# Run daily log cleanup at midnight
0 0 * * * /bin/bash /path/to/website-uptime-monitor/cleanup.sh >> /path/to/website-uptime-monitor/logs/cron.log 2>&1

# Send daily report at 8:00 AM for yesterday's activity
0 8 * * * /bin/bash /path/to/website-uptime-monitor/report.sh -d $(date -d yesterday +\%F)

```

## Alert System

- **State Persistence**: State tracking files stored in `logs/state/` store the previous status of every checked host.

- **Anti-Spam Filter**: Notifications are only dispatched when status transitions:
  - **DOWN Event**: Triggered when a host changes state from `UP` ➔ `DOWN`.

  - **RECOVERY Event**: Triggered when a host changes state from `DOWN` ➔ `UP`.

## Requirements

- **OS**: Linux, macOS, or WSL (Windows Subsystem for Linux)

- **Shell**: GNU Bash 4.0+

- **Core Utilities**: `curl`, `awk`, `sed`, `grep`

- **Mailer** _(Optional for email alerts)_: `mail`, `mailx`, or `msmtp`

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
