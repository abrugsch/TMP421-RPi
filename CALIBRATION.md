# TMP421 Sensor Calibration Guide

## Overview

The TMP421 has an internal and external (remote) temperature sensor. The external sensor can be calibrated to improve accuracy by comparing it against a known reference temperature. This calibration script allows you to:

- **Calibrate** the external sensor against a known reference temperature
- **Apply** the calibration offset to readings
- **Validate** calibration accuracy
- **View** calibration history
- **Reset** to factory defaults

## When to Calibrate

Calibration is recommended when:
- The external sensor readings are consistently offset from actual temperature
- You have access to a precise reference temperature (accurate thermometer, temperature bath, etc.)
- You want to improve measurement accuracy beyond factory specifications

## Calibration Process

### Step 1: Prepare Reference Temperature

Get an accurate reference temperature. Options:
- **Thermometer**: Use a calibrated digital thermometer placed next to the sensor
- **Temperature bath**: Submerge both sensors in a water bath at known temperature
- **Ice bath**: Use ice-water mixture (approximately 0°C) or boiling water (100°C)
- **Controlled environment**: Use an environmental chamber with precise temperature control

### Step 2: Run Calibration

```bash
./tmp421_calibrate.sh calibrate <REFERENCE_TEMPERATURE>
```

Example:
```bash
# If your reference thermometer reads 20.5°C
./tmp421_calibrate.sh calibrate 20.5
```

The script will:
1. Display the reference temperature you provided
2. Read the current external sensor value
3. Calculate the calibration offset (difference between reference and measured)
4. Ask for confirmation
5. Save the calibration data

### Step 3: Verify Calibration

```bash
# Show calibration status
./tmp421_calibrate.sh show

# Validate with multiple readings
./tmp421_calibrate.sh validate 10
```

## Usage Examples

### Basic Calibration

```bash
# Calibrate with 25°C reference
./tmp421_calibrate.sh calibrate 25.0

# Force calibration without confirmation
./tmp421_calibrate.sh calibrate 25.0 --force
```

### View Calibration

```bash
# Show current calibration details
./tmp421_calibrate.sh show

# View all past calibrations
./tmp421_calibrate.sh history
```

### Validate Calibration

```bash
# Perform 5 readings to validate accuracy
./tmp421_calibrate.sh validate 5

# Use 10 readings for more thorough validation
./tmp421_calibrate.sh validate 10
```

### Reset Calibration

```bash
# Reset to factory default (offset = 0)
./tmp421_calibrate.sh reset
```

### Calibrate on I2C Bus or with Different Address

```bash
# Calibrate on I2C bus 0
./tmp421_calibrate.sh calibrate 25.0 --bus 0

# Use different sensor address (if not default 0x1f)
./tmp421_calibrate.sh calibrate 25.0 --address 0x1f

# Combine both options
./tmp421_calibrate.sh calibrate 25.0 --bus 0 --address 0x1f
```

### Apply Calibration in Advanced Script

```bash
# Read remote sensor with calibration applied
./tmp421_advanced.sh --remote-only --calibrated

# JSON output with calibration
./tmp421_advanced.sh --remote-only --calibrated --json

# Log with calibration
./tmp421_advanced.sh --remote-only --calibrated --log
```

## Understanding Calibration Offset

The calibration offset is the difference between the reference temperature and the measured temperature:

```
Offset = Reference Temperature - Measured Temperature
```

### Examples

**Scenario 1: Sensor reads low**
```
Reference: 20.0°C
Measured:  19.5°C
Offset:    +0.5°C (positive)
```
All future readings will be +0.5°C higher.

**Scenario 2: Sensor reads high**
```
Reference: 20.0°C
Measured:  20.7°C
Offset:    -0.7°C (negative)
```
All future readings will be 0.7°C lower.

## Output Examples

### Show Calibration Status

```
=== TMP421 Calibration Status ===

Status: ✓ Valid calibration active

Calibration Details:
  Offset:              +0.5°C
  Calibration Date:    2026-06-09 14:30:15
  Reference Temp:      20.5°C
  Measured Temp:       20.0°C
  Estimated Accuracy:  97.56%
```

### Validate Results

```
=== Validation Results ===
Reference Temperature:    20.5°C
Average Error:            0.12°C
Maximum Error:            0.35°C
Minimum Error:            0.02°C

✓ Calibration is GOOD (avg error < 0.5°C)
```

## Configuration Files

### Calibration File
Location: `/var/lib/tmp421/calibration.conf`

