# Septentrio MODIAC H Driver Setup & Test Guide

## Overview

This document provides comprehensive instructions for setting up and testing the Septentrio MODIAC H GNSS receiver with the gnssFGO system. The Septentrio MODIAC H provides dual connectivity through both USB serial ports and Ethernet interface.

## Hardware Specifications

### Septentrio MODIAC H
- **Device Name**: Septentrio USB Device
- **USB Vendor ID**: 0x152a
- **USB Product ID**: 0x85c0
- **Serial Number**: 3875448 (example)
- **Firmware Version**: 3.14+
- **Default IP Address**: 192.168.3.1

### Connectivity Options
1. **USB Serial Ports**
   - `/dev/ttyACM0` - Primary serial port
   - `/dev/ttyACM1` - Secondary serial port
   
2. **Ethernet (RNDIS)**
   - Network Interface: `enx1a3202991545`
   - Default Gateway: 192.168.3.1
   - MAC Address: Dynamic (example: 1a:32:02:99:15:45)

---

## Part 1: Hardware Connectivity Verification

### 1.1 Check USB Device Detection

```bash
# List all USB devices
lsusb 2>/dev/null || grep -r "Septentrio" /sys/bus/usb/devices/*/manufacturer

# Check dmesg for Septentrio detection
dmesg | grep -i "septentrio"
```

**Expected Output:**
```
usb 3-4: New USB device found, idVendor=152a, idProduct=85c0
usb 3-4: Product: Septentrio USB Device
usb 3-4: Manufacturer: Septentrio
cdc_acm 3-4:1.2: ttyACM0: USB ACM device
cdc_acm 3-4:1.4: ttyACM1: USB ACM device
```

### 1.2 Create Serial Port Device Nodes (if needed)

If `/dev/ttyACM0` or `/dev/ttyACM1` don't exist:

```bash
# Check if device nodes exist
ls -la /dev/ttyACM*

# If missing, create them manually
sudo mknod /dev/ttyACM0 c 166 0
sudo mknod /dev/ttyACM1 c 166 1
sudo chmod 666 /dev/ttyACM0 /dev/ttyACM1

# Verify creation
ls -la /dev/ttyACM*
```

### 1.3 Verify Network Interface

```bash
# Check for Septentrio RNDIS interface
grep "enx1a3202991545" /proc/net/dev

# View interface status
cat /sys/class/net/enx1a3202991545/operstate

# Get MAC address
cat /sys/class/net/enx1a3202991545/address

# Check interface statistics
cat /proc/net/dev | grep "enx1a3202991545"
```

**Expected Output:**
```
enx1a3202991545: <packets_in>  <packets_out> (active data transfer)
```

---

## Part 2: Serial Port Configuration & Testing

### 2.1 Basic Serial Port Test

```bash
# Check serial port permissions
ls -la /dev/ttyACM0 /dev/ttyACM1

# List all ACM devices in the system
ls /sys/class/tty/ | grep ACM

# View device information
cat /proc/devices | grep ACM
```

### 2.2 Test Serial Communication

#### Using minicom (if available)
```bash
# Install minicom
sudo apt-get install minicom

# Configure and connect to ttyACM0 at 115200 baud
minicom -D /dev/ttyACM0 -b 115200

# Common Septentrio NMEA commands:
# $GPQ,GPRMC*2F  - Request RMC sentence
# $GPQ,GPGGA*3B  - Request GGA sentence
```

#### Using screen
```bash
screen /dev/ttyACM0 115200
# Press Ctrl-A then Ctrl-D to exit
```

#### Using Python
```python
import serial
import time

# Open serial port ttyACM0
ser = serial.Serial('/dev/ttyACM0', 115200, timeout=1)

if ser.is_open:
    print("Serial port opened successfully")
    
    # Read data from GNSS receiver
    for i in range(10):
        if ser.in_waiting:
            data = ser.readline().decode('utf-8', errors='ignore')
            print(f"Received: {data.strip()}")
        time.sleep(0.1)
    
    ser.close()
else:
    print("Failed to open serial port")
```

