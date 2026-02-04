# Drone Interfaces Documentation

This document explains how to communicate with the drone's flight controller and access the camera feed using standard protocols.

## Flight Controller Interface (MAVLink)

### Overview
The drone uses **MAVLink** (Micro Air Vehicle Link) protocol for flight control commands. MAVLink is an industry-standard protocol for communicating with drones and autopilots.

### Connection Details
- **Protocol**: MAVLink v2
- **Transport**: UDP
- **Host**: `0.0.0.0` (listen on all interfaces)
- **Port**: `14550`
- **Target System**: Auto-detected via heartbeat
- **Coordinate Frame**: NED (North-East-Down)

### How to Connect

```python
from pymavlink import mavutil

# Establish connection
master = mavutil.mavlink_connection('udp:0.0.0.0:14550')

# Wait for heartbeat to confirm connection
master.wait_heartbeat()
print(f"Connected to system {master.target_system}, component {master.target_component}")
```

### Example MAVLink Commands

#### 1. Set Flight Mode
```python
# Get the mode ID from mode mapping
mode = 'GUIDED'  # Can be: STABILIZE, GUIDED, LOITER, RTL, LAND, etc.
mode_id = master.mode_mapping()[mode]

# Send mode change command
master.mav.set_mode_send(
    master.target_system,
    mavutil.mavlink.MAV_MODE_FLAG_CUSTOM_MODE_ENABLED,
    mode_id
)
```

#### 2. Arm Motors
```python
# Standard arm command
master.arducopter_arm()

# OR use force-arm if needed
master.mav.command_long_send(
    master.target_system,
    master.target_component,
    mavutil.mavlink.MAV_CMD_COMPONENT_ARM_DISARM,
    0,
    1,      # 1 to arm, 0 to disarm
    21196,  # Force-arm magic number for ArduPilot
    0, 0, 0, 0, 0
)
```

### MAVLink Resources
- **Official Documentation**: https://mavlink.io/en/
- **ArduPilot MAVLink Commands**: https://ardupilot.org/dev/docs/mavlink-commands.html
- **pymavlink Documentation**: https://mavlink.io/en/mavgen_python/
- **Message Definitions**: https://mavlink.io/en/messages/common.html

---

## Camera Interface (TCP Stream)

### Overview
The camera streams color video over a TCP connection using a simple binary protocol.

### Connection Details
- **Protocol**: TCP
- **Host**: `localhost` (or drone IP if remote)
- **Port**: `5599`
- **Format**: Binary stream with header + payload

### Data Protocol

Each frame consists of:

1. **Header** (4 bytes):
   - Bytes 0-1: Width (unsigned short, little-endian)
   - Bytes 2-3: Height (unsigned short, little-endian)

2. **Payload** (width × height bytes):
   - color pixel data (3 byte per pixel)
   - Row-major order (left to right, top to bottom)

---
### Revision History

- 2026-02-04: Camera stream changed to color (3 bytes per pixel) — not grayscale; payload and documentation updated accordingly.
