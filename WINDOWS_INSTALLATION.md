# Windows Installation Guide

Documentation and resources for setting up ArduPilot SITL with Webots on Windows.

## Prerequisites

- Windows 10/11 (64-bit)
- At least 8GB RAM
- 20GB free disk space

## Components to Install

### 1. Webots Simulator
- **Download:** [Webots R2025a for Windows](https://github.com/cyberbotics/webots/releases/tag/R2025a)
- **Installation Guide:** [Webots Installation Procedure](https://cyberbotics.com/doc/guide/installation-procedure)

### 2. Python Environment
- **Download:** [Python 3.8+ for Windows](https://www.python.org/downloads/)
- **Required Libraries:** DroneKit, PyMAVLink (install via `pip install -r requirements.txt`)

### 3. ArduPilot SITL

ArduPilot SITL runs best on Linux. For Windows, use WSL2 or Cygwin.

**Option A: WSL2 (Recommended)**
- **Setup Guide:** [Install WSL on Windows](https://learn.microsoft.com/en-us/windows/wsl/install)
- **ArduPilot Setup:** [Setting up SITL on Linux (WSL)](https://ardupilot.org/dev/docs/setting-up-sitl-on-linux.html)

**Option B: Cygwin**
- **Download:** [Cygwin for Windows](https://www.cygwin.com/)
- **ArduPilot Setup:** [Building ArduPilot on Windows with Cygwin](https://ardupilot.org/dev/docs/building-setup-windows-cygwin.html)

## Documentation & Resources

### ArduPilot
- [ArduPilot SITL Documentation](https://ardupilot.org/dev/docs/sitl-simulator-software-in-the-loop.html) - Overview of SITL
- [Using SITL with Webots](https://ardupilot.org/dev/docs/sitl-with-webots.html) - Integration guide
- [MAVLink Commands in Guided Mode](https://ardupilot.org/dev/docs/copter-commands-in-guided-mode.html) - Control commands
- [ArduPilot Development Wiki](https://ardupilot.org/dev/index.html) - Complete developer documentation

### Webots
- [Webots User Guide](https://cyberbotics.com/doc/guide/index) - Complete user manual
- [External Robot Controllers](https://cyberbotics.com/doc/guide/running-extern-robot-controllers) - How to use `<extern>` mode
- [Webots Tutorial](https://cyberbotics.com/doc/guide/tutorial-1-your-first-simulation-in-webots) - Getting started

### MAVLink & DroneKit
- [DroneKit Python Guide](https://dronekit-python.readthedocs.io/en/latest/guide/index.html) - Python API for drone control
- [PyMAVLink Documentation](https://mavlink.io/en/mavgen_python/) - Low-level MAVLink protocol
- [MAVLink Message Definitions](https://mavlink.io/en/messages/common.html) - Protocol reference

### Windows-Specific
- [WSL Documentation](https://learn.microsoft.com/en-us/windows/wsl/) - Windows Subsystem for Linux
- [WSL Networking](https://learn.microsoft.com/en-us/windows/wsl/networking) - Connecting WSL to Windows apps

## Quick Setup Summary

Once all components are installed:

1. **Start Webots** → Open `iris_modified.wbt` → Set controller to `<extern>` → Press Play
2. **Start ArduPilot SITL** (in WSL/Cygwin): `sim_vehicle.py -v ArduCopter -f webots-python --console --map`
3. **Run Webots Controller** (in PowerShell): `python Webots\controller\ardupilot_vehicle_controller.py`
4. **Run Your Script** (in PowerShell): `python Task\flight.py`

## Common Issues

**WSL Network Issues:**
- If ArduPilot in WSL can't connect to Webots on Windows, find Windows IP: `ip route | grep default | awk '{print $3}'`
- Use this IP instead of `localhost` when configuring connections

**Port Conflicts:**
- Check if ports are free: `netstat -an | findstr "5760"`
- Default ports: 5760 (MAVLink), 14550 (GCS), 1234 (Webots extern)

**Python Path Issues:**
- Verify Python in PATH: `where python`
- Reinstall with "Add Python to PATH" checked if not found