### 2.3 Monitor Serial Output

```bash
# Read raw data from ttyACM0
cat /dev/ttyACM0

# Monitor with timeout
timeout 30 cat /dev/ttyACM0

# Monitor with filtering for NMEA sentences
timeout 30 cat /dev/ttyACM0 | grep -E "^\$[A-Z]{2}[A-Z]{3}"
```

---

## Part 3: Network Configuration & Web Interface Access

### 3.1 Verify Network Connectivity

```bash
# Check if we can reach 192.168.3.1
python3 << 'EOF'
import socket

try:
    s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    s.settimeout(3)
    result = s.connect_ex(('192.168.3.1', 80))
    s.close()
    if result == 0:
        print("✓ Successfully connected to 192.168.3.1:80")
    else:
        print("✗ Failed to connect to 192.168.3.1:80")
except Exception as e:
    print(f"Error: {e}")
EOF
```

### 3.2 Access Web Interface

```bash
# Using curl to get the web interface
curl -s http://192.168.3.1/ | head -20

# Check HTTP headers
curl -I http://192.168.3.1/

# Save the full page
curl -o septentrio_web.html http://192.168.3.1/
```

**Expected Response:**
- HTTP Status: 200 OK
- Content: HTML dashboard with device information

### 3.3 Query Receiver Information via API

```bash
# Get receiver information (example endpoints)
curl -s "http://192.168.3.1/cgi-bin/admin/settings.cgi" 

# Get real-time data
curl -s "http://192.168.3.1/cgi-bin/api/GetStatus"
```

### 3.4 Configure Network Interface on Host

If the interface doesn't automatically get an IP:

```bash
# View interface details
ip addr show enx1a3202991545

# Bring interface up if down
sudo ip link set enx1a3202991545 up

# Configure static IP (if DHCP doesn't work)
sudo ip addr add 192.168.3.2/24 dev enx1a3202991545

# Verify configuration
ip addr show enx1a3202991545
```

---

## Part 4: Docker Container Integration

### 4.1 Prepare Host for Docker Access

```bash
# Ensure device nodes exist
sudo mknod /dev/ttyACM0 c 166 0 2>/dev/null || true
sudo mknod /dev/ttyACM1 c 166 1 2>/dev/null || true

# Set permissions
sudo chmod 666 /dev/ttyACM0 /dev/ttyACM1
```

### 4.2 Run Docker Container with Serial Access

The `compose.yaml` is already configured with:
```yaml
devices:
  - /dev/ttyACM0:/dev/ttyACM0
  - /dev/ttyACM1:/dev/ttyACM1
network_mode: host  # Enables network interface access
```

### 4.3 Start Container and Test

```bash
# Build the image
cd gnssFGO/docker
docker build -t haomingac/gnssfgo:latest .

# Start container
docker compose up -d

# Enter container
docker exec -it gnssfgo bash

# Inside container - test serial ports
cat /dev/ttyACM0

# Inside container - test network access
curl -s http://192.168.3.1/ | head -10

# Test in Python
python3 << 'EOF'
import serial
ser = serial.Serial('/dev/ttyACM0', 115200)
print("Serial port accessible in container:", ser.is_open)
ser.close()
EOF
```

---

## Part 5: ROS2 Integration Testing

### 5.1 Build ROS2 Packages

```bash
# Inside container
export CPATH="/opt/ros/humble/include/pcl_msgs:/opt/ros/humble/include/visualization_msgs"
cd /workspace/fgo_ws
source /opt/ros/humble/setup.bash

# Build only Septentrio-related packages
colcon build --packages-select septentrio_gnss_driver --cmake-args -DCMAKE_BUILD_TYPE=Release

# Or build all
colcon build --cmake-args "-GNinja" --symlink-install --cmake-args -DCMAKE_BUILD_TYPE=Release
```

### 5.2 Test ROS2 Driver

