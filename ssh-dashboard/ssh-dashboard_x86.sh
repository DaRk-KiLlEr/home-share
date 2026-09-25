#!/bin/bash

# ─────────────────────────────────────────────
# SSH Dashboard
# ─────────────────────────────────────────────

# OS
if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS="$PRETTY_NAME $(uname -m)"
else
    OS="$(uname -s) $(uname -m)"
fi

# Host / hardware
if [ -f /proc/device-tree/model ]; then
    HOST=$(tr -d '\0' < /proc/device-tree/model)
elif [ -f /sys/devices/virtual/dmi/id/product_name ]; then
    HOST=$(cat /sys/devices/virtual/dmi/id/product_name)
else
    HOST="Unknown"
fi

# Kernel
KERNEL=$(uname -r)

# Proxmox VE
PVE=""
if command -v pveversion >/dev/null 2>&1; then
    PVE=$(pveversion 2>/dev/null | sed -n 's/^pve-manager\/\([^\/]*\).*/\1/p')
fi

# Uptime
UPTIME=$(uptime -p | sed 's/^up //')

# CPU usage (%)
CPU=$(top -bn1 | awk '/Cpu\(s\)/ {printf "%.0f", 100 - $8}')

# Load average (1 / 5 / 15 min)
LOAD=$(awk '{printf "%.2f  %.2f  %.2f", $1, $2, $3}' /proc/loadavg)

# Memory usage
MEM=$(free | awk '/Mem:/ {printf "%.0f", ($3/$2)*100}')

# IPv4
IP=$(hostname -I | awk '{print $1}')

echo
echo "       System information as of $(date '+%a %b %-d %H:%M:%S %Z %Y')"
echo
printf "  OS:       %s\n" "$OS"
printf "  Host:     %s\n" "$HOST"
printf "  Kernel:   %s\n" "$KERNEL"

if [ -n "$PVE" ]; then
    printf "  PVE:      %s\n" "$PVE"
fi

printf "  Uptime:   %s\n" "$UPTIME"
printf "  CPU:      %s%%\n" "$CPU"
printf "  Load avg: %s\n" "$LOAD"
printf "  Memory:   %s%%\n" "$MEM"

# ─────────────────────────────────────────────
# Local disks / filesystems
# ─────────────────────────────────────────────

while read -r filesystem mountpoint; do

    # Label
    if [ "$mountpoint" = "/" ]; then
        LABEL="Disk /:"
    else
        LABEL="Disk $mountpoint:"
    fi

    USAGE=$(df -P "$mountpoint" 2>/dev/null |
        awk 'NR==2 {print $5}')

    [ -n "$USAGE" ] && printf "  %-10s %s\n" "$LABEL" "$USAGE"

done < <(
    findmnt -rn -o SOURCE,TARGET -t ext2,ext3,ext4,xfs,btrfs,zfs,f2fs
)

printf "  IP:       %s\n" "$IP"

echo
echo "  Temperatures"
echo "  ─────────────────────────"

# ─────────────────────────────────────────────
# CPU temperature
# ─────────────────────────────────────────────

CPU_TEMP=""

# x86: coretemp Package id 0
if command -v sensors >/dev/null 2>&1; then
    CPU_TEMP=$(sensors 2>/dev/null |
        awk '/Package id 0:/ {
            gsub(/[+°C]/,"",$4)
            print $4
            exit
        }')
fi

# Raspberry Pi / ARM fallback
if [ -z "$CPU_TEMP" ]; then
    for f in /sys/class/thermal/thermal_zone*/temp; do
        [ -r "$f" ] || continue

        type_file="$(dirname "$f")/type"
        [ -r "$type_file" ] && type=$(cat "$type_file") || type=""

        case "$type" in
            *cpu*|*CPU*|*soc*|*SoC*|cpu_thermal)
                CPU_TEMP=$(awk '{printf "%.1f", $1/1000}' "$f")
                break
                ;;
        esac
    done
fi

# Final fallback via sensors
if [ -z "$CPU_TEMP" ] && command -v sensors >/dev/null 2>&1; then
    CPU_TEMP=$(sensors 2>/dev/null |
        awk '/temp1:/ {
            gsub(/[+°C]/,"",$2)
            print $2
            exit
        }')
fi

if [ -n "$CPU_TEMP" ]; then
    printf "  CPU/SoC       %s°C\n" "$CPU_TEMP"
fi

# ─────────────────────────────────────────────
# Other thermal sensors
# ─────────────────────────────────────────────

if command -v sensors >/dev/null 2>&1; then

    sensors 2>/dev/null | awk '
    BEGIN {
        IGNORECASE=1
    }

    /^[a-zA-Z0-9_+-]+-[a-zA-Z0-9_+-]+-[0-9]+$/ {
        chip=$0
        next
    }

    /temp[0-9]+:/ {
        name=$1
        gsub(/:/,"",name)

        value=$2
        gsub(/[+°C]/,"",value)

        if (chip ~ /coretemp/) next
        if (chip ~ /cpu_thermal/) next

        if (value ~ /^[0-9]+(\.[0-9]+)?$/) {
            label=chip

            if (chip ~ /acpitz/) label="acpitz"
            if (chip ~ /pch_cannonlake/) label="pch_cannonlake"

            printf "  %-13s %s°C\n", label, value
        }
    }

    /Composite:/ {
        value=$2
        gsub(/[+°C]/,"",value)

        if (value ~ /^[0-9]+(\.[0-9]+)?$/)
            printf "  %-13s %s°C\n", "nvme", value
    }
    '
fi

# ─────────────────────────────────────────────
# Disk temperatures
# ─────────────────────────────────────────────

if command -v smartctl >/dev/null 2>&1; then

    for disk in /dev/sd?; do
        [ -b "$disk" ] || continue

        TEMP=$(smartctl -A "$disk" 2>/dev/null |
            awk '
                /Temperature_Celsius/ && $10 ~ /^[0-9]+$/ {
                    print $10
                    exit
                }

                /Airflow_Temperature_Cel/ && $10 ~ /^[0-9]+$/ {
                    print $10
                    exit
                }
            ')

        if [ -n "$TEMP" ]; then
            printf "  %-13s %s°C\n" "$(basename "$disk")" "$TEMP"
        fi
    done

fi

echo
