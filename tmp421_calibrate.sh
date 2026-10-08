#!/bin/bash

# TMP421 External Sensor Calibration Tool
# Allows calibration of the external/remote temperature sensor
# Stores calibration offset and applies it to readings

set -o pipefail

# Configuration
I2C_BUS=1
SENSOR_ADDRESS=0x1f
REMOTE_TEMP_REG=0x01
CONFIG_DIR="/var/lib/tmp421"
CALIBRATION_FILE="$CONFIG_DIR/calibration.conf"
CALIBRATION_HISTORY="$CONFIG_DIR/calibration_history.log"

# Source common functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ADVANCED_SCRIPT="$SCRIPT_DIR/tmp421_advanced.sh"

# Function to display usage
usage() {
    cat << EOF
TMP421 External Sensor Calibration Tool

USAGE:
    $0 [COMMAND] [OPTIONS]

COMMANDS:
    calibrate [REFERENCE_TEMP]  Calibrate with known reference temperature
    apply [READING]             Apply calibration to a reading
    show                        Display current calibration data
    reset                       Reset calibration to 0
    history                     Show calibration history
    validate [ITERATIONS]       Validate calibration accuracy
    help                        Display this help message

OPTIONS:
    -b, --bus BUS_NUMBER        I2C bus number (default: 1)
    -a, --address ADDRESS       Sensor address (default: 0x1f)
    -f, --force                 Force calibration without confirmation

EXAMPLES:
    # Calibrate with known reference temperature of 20.5°C
    $0 calibrate 20.5

    # Apply calibration factor to a reading
    $0 apply 22.3

    # Show current calibration
    $0 show

    # Validate calibration with 5 iterations
    $0 validate 5

    # Reset calibration
    $0 reset

EOF
    exit 0
}

# Create config directory if needed
ensure_config_dir() {
    if [ ! -d "$CONFIG_DIR" ]; then
        mkdir -p "$CONFIG_DIR" || {
            echo "Error: Cannot create config directory $CONFIG_DIR"
            exit 1
        }
    fi
}

# Initialize or load calibration file
init_calibration_file() {
    if [ ! -f "$CALIBRATION_FILE" ]; then
        cat > "$CALIBRATION_FILE" << 'EOF'
# TMP421 Calibration Configuration
# Generated automatically - do not edit manually unless you know what you're doing

CALIBRATION_OFFSET=0.0
CALIBRATION_DATE=""
CALIBRATION_REFERENCE_TEMP=""
CALIBRATION_MEASURED_TEMP=""
VALID=0

EOF
    fi
}

# Load calibration data
load_calibration() {
    if [ -f "$CALIBRATION_FILE" ]; then
        source "$CALIBRATION_FILE"
    else
        CALIBRATION_OFFSET=0.0
        CALIBRATION_DATE=""
        CALIBRATION_REFERENCE_TEMP=""
        CALIBRATION_MEASURED_TEMP=""
        VALID=0
    fi
}

# Save calibration data
save_calibration() {
    cat > "$CALIBRATION_FILE" << EOF
# TMP421 Calibration Configuration
# Generated automatically - do not edit manually unless you know what you're doing

CALIBRATION_OFFSET=$CALIBRATION_OFFSET
CALIBRATION_DATE="$CALIBRATION_DATE"
CALIBRATION_REFERENCE_TEMP="$CALIBRATION_REFERENCE_TEMP"
CALIBRATION_MEASURED_TEMP="$CALIBRATION_MEASURED_TEMP"
VALID=$VALID

EOF
}

# Read external sensor temperature
read_external_temp() {
    if [ ! -x "$ADVANCED_SCRIPT" ]; then
        echo "Error: Advanced script not found at $ADVANCED_SCRIPT"
        return 1
    fi
    
    TEMP_JSON=$("$ADVANCED_SCRIPT" -b "$I2C_BUS" -a "$SENSOR_ADDRESS" -j --remote-only 2>&1)
    
    if [ $? -ne 0 ]; then
        echo "Error: Failed to read external sensor temperature" >&2
        return 1
    fi
    
    # Extract temperature from JSON
    TEMP=$(echo "$TEMP_JSON" | grep -oE '"remote_temperature_celsius": [0-9.-]+' | grep -oE '[0-9.-]+')
    
    if [ -z "$TEMP" ]; then
        echo "Error: Could not parse temperature from sensor" >&2
        return 1
    fi
    
    echo "$TEMP"
}

