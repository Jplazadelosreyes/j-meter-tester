#!/bin/bash

# Ensure the VNC password directory exists and set the password
mkdir -p "$HOME"/.vnc
echo "$VNC_PW" | vncpasswd -f > "$HOME"/.vnc/passwd
chmod 600 "$HOME"/.vnc/passwd

# Create the xstartup script for XFCE4
# This script will be executed by the VNC server when it starts.
cat << 'EOF_INNER_XSTARTUP' > "$HOME"/.vnc/xstartup
#!/bin/bash

# Source profile for environmental variables like XDG_RUNTIME_DIR
# if you were using systemd, this would be auto-managed.
# For Docker slim images, often this is missing.
if [ -f /etc/profile ]; then
    . /etc/profile
fi

# Ensure D-Bus is running for XFCE4
# This is crucial for many GUI applications and desktop environments
if [ -z "$DBUS_SESSION_BUS_ADDRESS" ]; then
    eval "$(dbus-launch --sh-syntax)"
fi

# Set a trap to ensure dbus-daemon exits when xfce4-session exits
trap "kill \$DBUS_SESSION_BUS_PID" EXIT

# Unset SESSION_MANAGER to let xfce4-session manage it
unset SESSION_MANAGER

# Disable screen blanking and power management
xset -dpms
xset s off

# Export the display variable
export DISPLAY=:1

# Start the XFCE4 session. 'exec' replaces the current shell process.
exec xfce4-session
EOF_INNER_XSTARTUP
chmod +x "$HOME"/.vnc/xstartup

# Start the VNC server in the background.
# The VNC server will execute the xstartup script for the graphical environment.
vncserver :1 -geometry 1280x800 -depth 24 -localhost no

# Give the VNC server and XFCE4 session ample time to initialize.
# This is a critical sleep, as JMeter needs the X server fully ready.
echo "Waiting for VNC and XFCE4 to fully initialize (30 seconds)..."
sleep 30 # Increased to 30 seconds for robustness

# Now launch JMeter. It will connect to the X server started by VNC.
echo "Launching JMeter..."
DISPLAY=:1 jmeter &

# Keep the container running
echo "JMeter started. Keeping container alive."
tail -f /dev/null