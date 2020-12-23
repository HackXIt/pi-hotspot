#!/bin/bash

if [ "$EUID" -ne 0 ]; then
	echo "Please run as root"
	exit
fi

apt install hostapd isc-dhcp-server -y
if [ $? -ne 0 ]; then echo "Error installing packages."; exit; fi;

service hostapd stop
if [ $? -ne 0 ]; then echo "Error stopping service."; exit; fi;
service isc-dhcp-server stop
if [ $? -ne 0 ]; then echo "Error stopping service."; exit; fi;
systemctl stop NetworkManager.service
if [ $? -ne 0 ]; then echo "Error stopping service."; exit; fi;

# Change Interface configuration
cat interfaces >> /etc/network/interfaces
echo "Appended interface config. Please check /etc/network/interfaces when issues occur."
echo "If there was an existing config it wasn't overwritten and needs to be removed manually."

# Setup of hostapd
cp hostapd.conf /etc/hostapd/
echo "Copied hostapd.conf to /etc/hostapd/"
echo 'DAEMON_CONF="/etc/hostapd/hostapd.conf"' >> /etc/default/hostapd
echo "Appended DAEMON_CONF setting to /etc/default/hostapd"

# Setup of isc-dhcp-server
mv /etc/dhcp/dhcpd.conf /etc/dhcp/dhcpd.bak
echo "Backed up default-config 'dhcpd.conf' in /etc/dhcp/"
mv dhcpd.conf /etc/dhcp/
echo "Moved setup-config 'dhcpd.conf' from setup to /etc/dhcp/"

# Insert wlan0 to DHCP-Interfaces
TARGET_KEY=INTERFACESv4
CONFIG_FILE=/etc/default/isc-dhcp-server
REPLACEMENT_VALUE=\"wlan0\"
sed-c -i "s/\($TARGET_KEY *= *\).*/\1$REPLACEMENT_VALUE/" $CONFIG_FILE

# Uncomment IPv4 forwarding in sysctl
CONFIG_FILE=/etc/sysctl.conf
TARGET_LINE=net.ipv4.ip_forward=1
sed -i '/\($TARGET_LINE\)/s/^#//g' $CONFIG_FILE
# Directly Save config
sh -c "echo 1 > /proc/sys/net/ipv4/ip_forward"

# Change firewall settings
iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
ipdables -A FORWARD -i eth0 -o wlan0 -m state --state RELATED,ESTABLISHED -j ACCEPT
iptables -A FORWARD -i wlan0 -o eth0 -j ACCEPT
# Output-check
echo "Changed firewall settings, see below:"
iptables -L -n -v
# Save firewall rules
sh -c "iptables-save > /etc/iptables.ipv4.nat"
# Load rule automatically on system boot
# Doesn't consider exit 0 in rc.local - Should be considered if it exists
echo "iptables-restore < /etc/iptables.ipv4.nat" >> /etc/rc.local

# Starting services
service isc-dhcp-server start
service hostapd start
systemctl start NetworkManager.service
echo "Started services, WLAN Hotspot should be running now."
echo "SSID: Systest-Spot"
echo "PASS: Syst3m_t3st"

mv start-spot.sh.x /usr/local/sbin/start-spot
echo "Start hotspot with 'start-spot' - Root priviledges required."
mv stop-spot.sh.x /usr/local/sbin/stop-spot
echo "Stop hotspot with 'stop-spot' - Root priviledges required."