# Perform calibration
calibrate() {
    local reference_temp=$1
    local force=$2
    
    if [ -z "$reference_temp" ]; then
        echo "Error: Reference temperature not provided"
        echo "Usage: $0 calibrate <REFERENCE_TEMP>"
        exit 1
    fi
    
    # Validate reference temperature format
    if ! [[ "$reference_temp" =~ ^-?[0-9]+\.?[0-9]*$ ]]; then
        echo "Error: Invalid temperature format: $reference_temp"
        echo "Use format like: 20.5 or -10"
        exit 1
    fi
    
    echo "=== TMP421 External Sensor Calibration ==="
    echo ""
    echo "Reference temperature: $reference_temp°C"
    echo ""
    echo "Reading external sensor temperature..."
    
    # Read the sensor
    MEASURED_TEMP=$(read_external_temp)
    if [ $? -ne 0 ]; then
        exit 1
    fi
    
    echo "Measured temperature: $MEASURED_TEMP°C"
    echo ""
    
    # Calculate offset
    OFFSET=$(echo "scale=3; $reference_temp - $MEASURED_TEMP" | bc)
    
    echo "Calculated calibration offset: $OFFSET°C"
    echo ""
    echo "This means:"
    echo "  - Real temperature: Measured + $OFFSET"
    echo "  - All future readings will be adjusted by $OFFSET°C"
    echo ""
    
    # Confirmation (unless forced)
    if [ "$force" != "1" ]; then
        read -p "Apply this calibration? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            echo "Calibration cancelled"
            exit 0
        fi
    fi
    
    # Save calibration
    CALIBRATION_OFFSET=$OFFSET
    CALIBRATION_DATE=$(date '+%Y-%m-%d %H:%M:%S')
    CALIBRATION_REFERENCE_TEMP=$reference_temp
    CALIBRATION_MEASURED_TEMP=$MEASURED_TEMP
    VALID=1
    
    save_calibration
    
    # Log calibration event
    cat >> "$CALIBRATION_HISTORY" << EOF
$(date '+%Y-%m-%d %H:%M:%S') | Calibration performed
  Reference: ${reference_temp}°C | Measured: ${MEASURED_TEMP}°C | Offset: ${OFFSET}°C
EOF
    
    echo ""
    echo "✓ Calibration saved successfully!"
    echo "  Offset: $OFFSET°C"
    echo "  Date: $CALIBRATION_DATE"
    echo ""
}

# Apply calibration to a reading
apply_calibration() {
    local reading=$1
    
    if [ -z "$reading" ]; then
        echo "Error: Reading temperature not provided"
        echo "Usage: $0 apply <READING>"
        exit 1
    fi
    
    load_calibration
    
    if [ -z "$CALIBRATION_OFFSET" ] || [ "$CALIBRATION_OFFSET" = "0.0" ]; then
        echo "Warning: No calibration applied (offset is 0)"
    fi
    
    # Apply offset
    CALIBRATED=$(echo "scale=3; $reading + $CALIBRATION_OFFSET" | bc)
    
    echo "Raw reading:         $reading°C"
    echo "Calibration offset:  $CALIBRATION_OFFSET°C"
    echo "Calibrated reading:  $CALIBRATED°C"
    
    # Return the calibrated value for scripting
    echo "$CALIBRATED"
}

# Show current calibration
show_calibration() {
    load_calibration
    
    echo "=== TMP421 Calibration Status ==="
    echo ""
    
    if [ "$VALID" = "1" ]; then
        echo "Status: ✓ Valid calibration active"
        echo ""
        echo "Calibration Details:"
        echo "  Offset:              $CALIBRATION_OFFSET°C"
        echo "  Calibration Date:    $CALIBRATION_DATE"
        echo "  Reference Temp:      $CALIBRATION_REFERENCE_TEMP°C"
        echo "  Measured Temp:       $CALIBRATION_MEASURED_TEMP°C"
        echo ""
        
        # Calculate accuracy
        ACCURACY=$(echo "scale=3; 100 - (($CALIBRATION_OFFSET*100)/$CALIBRATION_REFERENCE_TEMP)" | bc 2>/dev/null || echo "Unknown")
        echo "  Estimated Accuracy:  $ACCURACY%"
    else
        echo "Status: No active calibration"
        echo ""
        echo "Current offset: $CALIBRATION_OFFSET°C (default)"
        echo ""
        echo "To calibrate, run:"
        echo "  $0 calibrate <REFERENCE_TEMPERATURE>"
    fi
    
    echo ""
}

# Reset calibration
reset_calibration() {
    load_calibration
    
    read -p "Reset calibration to default (offset=0)? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Reset cancelled"
        exit 0
    fi
    
    CALIBRATION_OFFSET=0.0
    CALIBRATION_DATE=""
    CALIBRATION_REFERENCE_TEMP=""
    CALIBRATION_MEASURED_TEMP=""
    VALID=0
    
    save_calibration
    
    # Log reset event
    echo "$(date '+%Y-%m-%d %H:%M:%S') | Calibration reset to default" >> "$CALIBRATION_HISTORY"
    
    echo "✓ Calibration reset to default (offset=0)"
}

