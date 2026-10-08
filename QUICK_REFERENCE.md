# TMP421 Quick Reference Card

## Installation (2 minutes)

```bash
sudo apt-get update
sudo apt-get install -y i2c-tools bc
sudo raspi-config  # Enable I2C: Interface Options → I2C
git clone <repo> ~/tmp421_scripts
cd ~/tmp421_scripts && chmod +x *.sh
sudo ./tmp421_diagnose.sh  # Verify setup
```

## Quick Commands

| Task | Command |
|------|---------|
| Read temperature now | `./tmp421_read.sh` |
| Read, show debug info | `DEBUG=1 ./tmp421_read.sh` |
| Read in Fahrenheit | `./tmp421_advanced.sh -f fahrenheit` |
| JSON output | `./tmp421_advanced.sh -j` |
| Log readings | `./tmp421_advanced.sh -l` |
| Continuous monitor | `./tmp421_monitor.sh` || Calibrate sensor | `./tmp421_calibrate.sh calibrate 20.5` |
| Show calibration | `./tmp421_calibrate.sh show` |
| Validate calibration | `./tmp421_calibrate.sh validate 10` || Diagnose issues | `sudo ./tmp421_diagnose.sh` |

## Script Descriptions

- **tmp421_read.sh** - Simple, one-shot temperature reader
- **tmp421_advanced.sh** - Feature-rich reader with format conversion & calibration support
- **tmp421_calibrate.sh** - Sensor calibration and validation
- **tmp421_monitor.sh** - Background monitoring with history
- **tmp421_diagnose.sh** - Troubleshooting and diagnostics

## I2C Bus Info

- **Default Bus**: 1 (most Raspberry Pi models)
- **Default Address**: 0x1f (configurable)
- **GPIO Pins**: SCL=GPIO3, SDA=GPIO2
- **Verify**: `i2cdetect -y 1` (should show your device address)

## Temperature Output

- **Internal sensor register**: 0x00
- **16-bit format**: Integer (MSB) + Fractional (LSB)
- **Range**: -128 to +127°C
- **Precision**: ~0.004°C

## Examples

### Single temperature read:
```bash
./tmp421_read.sh
# Output: TMP421 Internal Temperature: 25.3°C
```

### Continuous logging:
```bash
./tmp421_advanced.sh -j -l
```

### Monitor with service:
```bash
sudo cp tmp421_monitor.service /etc/systemd/system/
sudo systemctl enable tmp421_monitor.service
sudo systemctl start tmp421_monitor.service
sudo systemctl status tmp421_monitor.service
```

### View history:
```bash
cat /var/lib/tmp421/temperature_history.log | jq '.internal_temperature_celsius'
```

## Troubleshooting

| Problem | Fix |
|---------|-----|
| I2C not found | `sudo raspi-config` → Enable I2C → Reboot |
| Sensor not detected | Check wiring, run `i2cdetect -y 1` |
| Permission denied | Run with `sudo` or add user to i2c group |
| Wrong temperature | Verify address 0x1f, check sensor wiring |
| Can't read register | Try: `sudo i2cget -y 1 0x1f 0x00 w` |

## Cron Examples

```bash
crontab -e

# Read temperature every 5 minutes
*/5 * * * * /home/pi/tmp421_scripts/tmp421_advanced.sh -j -l >> /tmp/tmp421.log 2>&1

# Read hourly
0 * * * * /home/pi/tmp421_scripts/tmp421_read.sh >> /var/log/tmp421_hourly.log 2>&1
```

## Calibration Quick Start

```bash
# Calibrate external sensor against known reference
./tmp421_calibrate.sh calibrate 20.5

# Use calibration in readings
./tmp421_advanced.sh -r --calibrated

# See extensive guide: CALIBRATION.md
```

## Useful Links

- TMP421 Datasheet: https://www.ti.com/product/TMP421
- i2c-tools: https://i2c.wiki.kernel.org/index.php/I2CTools
- Raspberry Pi I2C: https://www.raspberrypi.org/documentation
- Detailed Calibration Guide: [CALIBRATION.md](CALIBRATION.md)

---
**Default Address**: 0x1f (configurable with -a flag) | **Default Bus**: 1 | **GPIO**: SDA=2, SCL=3

