#!/usr/bin/env bash
set -e

# ArduPilot SITL + Webots Simulation Startup Script
# This script starts the container services and opens the noVNC web interface

NOVNC_PORT=6080
NOVNC_URL="http://localhost:${NOVNC_PORT}/vnc.html?autoconnect=true"

echo "🚀 Starting ArduPilot SITL + Webots simulation..."

# Check for .env file
if [ ! -f .env ]; then
    if [ -f .env.example ]; then
        echo "⚠ No .env file found. Copying from .env.example..."
        cp .env.example .env
        echo "✓ Created .env - please review and adjust paths if needed"
    else
        echo "⚠ Warning: No .env file found. Using default values."
    fi
fi

# Start containers with the appropriate tool
if command -v podman-compose &> /dev/null; then
    echo "⬇️  Pulling latest images with podman-compose..."
    podman-compose pull
    echo "📦 Starting with podman-compose..."
    podman-compose up -d
elif command -v docker &> /dev/null; then
    echo "⬇️  Pulling latest images with docker compose..."
    docker compose pull
    echo "🐳 Starting with docker compose..."
    docker compose up -d
else
    echo "❌ Error: Neither podman-compose nor docker found."
    echo "   Please install Podman: sudo apt install podman podman-compose"
    echo "   Or Docker: https://docs.docker.com/engine/install/"
    exit 1
fi

echo ""
echo "════════════════════════════════════════════════════════════"
echo "✅ Simulation containers started!"
echo "════════════════════════════════════════════════════════════"
echo ""
echo "⏳ Waiting for noVNC to be ready..."
sleep 5

# Try to open the browser
open_browser() {
    local url="$1"
    
    if command -v xdg-open &> /dev/null; then
        xdg-open "$url" 2>/dev/null &
    elif command -v gnome-open &> /dev/null; then
        gnome-open "$url" 2>/dev/null &
    elif command -v kde-open &> /dev/null; then
        kde-open "$url" 2>/dev/null &
    elif command -v open &> /dev/null; then
        open "$url" 2>/dev/null &
    else
        echo "⚠ Could not detect browser. Please open manually:"
        echo "   $url"
        return 1
    fi
    return 0
}

echo ""
echo "🌐 Opening MAVProxy GUI in browser..."
if open_browser "$NOVNC_URL"; then
    echo "   $NOVNC_URL"
else
    echo ""
fi

echo ""
echo "Next steps:"
echo ""
echo "  1. Open Webots and load the world:"
echo "     webots Webots/worlds/iris_Task_2.wbt"
echo "     Then press ▶ (Play)"
echo ""
echo "  2. In another terminal, run the control script, for example:"
echo "     source venv/bin/activate"
echo "     python Task/flight.py"
echo ""
echo "  MAVProxy GUI: $NOVNC_URL"
echo "  To stop: ./stop.sh"
echo ""
