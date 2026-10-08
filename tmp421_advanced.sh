#!/bin/bash

# TMP421 Advanced Temperature Reader
# Reads both internal and remote temperature sensors (if available)
# Supports data logging and formatting options

set -o pipefail

# Default configuration
I2C_BUS=1
SENSOR_ADDRESS=0x1f
INTERNAL_TEMP_REG=0x00
REMOTE_TEMP_REG=0x01
OUTPUT_FORMAT="celsius"  # celsius, fahrenheit, kelvin
ENABLE_LOGGING=0
LOG_FILE="/var/log/tmp421_temperatures.log"
APPLY_CALIBRATION=0
CALIBRATION_FILE="/var/lib/tmp421/calibration.conf"

# Function to display usage
usage() {
    cat << EOF
Usage: $0 [OPTIONS]

OPTIONS:
    -b, --bus BUS_NUMBER        I2C bus number (default: 1)
    -a, --address ADDRESS       Sensor address in hex (default: 0x1f)
    -f, --format FORMAT         Output format: celsius, fahrenheit, kelvin (default: celsius)
    -l, --log                   Enable logging to $LOG_FILE
    -i, --internal-only         Read only internal temperature
    -r, --remote-only           Read only remote temperature
    -j, --json                  Output in JSON format
    -c, --calibrated            Apply calibration offset to remote temperature
    -d, --debug                 Enable debug output
    -h, --help                  Display this help message

EXAMPLES:
    $0                          # Read both temperatures in Celsius
    $0 -f fahrenheit            # Read both temperatures in Fahrenheit
    $0 --internal-only -f       # Read internal temperature only
    $0 --json -l                # Output JSON and log the result
    $0 --remote-only -c         # Read remote temp with calibration applied

EOF
    exit 1
}

# Logging function
log_result() {
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] $1" | tee -a "$LOG_FILE"
}

# Load calibration offset if available
load_calibration() {
    if [ -f "$CALIBRATION_FILE" ]; then
        source "$CALIBRATION_FILE" 2>/dev/null
        if [ -z "$CALIBRATION_OFFSET" ]; then
            CALIBRATION_OFFSET=0.0
        fi
    else
        CALIBRATION_OFFSET=0.0
    fi
}

# Temperature conversion functions
celsius_to_fahrenheit() {
    echo "scale=3; ($1 * 9/5) + 32" | bc
}

celsius_to_kelvin() {
    echo "scale=3; $1 + 273.15" | bc
}

# Read temperature from register
read_temperature() {
    local register=$1
    local register_name=$2
    
    TEMP_RAW=$(i2cget -y "$I2C_BUS" "$SENSOR_ADDRESS" "$register" w 2>/dev/null)
    
    if [ $? -ne 0 ]; then
        echo "ERROR: Failed to read $register_name from address 0x$SENSOR_ADDRESS on bus $I2C_BUS" >&2
        return 1
    fi
    
    # Parse the 16-bit value (little-endian)
    HEX_VALUE="${TEMP_RAW#0x}"
    HIGH_BYTE="${HEX_VALUE:2:2}"
    LOW_BYTE="${HEX_VALUE:0:2}"
    
    # Convert hex to decimal
    TEMP_INT=$((16#$HIGH_BYTE))
    TEMP_FRAC=$((16#$LOW_BYTE))
    
    # Handle negative temperatures (two's complement)
    if [ $TEMP_INT -ge 128 ]; then
        TEMP_INT=$((TEMP_INT - 256))
    fi
    
    # Calculate fractional part
    TEMP_FRAC_CELSIUS=$((TEMP_FRAC * 1000 / 256))
    
    # Format temperature
    TEMP_CELSIUS=$(printf "%d.%03d" "$TEMP_INT" "$TEMP_FRAC_CELSIUS")
    
    # Remove trailing zeros
    TEMP_CELSIUS=$(echo "$TEMP_CELSIUS" | sed 's/\.?0*$//')
    
    if [[ ! "$TEMP_CELSIUS" =~ \. ]]; then
        TEMP_CELSIUS="${TEMP_CELSIUS}.0"
    fi
    
    # Apply calibration if enabled and this is the remote sensor
    if [ "$APPLY_CALIBRATION" = "1" ] && [ "$register" = "$REMOTE_TEMP_REG" ]; then
        if command -v bc &> /dev/null; then
            TEMP_CELSIUS=$(echo "scale=3; $TEMP_CELSIUS + $CALIBRATION_OFFSET" | bc)
            # Remove trailing zeros again after calibration
            TEMP_CELSIUS=$(echo "$TEMP_CELSIUS" | sed 's/\.?0*$//')
            if [[ ! "$TEMP_CELSIUS" =~ \. ]]; then
                TEMP_CELSIUS="${TEMP_CELSIUS}.0"
            fi
        fi
    fi
    
    echo "$TEMP_CELSIUS"
}

# Check dependencies
if ! command -v i2cget &> /dev/null; then
    echo "Error: i2c-tools is not installed."
    echo "Install with: sudo apt-get install i2c-tools"
    exit 1
fi

# Parse arguments
READ_INTERNAL=1
READ_REMOTE=1

while [ $# -gt 0 ]; do
    case "$1" in
        -b|--bus)
            I2C_BUS="$2"
            shift 2
            ;;
        -a|--address)
            SENSOR_ADDRESS="$2"
            shift 2
            ;;
        -f|--format)
            OUTPUT_FORMAT="$2"
            shift 2
            ;;
        -l|--log)
            ENABLE_LOGGING=1
            shift
            ;;
        -i|--internal-only)
            READ_INTERNAL=1
            READ_REMOTE=0
            shift
            ;;
        -r|--remote-only)
            READ_INTERNAL=0
            READ_REMOTE=1
            shift
            ;;
        -j|--json)
            OUTPUT_FORMAT="json"
            shift
            ;;
        -c|--calibrated)
            APPLY_CALIBRATION=1
            shift
            ;;
        -d|--debug)
            DEBUG=1
            shift
            ;;
        -h|--help)
            usage
            ;;
        *)
            echo "Unknown option: $1"
            usage
            ;;
    esac
