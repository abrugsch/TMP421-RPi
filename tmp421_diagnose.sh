#!/bin/bash

# TMP421 I2C Diagnostics Tool
# Helps troubleshoot I2C communication with the TMP421 sensor

echo "=== TMP421 I2C Diagnostic Tool ==="
echo ""

# Check if i2c-tools is installed
if ! command -v i2cdetect &> /dev/null; then
    echo "❌ ERROR: i2c-tools is not installed"
    echo "   Install with: sudo apt-get install i2c-tools"
    exit 1
fi
echo "✓ i2c-tools is installed"

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo "⚠ WARNING: Not running as root. Some I2C operations may fail."
    echo "  Run with: sudo $0"
    echo ""
fi

# List available I2C buses
echo ""
echo "=== Available I2C Buses ==="
if ls /dev/i2c-* &> /dev/null; then
    ls -la /dev/i2c-*
else
    echo "❌ No I2C buses found"
    echo "   Is I2C enabled? Run: raspi-config → Interface Options → I2C"
    exit 1
fi

# Scan for TMP421 sensor (default address 0x1f)
echo ""
echo "=== Scanning for TMP421 at address 0x1f ==="

for bus in /dev/i2c-*; do
    BUS_NUM=$(echo "$bus" | grep -oE '[0-9]+$')
    
    if i2cdetect -y "$BUS_NUM" 2>/dev/null | grep -q "1f"; then
        echo "✓ FOUND: TMP421 at address 0x1f on bus $BUS_NUM"
        FOUND_BUS=$BUS_NUM
    fi
done

if [ -z "$FOUND_BUS" ]; then
    echo "❌ No TMP421 sensor found at address 0x1f"
    echo ""
    echo "Full I2C bus scan:"
    for bus in /dev/i2c-*; do
        BUS_NUM=$(echo "$bus" | grep -oE '[0-9]+$')
        echo ""
        echo "Bus $BUS_NUM:"
        i2cdetect -y "$BUS_NUM" 2>/dev/null || echo "Unable to scan bus $BUS_NUM"
    done
    exit 1
fi

# Try to read temperature
echo ""
echo "=== Reading Temperature from Bus $FOUND_BUS ==="

TEMP_RAW=$(i2cget -y "$FOUND_BUS" 0x1f 0x00 w 2>/dev/null)

if [ $? -eq 0 ]; then
    echo "✓ Successfully read from sensor"
    echo "  Raw value (16-bit): $TEMP_RAW"
    
    # Parse the value
    HEX_VALUE="${TEMP_RAW#0x}"
    HIGH_BYTE="${HEX_VALUE:2:2}"
    LOW_BYTE="${HEX_VALUE:0:2}"
    
    echo "  High byte (integer temp): 0x$HIGH_BYTE"
    echo "  Low byte (fractional):    0x$LOW_BYTE"
    
    # Convert to decimal and calculate temperature
    TEMP_INT=$((16#$HIGH_BYTE))
    TEMP_FRAC=$((16#$LOW_BYTE))
    
    if [ $TEMP_INT -ge 128 ]; then
        TEMP_INT=$((TEMP_INT - 256))
    fi
    
    TEMP_FRAC_CELSIUS=$((TEMP_FRAC * 1000 / 256))
    TEMP_CELSIUS=$(printf "%d.%03d" "$TEMP_INT" "$TEMP_FRAC_CELSIUS")
    TEMP_CELSIUS=$(echo "$TEMP_CELSIUS" | sed 's/\.?0*$//')
    
    echo "  Calculated temperature: $TEMP_CELSIUS°C"
else
    echo "❌ Failed to read from sensor"
    exit 1
fi

# Additional diagnostic info
echo ""
echo "=== System Information ==="
echo "Hostname: $(hostname)"
echo "OS: $(cat /etc/os-release 2>/dev/null | grep PRETTY_NAME | cut -d'"' -f2)"
echo "Kernel: $(uname -r)"
echo "Python: $(python3 --version 2>&1)"

# Check for I2C kernel modules
echo ""
echo "=== I2C Kernel Modules ==="
lsmod | grep -E "i2c|bcm" || echo "No I2C modules loaded"

# Check GPIO status (if available)
echo ""
echo "=== GPIO Status (if available) ==="
if command -v raspi-gpio &> /dev/null; then
    raspi-gpio get 2,3 2>/dev/null || echo "Unable to check GPIO status"
else
    echo "raspi-gpio not available"
fi

echo ""
echo "=== Diagnostics Complete ==="