Contains:
- `CALIBRATION_OFFSET`: The calculated offset in °C
- `CALIBRATION_DATE`: When calibration was performed
- `CALIBRATION_REFERENCE_TEMP`: Reference temperature used
- `CALIBRATION_MEASURED_TEMP`: Temperature measured during calibration
- `VALID`: Whether calibration is active (0 or 1)

### Calibration History
Location: `/var/lib/tmp421/calibration_history.log`

Log of all calibration operations with timestamps and details.

## Best Practices

### For Accurate Calibration

1. **Wait for thermal equilibrium**: Allow 5-10 minutes for sensor and reference to reach same temperature
2. **Multiple readings**: Use `validate` command to check consistency
3. **Stable environment**: Minimize heat sources and air currents during calibration
4. **Close to operating point**: Calibrate near the temperature range where you'll use the sensor
5. **Reference accuracy**: Use a calibrated reference (±0.5°C or better)

### Calibration Strategy

**Single-point calibration** (what this script does):
- Calibrates at one temperature point
- Good for typical operating range
- Takes ~30 seconds

**Multi-point calibration** (manual process):
- Calibrate at multiple temperatures (e.g., 0°C, 20°C, 50°C)
- Better for wide temperature ranges
- More time-consuming

### Maintenance

- Recalibrate annually or if accuracy degrades
- Recalibrate after sensor replacement
- Keep calibration history for audit purposes
- Document reference temperature source and accuracy

## Troubleshooting

### Issue: "Cannot read external sensor"

**Solution:**
1. Verify remote sensor is connected and powered
2. Run diagnostics: `sudo ./tmp421_diagnose.sh`
3. Check I2C bus: `i2cdetect -y 1`

### Issue: "Calibration offset seems too large"

**Possible causes:**
- Reference temperature is incorrect (typo)
- Remote sensor is not reading (reads 0 or 127°C)
- Sensor is not in thermal equilibrium with reference

**Solution:**
- Verify reference temperature
- Wait for thermal equilibrium (5-10 minutes)
- Run `validate` command to test accuracy
- Try calibration again

### Issue: "Validation shows large errors"

**Possible causes:**
- Sensor drift/instability
- Reference temperature has changed
- Environmental temperature fluctuations

**Solution:**
- Stabilize environment (eliminate heat sources)
- Recalibrate at current temperature
- Use sensor after warm-up period (5 minutes)

### Issue: "Permission denied" when using calibration

**Solution:**
```bash
# Run with sudo
sudo ./tmp421_calibrate.sh calibrate 25.0

# Or add user to i2c group
sudo usermod -aG i2c pi
```

## API for Scripts

Use calibration in your own scripts:

```bash
# Load calibration
source /var/lib/tmp421/calibration.conf

# Apply to custom reading
MEASURED=22.3
CALIBRATED=$(echo "scale=3; $MEASURED + $CALIBRATION_OFFSET" | bc)
echo "Calibrated: $CALIBRATED°C"
```

## Advanced: Manual Calibration Adjustment

If needed, edit `/var/lib/tmp421/calibration.conf` directly:

```bash
sudo nano /var/lib/tmp421/calibration.conf

# Change CALIBRATION_OFFSET to desired value
CALIBRATION_OFFSET=0.25
```

## Technical Details

### Temperature Calculation

The script applies calibration using simple arithmetic:

```
Calibrated_Temperature = Measured_Temperature + Calibration_Offset
```

### Data Storage

All calibration data is stored in plain text files:
- `/var/lib/tmp421/calibration.conf` - Current calibration
- `/var/lib/tmp421/calibration_history.log` - Historical records

### Integration with Advanced Script

The advanced script supports calibration via `-c` or `--calibrated` flag:

```bash
./tmp421_advanced.sh -r -c  # Remote temp with calibration
```

## Reference

### Calibration Accuracy Levels

| Average Error | Quality |
|---------------|---------|
| < 0.1°C | Excellent |
| < 0.5°C | Good |
| < 1.0°C | Acceptable |
| > 1.0°C | Poor - recalibrate |

### TMP421 Specifications

- **Temperature Range**: -40 to +125°C
- **Accuracy (factory)**: ±1°C typical
- **Resolution**: ~0.004°C (12-bit)
- **Remote Sensor Accuracy**: ±2°C typical

---

For more information, see:
- [README.md](README.md) - General usage
- [SETUP.md](SETUP.md) - Setup instructions
- [QUICK_REFERENCE.md](QUICK_REFERENCE.md) - Quick commands