# Show calibration history
show_history() {
    if [ ! -f "$CALIBRATION_HISTORY" ]; then
        echo "No calibration history found"
        exit 0
    fi
    
    echo "=== Calibration History ==="
    echo ""
    cat "$CALIBRATION_HISTORY"
    echo ""
}

# Validate calibration accuracy
validate_calibration() {
    local iterations=${1:-5}
    
    if [ ! "$iterations" -ge 1 ]; then
        iterations=5
    fi
    
    echo "=== Calibration Validation ==="
    echo ""
    echo "Number of iterations: $iterations"
    echo "This will take approximately $((iterations * 5)) seconds..."
    echo ""
    
    load_calibration
    
    if [ -z "$CALIBRATION_REFERENCE_TEMP" ]; then
        echo "Error: No calibration reference found"
        echo "Please calibrate first: $0 calibrate <REFERENCE_TEMP>"
        exit 1
    fi
    
    echo "Using calibration reference: $CALIBRATION_REFERENCE_TEMP°C"
    echo ""
    
    local total_error=0
    local max_error=0
    local min_error=999
    
    for i in $(seq 1 "$iterations"); do
        echo -n "Reading $i/$iterations... "
        
        MEASURED=$(read_external_temp)
        if [ $? -ne 0 ]; then
            echo "FAILED"
            exit 1
        fi
        
        CALIBRATED=$(echo "scale=3; $MEASURED + $CALIBRATION_OFFSET" | bc)
        ERROR=$(echo "scale=3; ($CALIBRATED - $CALIBRATION_REFERENCE_TEMP)" | bc)
        ERROR_ABS=$(echo "$ERROR" | sed 's/-//')
        
        echo "Measured: $MEASURED°C, Calibrated: $CALIBRATED°C, Error: $ERROR°C"
        
        # Track errors
        total_error=$(echo "scale=3; $total_error + $ERROR_ABS" | bc)
        
        # Update min/max
        if (( $(echo "$ERROR_ABS > $max_error" | bc -l) )); then
            max_error=$ERROR_ABS
        fi
        if (( $(echo "$ERROR_ABS < $min_error" | bc -l) )); then
            min_error=$ERROR_ABS
        fi
        
        # Wait between readings
        if [ $i -lt "$iterations" ]; then
            sleep 5
        fi
    done
    
    echo ""
    echo "=== Validation Results ==="
    
    AVG_ERROR=$(echo "scale=3; $total_error / $iterations" | bc)
    
    echo "Reference Temperature:    $CALIBRATION_REFERENCE_TEMP°C"
    echo "Average Error:            $AVG_ERROR°C"
    echo "Maximum Error:            $max_error°C"
    echo "Minimum Error:            $min_error°C"
    echo ""
    
    if (( $(echo "$AVG_ERROR < 0.5" | bc -l) )); then
        echo "✓ Calibration is GOOD (avg error < 0.5°C)"
    elif (( $(echo "$AVG_ERROR < 1.0" | bc -l) )); then
        echo "~ Calibration is ACCEPTABLE (avg error < 1.0°C)"
    else
        echo "✗ Calibration needs adjustment (avg error >= 1.0°C)"
    fi
    
    echo ""
}

# Check dependencies
ensure_config_dir
init_calibration_file

if ! command -v bc &> /dev/null; then
    echo "Error: bc is not installed"
    echo "Install with: sudo apt-get install bc"
    exit 1
fi

# Parse arguments
COMMAND=${1:-help}
FORCE=0

case "$COMMAND" in
    calibrate)
        # Parse options for calibrate command
        shift
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
                -f|--force)
                    FORCE=1
                    shift
                    ;;
                -*)
                    echo "Unknown option: $1"
                    usage
                    ;;
                *)
                    calibrate "$1" "$FORCE"
                    exit $?
                    ;;
            esac
        done
        ;;
    apply)
        shift
        apply_calibration "$1"
        exit 0
        ;;
    show)
        show_calibration
        exit 0
        ;;
    reset)
        reset_calibration
        exit 0
        ;;
    history)
        show_history
        exit 0
        ;;
    validate)
        shift
        validate_calibration "$1"
        exit 0
        ;;
    help|--help|-h)
        usage
        ;;
    *)
        echo "Unknown command: $COMMAND"
        echo ""
        usage
        ;;
esac

exit 0