done

# Validate I2C bus exists
if [ ! -e /dev/i2c-"$I2C_BUS" ]; then
    echo "Error: I2C bus $I2C_BUS not found. Available buses:"
    ls -la /dev/i2c-* 2>/dev/null || echo "  None found"
    exit 1
fi

# Load calibration if needed
if [ "$APPLY_CALIBRATION" = "1" ]; then
    load_calibration
fi

# Create log file directory if needed
if [ $ENABLE_LOGGING -eq 1 ] && [ ! -d "$(dirname "$LOG_FILE")" ]; then
    mkdir -p "$(dirname "$LOG_FILE")" || {
        echo "Error: Cannot create log directory"
        exit 1
    }
fi

# Read temperatures
INTERNAL_TEMP=""
REMOTE_TEMP=""

if [ $READ_INTERNAL -eq 1 ]; then
    INTERNAL_TEMP=$(read_temperature "$INTERNAL_TEMP_REG" "Internal Temperature")
    [ $? -eq 0 ] || exit 1
fi

if [ $READ_REMOTE -eq 1 ]; then
    REMOTE_TEMP=$(read_temperature "$REMOTE_TEMP_REG" "Remote Temperature")
    [ $? -eq 0 ] || exit 1
fi

# Convert temperatures if needed
if [ "$OUTPUT_FORMAT" != "celsius" ] && [ "$OUTPUT_FORMAT" != "json" ]; then
    if [ -n "$INTERNAL_TEMP" ]; then
        case "$OUTPUT_FORMAT" in
            fahrenheit)
                INTERNAL_TEMP=$(celsius_to_fahrenheit "$INTERNAL_TEMP")
                ;;
            kelvin)
                INTERNAL_TEMP=$(celsius_to_kelvin "$INTERNAL_TEMP")
                ;;
        esac
    fi
    
    if [ -n "$REMOTE_TEMP" ]; then
        case "$OUTPUT_FORMAT" in
            fahrenheit)
                REMOTE_TEMP=$(celsius_to_fahrenheit "$REMOTE_TEMP")
                ;;
            kelvin)
                REMOTE_TEMP=$(celsius_to_kelvin "$REMOTE_TEMP")
                ;;
        esac
    fi
fi

# Output results
if [ "$OUTPUT_FORMAT" = "json" ]; then
    JSON_OUTPUT="{"
    [ -n "$INTERNAL_TEMP" ] && JSON_OUTPUT="$JSON_OUTPUT \"internal_temperature_celsius\": $INTERNAL_TEMP"
    if [ -n "$REMOTE_TEMP" ]; then
        [ -n "$INTERNAL_TEMP" ] && JSON_OUTPUT="$JSON_OUTPUT,"
        JSON_OUTPUT="$JSON_OUTPUT \"remote_temperature_celsius\": $REMOTE_TEMP"
    fi
    JSON_OUTPUT="$JSON_OUTPUT, \"timestamp\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\"}"
    echo "$JSON_OUTPUT"
    
    if [ $ENABLE_LOGGING -eq 1 ]; then
        log_result "$JSON_OUTPUT"
    fi
else
    OUTPUT=""
    UNIT_SUFFIX="°C"
    
    case "$OUTPUT_FORMAT" in
        fahrenheit)
            UNIT_SUFFIX="°F"
            ;;
        kelvin)
            UNIT_SUFFIX="K"
            ;;
    esac
    
    if [ -n "$INTERNAL_TEMP" ]; then
        OUTPUT="Internal: $INTERNAL_TEMP$UNIT_SUFFIX"
    fi
    
    if [ -n "$REMOTE_TEMP" ]; then
        [ -n "$OUTPUT" ] && OUTPUT="$OUTPUT, "
        OUTPUT="${OUTPUT}Remote: $REMOTE_TEMP$UNIT_SUFFIX"
    fi
    
    echo "TMP421 Temperature - $OUTPUT"
    
    if [ $ENABLE_LOGGING -eq 1 ]; then
        log_result "$OUTPUT"
    fi
fi

# Debug output
if [ -n "$DEBUG" ]; then
    echo ""
    echo "=== Debug Information ==="
    echo "I2C Bus: $I2C_BUS"
    echo "Sensor Address: 0x$SENSOR_ADDRESS"
    echo "Output Format: $OUTPUT_FORMAT"
    echo "Logging Enabled: $ENABLE_LOGGING"
    echo "Calibration Applied: $APPLY_CALIBRATION"
    if [ "$APPLY_CALIBRATION" = "1" ]; then
        echo "Calibration Offset: $CALIBRATION_OFFSET°C"
    fi
fi

exit 0
