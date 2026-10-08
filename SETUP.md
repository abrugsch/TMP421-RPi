# TMP421 Temperature Sensor for Raspberry Pi OS Trixie - Complete Setup Guide

This package contains everything needed to read temperature from a TMP421 sensor on a Raspberry Pi.

## 📋 Quick Start

### 1. Prerequisites
- Raspberry Pi running Raspberry Pi OS Trixie
- TMP421 temperature sensor (I2C address configurable, default 0x1f)
- I2C pins accessible (GPIO 2 for SDA, GPIO 3 for SCL)

### 2. Installation

#### Install i2c-tools and dependencies:
```bash
sudo apt-get update
sudo apt-get install -y i2c-tools bc
```

#### Enable I2C interface:
```bash
sudo raspi-config
# Navigate to: Interface Options → I2C → Yes
# Reboot when prompted
```

#### Copy scripts to your Raspberry Pi:
```bash
# Option A: Using git (if available)
git clone <repository> ~/tmp421_scripts
cd ~/tmp421_scripts

# Option B: Manual copy
mkdir -p ~/tmp421_scripts
# Copy all .sh files to this directory
```

#### Make scripts executable:
```bash
chmod +x ~/tmp421_scripts/tmp421_*.sh
```

### 3. Verify Setup
Run diagnostics:
```bash
sudo ~/tmp421_scripts/tmp421_diagnose.sh
```

You should see:
- ✓ i2c-tools is installed
- ✓ FOUND: TMP421 at address 0x1f on bus X (or your configured address)
- ✓ Successfully read from sensor
- Calculated temperature shown in °C

## 📁 File Descriptions

| File | Purpose |
|------|---------|
| `tmp421_read.sh` | Simple one-shot temperature reader (start here) |
| `tmp421_advanced.sh` | Advanced reader with format conversion & logging |
| `tmp421_calibrate.sh` | External sensor calibration tool |
| `tmp421_monitor.sh` | Continuous monitoring with history tracking |
| `tmp421_diagnose.sh` | Diagnostic and troubleshooting tool |
| `tmp421_monitor.service` | Systemd service for background monitoring |
| `README.md` | Basic usage documentation |
| `CALIBRATION.md` | Calibration guide and procedures |
| `SETUP.md` | This file |

## 🚀 Usage Examples

### Simple Temperature Read
```bash
~/tmp421_scripts/tmp421_read.sh
# Output: TMP421 Internal Temperature: 23.45°C
```

### Specify I2C Bus and Address
```bash
# Use bus 1 (default) and address 0x1f (default)
~/tmp421_scripts/tmp421_read.sh

# Use specific bus and address
~/tmp421_scripts/tmp421_read.sh -b 0 -a 0x1f
```

### With Debug Information
```bash
DEBUG=1 ~/tmp421_scripts/tmp421_read.sh
```

### Advanced Options
```bash
# Read both temperatures in Fahrenheit
~/tmp421_scripts/tmp421_advanced.sh -f fahrenheit

# Output as JSON
~/tmp421_scripts/tmp421_advanced.sh -j

# Log to file
~/tmp421_scripts/tmp421_advanced.sh -l

# Combine options
~/tmp421_scripts/tmp421_advanced.sh -f celsius -j -l --internal-only

# Read remote temp with calibration applied
~/tmp421_scripts/tmp421_advanced.sh --remote-only --calibrated
```

### Calibration
```bash
# Calibrate external sensor with known reference temperature
~/tmp421_scripts/tmp421_calibrate.sh calibrate 20.5

# Show calibration status
~/tmp421_scripts/tmp421_calibrate.sh show

# Validate calibration accuracy
~/tmp421_scripts/tmp421_calibrate.sh validate 10

# Reset calibration to default
~/tmp421_scripts/tmp421_calibrate.sh reset
```

### Continuous Monitoring
```bash
# Monitor with 30-second intervals
~/tmp421_scripts/tmp421_monitor.sh -i 30

# Monitor on a specific I2C bus
~/tmp421_scripts/tmp421_monitor.sh -b 0
```

## 🔧 Hardware Wiring

### Raspberry Pi GPIO Pinout
```
GPIO 2 (SDA) ←→ TMP421 SDA
GPIO 3 (SCL) ←→ TMP421 SCL
3.3V         ←→ TMP421 VDD
GND          ←→ TMP421 GND
```

### Pull-up Resistors
Usually 4.7kΩ pull-up resistors are needed on SDA and SCL lines to 3.3V (often already on sensor modules).

## 📊 Automation

### Cron Job for Periodic Reading
```bash
# Edit crontab
crontab -e

# Add one of these lines:

# Read temperature every 5 minutes and log
*/5 * * * * /home/pi/tmp421_scripts/tmp421_advanced.sh -l >> /tmp/tmp421_cron.log 2>&1

# Read temperature hourly
0 * * * * /home/pi/tmp421_scripts/tmp421_read.sh >> /tmp/temp_hourly.log 2>&1

# Read every 30 minutes in Fahrenheit  
*/30 * * * * /home/pi/tmp421_scripts/tmp421_advanced.sh -f fahrenheit -j -l 2>&1
```

### Systemd Service (Background Daemon)

1. Copy service file:
```bash
sudo cp ~/tmp421_scripts/tmp421_monitor.service /etc/systemd/system/
```

2. Edit paths in service file if needed:
```bash
sudo nano /etc/systemd/system/tmp421_monitor.service
# Adjust ExecStart path to your installation location
```

