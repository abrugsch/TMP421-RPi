# TMP421 Temperature Sensor Script for Raspberry Pi OS Trixie

This script reads the internal temperature from a TMP421 temperature sensor connected to a Raspberry Pi via I2C.

## Hardware Setup

- **Sensor**: TMP421 Temperature Sensor
- **Address**: 0x1f (configurable)
- **I2C Bus**: Usually bus 1 on Raspberry Pi
- **Connection**: SCL and SDA pins

### Wiring (Raspberry Pi 4/5):
- TMP421 VDD → Raspberry Pi 3.3V
- TMP421 GND → Raspberry Pi GND
- TMP421 SCL → Raspberry Pi GPIO 3 (BCM 3 / SCL)
- TMP421 SDA → Raspberry Pi GPIO 2 (BCM 2 / SDA)

## Prerequisites

1. Enable I2C on Raspberry Pi:
   ```bash
   sudo raspi-config
   # Navigate to: Interface Options → I2C → Enable
   ```

2. Install i2c-tools:
   ```bash
   sudo apt-get update
   sudo apt-get install i2c-tools
   ```

3. Verify sensor is detected:
   ```bash
   i2cdetect -y 1
   # Should show 3e in the output
   ```

## Usage

### Basic Usage
```bash
chmod +x tmp421_read.sh
./tmp421_read.sh
```

### Specify I2C Bus and/or Address
```bash
./tmp421_read.sh -b 1 -a 0x3e   # Bus 1, address 0x3e
./tmp421_read.sh -b 0           # Bus 0 (default address 0x1f)
./tmp421_read.sh -a 0x3e        # Default bus 1, address 0x3e
```

### Run with Debug Output
```bash
DEBUG=1 ./tmp421_read.sh
```

## Output

```
TMP421 Internal Temperature: 25.5°C
```

## Creating a Cron Job for Periodic Readings

To read the temperature every 5 minutes and log it:

```bash
crontab -e
```

Add the line:
```
*/5 * * * * /home/pi/tmp421_read.sh >> /var/log/tmp421_temp.log 2>&1
```
## Advanced Mode

Use `tmp421_advanced.sh` for additional features:

- Read internal or remote sensor
- Apply calibration to remote readings
- Output in Celsius, Fahrenheit, or Kelvin
- JSON output
- Logging support

```bash
./tmp421_advanced.sh --help
./tmp421_advanced.sh -r -c
./tmp421_advanced.sh -r -c --json
./tmp421_advanced.sh -r -c --log
./tmp421_advanced.sh -r -c -F
```

## Service Mode

A systemd service is available for background monitoring:

```bash
sudo cp tmp421_monitor.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable --now tmp421_monitor.service
sudo systemctl status tmp421_monitor.service
```

## Troubleshooting

### "I2C bus not found"
- Check if I2C is enabled: `i2cdetect -y 1`
- Try different bus numbers (usually 0 or 1)

### "Failed to read from TMP421 sensor"
- Verify sensor address: `i2cdetect -y 1` (should show 3e)
- Check I2C is enabled and wiring is correct
- Try reading manually: `i2cget -y 1 0x3e 0x00 w`

### "i2c-tools is not installed"
- Run: `sudo apt-get install i2c-tools`

## Temperature Register Information (TMP421)

- **Register 0x00**: Internal Temperature (16-bit)
- **Register 0x01**: Remote Temperature (optional, not read by this script)
- **Default Address**: 0x1f
- **Format**: MSB is integer temperature (°C), LSB is fractional part (0-255 → 0.0-0.996°C)

## Notes

- The script handles negative temperatures (two's complement)
- Fractional temperature is calculated to 0.001°C precision
- May require root/sudo privileges to access /dev/i2c devices
