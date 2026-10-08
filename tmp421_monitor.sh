#!/bin/bash

# TMP421 Continuous Temperature Monitor
# Reads temperature at regular intervals and maintains a history
# Requires: tmp421_advanced.sh in the same directory

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ADVANCED_SCRIPT="$SCRIPT_DIR/tmp421_advanced.sh"
HISTORY_FILE="/var/lib/tmp421/temperature_history.log"
STATS_FILE="/var/lib/tmp421/temperature_stats.txt"
DATA_DIR="/var/lib/tmp421"

# Configuration
INTERVAL=60       # Read every 60 seconds
I2C_BUS=1         # I2C bus number
SENSOR_ADDRESS=0x1f  # TMP421 I2C address
FORMAT="celsius"  # Output format

# Parse command line arguments
while [ $# -gt 0 ]; do
    case "$1" in
        -i|--interval)
            INTERVAL="$2"
            shift 2
            ;;
        -b|--bus)
            I2C_BUS="$2"
            shift 2
            ;;
        -a|--address)
            SENSOR_ADDRESS="$2"
            shift 2
            ;;
        -f|--format)
            FORMAT="$2"
            shift 2
            ;;
        -h|--help)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "OPTIONS:"
            echo "  -i, --interval SECONDS    Interval between readings (default: 60)"
            echo "  -b, --bus BUS_NUMBER      I2C bus number (default: 1)"
            echo "  -a, --address ADDRESS     Sensor address in hex (default: 0x1f)"
            echo "  -f, --format FORMAT       Output format: celsius, fahrenheit (default: celsius)"
            echo "  -h, --help                Display this help message"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Check if advanced script exists
if [ ! -x "$ADVANCED_SCRIPT" ]; then
    echo "Error: $ADVANCED_SCRIPT not found or not executable"
    exit 1
fi

# Create data directory
if [ ! -d "$DATA_DIR" ]; then
    mkdir -p "$DATA_DIR" || {
        echo "Error: Cannot create $DATA_DIR"
        exit 1
    }
fi

# Function to calculate statistics
calculate_stats() {
    if [ ! -f "$HISTORY_FILE" ]; then
        return
    fi
    
    # Extract temperature values from JSON logs
    local temps=$(grep "internal_temperature_celsius" "$HISTORY_FILE" | \
                 grep -oE '"internal_temperature_celsius": [0-9.]+' | \
                 grep -oE '[0-9.]+')
    
    if [ -z "$temps" ]; then
        return
    fi
    
    local count=$(echo "$temps" | wc -l)
    local min=$(echo "$temps" | sort -n | head -1)
    local max=$(echo "$temps" | sort -n | tail -1)
    local avg=$(echo "$temps" | awk '{sum+=$1} END {print sum/NR}')
    
    cat > "$STATS_FILE" << EOF
Temperature Statistics (Last 100 readings)
============================================
Count:     $count
Minimum:   ${min}°C
Maximum:   ${max}°C
Average:   $(printf "%.2f" $avg)°C
Last Updated: $(date)
EOF
}

# Main monitoring loop
echo "TMP421 Temperature Monitor Started"
echo "Interval: ${INTERVAL}s, Bus: $I2C_BUS, Format: $FORMAT"
echo "Data directory: $DATA_DIR"
echo "Press Ctrl+C to stop"
echo ""

# Trap Ctrl+C to gracefully exit
trap 'echo ""; echo "Monitor stopped"; calculate_stats; exit 0' INT

while true; do
    TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
    
    # Read temperature
    RESULT=$("$ADVANCED_SCRIPT" -b "$I2C_BUS" -a "$SENSOR_ADDRESS" -f "$FORMAT" -j 2>&1)
    
    if [ $? -eq 0 ]; then
        # Add timestamp to JSON output
        JSON_WITH_TS=$(echo "$RESULT" | sed 's/"timestamp":/"read_timestamp":/' | \
                       sed 's/}/, "system_timestamp": "'$TIMESTAMP'"}/')
        
        echo "$JSON_WITH_TS" >> "$HISTORY_FILE"
        echo "[$TIMESTAMP] Temperature recorded successfully"
        
        # Calculate and display current temperature
        INTERNAL=$(echo "$RESULT" | grep -oE '"internal_temperature_celsius": [0-9.]+' | grep -oE '[0-9.]+')
        if [ -n "$INTERNAL" ]; then
            case "$FORMAT" in
                fahrenheit) UNIT="°F" ;;
                kelvin) UNIT="K" ;;
                *) UNIT="°C" ;;
            esac
            echo "  Current temperature: $INTERNAL$UNIT"
        fi
    else
        echo "[$TIMESTAMP] ERROR: Failed to read temperature"
    fi
    
    # Keep only last 100 entries in history file
    if [ -f "$HISTORY_FILE" ]; then
        LINES=$(wc -l < "$HISTORY_FILE")
        if [ "$LINES" -gt 100 ]; then
            tail -100 "$HISTORY_FILE" > "$HISTORY_FILE.tmp"
            mv "$HISTORY_FILE.tmp" "$HISTORY_FILE"
        fi
    fi
    
    sleep "$INTERVAL"
done