3. Enable and start service:
```bash
sudo systemctl daemon-reload
sudo systemctl enable tmp421_monitor.service
sudo systemctl start tmp421_monitor.service
```

4. Check status:
```bash
sudo systemctl status tmp421_monitor.service
journalctl -u tmp421_monitor.service -f  # Follow logs
```

5. View temperature history:
```bash
cat /var/lib/tmp421/temperature_history.log | jq  # Pretty JSON
cat /var/lib/tmp421/temperature_stats.txt          # Statistics
```

## 🔍 Troubleshooting

### Issue: "I2C bus not found"
**Solution:**
1. Verify I2C is enabled: `raspi-config` → Interface Options → I2C
2. Reboot: `sudo reboot`
3. Check available buses: `ls /dev/i2c-*`

### Issue: "Failed to read from TMP421 sensor"
**Solutions:**
1. Verify sensor is detected and find its address:
   ```bash
   i2cdetect -y 1
   # Should show your sensor address (e.g., 1f, 3e, etc.)
   ```

2. If address differs from default 0x1f, use the address flag:
   ```bash
   ./tmp421_scripts/tmp421_read.sh -a 0x1f  # replace with your actual address
   ```

3. Check wiring and connections
4. Verify pull-up resistors on SDA/SCL

### Issue: "Permission denied when accessing /dev/i2c"
**Solutions:**
1. Run with sudo: `sudo ~/tmp421_scripts/tmp421_read.sh`
2. Or add user to i2c group: `sudo usermod -aG i2c pi`

### Issue: No I2C devices detected at all
**Solutions:**
1. Check GPIO pin configuration: `raspi-gpio get 2,3`
2. Verify GPIO 2 (SDA) and GPIO 3 (SCL) show ALT0
3. If showing IN or OUT, try: `sudo raspi-config` → Interface Options → I2C → Yes

### Issue: Temperature reading seems incorrect
**Solutions:**
1. Verify sensor address is correct (find it with `i2cdetect -y 1`)
2. If address differs from default 0x1f, specify it with `-a` flag
3. Use `DEBUG=1` flag to see raw values
4. Compare with manual i2cget: `sudo i2cget -y 1 0x1f 0x00 w` (adjust address if needed)
5. Check sensor datasheet for register interpretation

## 📈 Data Logging & Analysis

### Log Format
When using advanced script with `-l` flag, logs are in JSON format:
```json
{"internal_temperature_celsius": 23.45, "timestamp": "2026-06-09T15:30:00Z"}
```

### Analyze Logs
```bash
# View last 10 readings
tail -10 /var/log/tmp421_temperatures.log

# Extract just temperatures
grep -o '"internal_temperature_celsius": [0-9.]*' /var/log/tmp421_temperatures.log

# Find max temperature
grep -o '"internal_temperature_celsius": [0-9.]*' /var/log/tmp421_temperatures.log | \
    awk '{print $2}' | sort -n | tail -1
```

## 🔐 Security Considerations

- Scripts require access to `/dev/i2c-*` devices
- Typically available to root and i2c group members
- Service file includes security constraints (ProtectSystem, etc.)
- Monitor data stored in `/var/lib/tmp421/` (restricted access)

## 📝 TMP421 Register Reference

| Register | Address | Description |
|----------|---------|-------------|
| Internal Temperature | 0x00 | Primary internal sensor reading |
| Remote Temperature | 0x01 | External sensor reading (if available) |
| Configuration | 0x04 | Device configuration |
| Status | 0x05 | Device status flags |

### Temperature Data Format
- 16-bit value (little-endian in i2c reads)
- MSB (integer part): -128 to +127°C
- LSB (fractional part): 0-255 representing 0.0000-0.9961°C

## 🆘 Support & Debugging

### Run full diagnostic:
```bash
sudo ~/tmp421_scripts/tmp421_diagnose.sh
```

### Enable verbose output:
```bash
DEBUG=1 ~/.tmp421_scripts/tmp421_advanced.sh -d
```

### Check I2C communication directly:
```bash
# List all I2C devices
sudo i2cdetect -y 1

# Read temperature register directly
sudo i2cget -y 1 0x1f 0x00 w

# Read in byte mode (if word read fails)
sudo i2cget -y 1 0x1f 0x00 b
sudo i2cget -y 1 0x1f 0x00 b  # Read MSB and LSB separately
```

## 📚 Additional Resources

- [TMP421 Datasheet](https://www.ti.com/product/TMP421)
- [Raspberry Pi I2C Guide](https://www.raspberrypi.org/documentation/computers/raspberry-pi.html)
- [i2c-tools Documentation](https://i2c.wiki.kernel.org/index.php/I2CTools)

## 💡 Tips & Tricks

1. **Multiple Sensors**: Sensors with different address pins can be connected to the same I2C bus
2. **Remote Sensor**: If TMP421 has remote sensor capability, uncomment remote temp reading in advanced script
3. **Data Export**: Use `jq` to process JSON logs: `cat file.log | jq .temperature`
4. **Graphing**: Pipe temperature data to graphing tools like Gnuplot or Python matplotlib
5. **Alerting**: Add temperature threshold checks to monitor script for alarm conditions

## 📄 License

These scripts are provided as-is for use with Raspberry Pi OS Trixie and TMP421 sensors.

---

**Last Updated:** June 2026  
**OS Version:** Raspberry Pi OS Trixie  
**Arch:** armv7l/aarch64