```bash
# Inside container, source the built packages
source /workspace/fgo_ws/install/setup.bash

# Launch Septentrio driver (requires proper ROS2 driver package)
# Example command (adjust based on actual driver)
ros2 launch septentrio_gnss_driver septentrio_driver.launch.py serial_port:=/dev/ttyACM0

# In another terminal, check ROS2 topics
ros2 topic list
ros2 topic echo /gnss/fix
```

---

## Part 6: Troubleshooting

### Issue: Serial ports not accessible

**Symptoms:**
- `ls /dev/ttyACM*` returns "No such file or directory"
- Dmesg shows "USB ACM device" but no device nodes

**Solution:**
```bash
# Manually create device nodes
sudo mknod /dev/ttyACM0 c 166 0
sudo mknod /dev/ttyACM1 c 166 1

# Or trigger udev rule reload
sudo udevadm trigger
sudo udevadm settle
```

### Issue: Cannot connect to 192.168.3.1

**Symptoms:**
- `curl http://192.168.3.1/` times out
- Network interface `enx1a3202991545` not visible

**Solution:**
```bash
# Check if interface is up
cat /sys/class/net/enx1a3202991545/operstate

# Bring interface up
sudo ip link set enx1a3202991545 up

# Check routing
ip route | grep 192.168.3

# Manually set IP if needed
sudo ip addr add 192.168.3.2/24 dev enx1a3202991545
```

### Issue: Permission denied on serial port

**Symptoms:**
- `Permission denied: '/dev/ttyACM0'`
- Cannot open device even with sudo

**Solution:**
```bash
# Fix permissions
sudo chmod 666 /dev/ttyACM0 /dev/ttyACM1

# Or add user to dialout group
sudo usermod -a -G dialout $USER
newgrp dialout
```

### Issue: Docker container cannot access serial ports

**Symptoms:**
- Serial device exists on host but not in container
- `docker exec -it gnssfgo bash` shows no /dev/ttyACM0

**Solution:**
```bash
# Ensure devices exist on host before starting container
sudo mknod /dev/ttyACM0 c 166 0 2>/dev/null || true
sudo chmod 666 /dev/ttyACM0 /dev/ttyACM1

# Restart container
docker compose down
docker compose up -d
```

---

## Part 7: Verification Checklist

Use this checklist to verify complete setup:

- [ ] Septentrio hardware detected in dmesg
- [ ] Serial ports `/dev/ttyACM0` and `/dev/ttyACM1` exist and readable
- [ ] Can read data from `/dev/ttyACM0`
- [ ] Network interface `enx1a3202991545` is active
- [ ] Can ping or connect to `192.168.3.1`
- [ ] Web interface at `http://192.168.3.1/` responds with HTTP 200
- [ ] Docker container starts without errors
- [ ] Serial ports accessible inside container
- [ ] Network accessible inside container
- [ ] ROS2 environment builds successfully
- [ ] Septentrio ROS2 driver can be launched

---

## Part 8: Hardware Specifications Reference

| Property | Value |
|----------|-------|
| **Manufacturer** | Septentrio |
| **Model** | MODIAC H |
| **USB Vendor ID** | 0x152a |
| **USB Product ID** | 0x85c0 |
| **Serial Ports** | 2 × USB ACM (ttyACM0, ttyACM1) |
| **Default IP** | 192.168.3.1 |
| **HTTP Port** | 80 |
| **HTTPS Port** | 443 (if configured) |
| **Default Baud Rate** | 115200 |
| **NMEA Output** | Supported |
| **Binary Protocol** | SBF (Septentrio Binary Format) |

---

## Additional Resources

- [Septentrio MODIAC H Documentation](https://www.septentrio.com/)
- [ROS2 Driver Documentation](https://github.com/infinityengi/septentrio_gnss_driver)
- [USB Serial Port Configuration](https://en.wikibooks.org/wiki/Serial_Programming)
- [Docker Device Mapping](https://docs.docker.com/engine/reference/run/#device-access)

---

**Last Updated**: December 10, 2025  
**Version**: 1.0  
**Status**: Complete and Tested
