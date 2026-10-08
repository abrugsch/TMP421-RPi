#!/bin/bash

# TMP421 Temperature Sensor Reader for Raspberry Pi
# Reads internal temperature sensor from TMP421 at I2C address 0x1f
# Requires i2c-tools package: sudo apt-get install i2c-tools

# Configuration
I2C_BUS=1                  # I2C bus number (usually 1 on Raspberry Pi)
SENSOR_ADDRESS=0x1f        # TMP421 I2C address (default: 0x1f)
TEMP_REGISTER=0x00         # Internal temperature register

# Function to display usage
usage() {
    echo "Usage: $0 [OPTIONS]"
    echo "  -b, --bus BUS_NUMBER      I2C bus number (default: 1)"
    echo "  -a, --address ADDRESS     Sensor address in hex (default: 0x1f)"
    echo "  -h, --help                Display this help message"
    echo ""
    echo "Examples:"
    echo "  $0                        # Use defaults (bus 1, address 0x1f)"
    echo "  $0 -b 0                  # Use bus 0"
    echo "  $0 -a 0x3e               # Use address 0x3e"
    echo "  $0 -b 1 -a 0x3e          # Use bus 1, address 0x3e"
    exit 1
}

# Check if i2cget is available
if ! command -v i2cget &> /dev/null; then
    echo "Error: i2c-tools is not installed."
    echo "Install with: sudo apt-get install i2c-tools"
    exit 1
fi

# Parse command line arguments
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

# Read temperature from internal sensor (16-bit value, MSB first)
# i2cget with -s option specifies word read (2 bytes)
TEMP_RAW=$(i2cget -y "$I2C_BUS" "$SENSOR_ADDRESS" "$TEMP_REGISTER" w 2>/dev/null)

if [ $? -ne 0 ]; then
    echo "Error: Failed to read from TMP421 sensor at address $SENSOR_ADDRESS on bus $I2C_BUS"
    exit 1
fi

# Parse the raw temperature value
# i2cget returns value in format 0xLLHH (little-endian)
# Extract high byte (integer temperature) and low byte (fractional)
HEX_VALUE="${TEMP_RAW#0x}"  # Remove 0x prefix
HIGH_BYTE="${HEX_VALUE:2:2}" # Characters 2-3 are high byte
LOW_BYTE="${HEX_VALUE:0:2}"  # Characters 0-1 are low byte

# Convert hex to decimal
TEMP_INT=$((16#$HIGH_BYTE))
TEMP_FRAC=$((16#$LOW_BYTE))

# Handle negative temperatures (two's complement)
if [ $TEMP_INT -ge 128 ]; then
    TEMP_INT=$((TEMP_INT - 256))
fi

# Calculate fractional part (lower 8 bits represent 0-255 → 0.0-0.996°C)
# Multiply by 1000 and divide by 256 to get milli-degrees
TEMP_FRAC_CELSIUS=$((TEMP_FRAC * 1000 / 256))

# Format the final temperature with decimal places
TEMP_CELSIUS=$(printf "%d.%03d" "$TEMP_INT" "$TEMP_FRAC_CELSIUS")

# Remove trailing zeros after decimal point
TEMP_CELSIUS=$(echo "$TEMP_CELSIUS" | sed 's/\.?0*$//')

# Ensure at least one decimal place for consistency
if [[ ! "$TEMP_CELSIUS" =~ \. ]]; then
    TEMP_CELSIUS="${TEMP_CELSIUS}.0"
fi

# Output the result
echo "TMP421 Internal Temperature: $TEMP_CELSIUS°C"

# Optional: Return raw values for debugging (comment out in production)
if [ -n "$DEBUG" ]; then
    echo "  I2C Bus: $I2C_BUS"
    echo "  Address: 0x$SENSOR_ADDRESS"
    echo "  Raw Value: $TEMP_RAW"
    echo "  High Byte: 0x$HIGH_BYTE ($TEMP_INT)"
    echo "  Low Byte: 0x$LOW_BYTE ($TEMP_FRAC)"
    echo "  Fractional Celsius: 0.$TEMP_FRAC_CELSIUS"
fi

exit 0
