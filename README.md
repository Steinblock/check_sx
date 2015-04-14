# check_sx

nagios plugin for checking silex technology SX-3000GB Gigabit-Ethernet USB Device Server - http://www.silexeurope.com/de/home/produkte/usb-device-server3/sx-3000gb.html

Copyright (C) 2015 Jürgen Steinblock

Report bugs to: https://github.com/Steinblock/check_sx/issues

14.04.2015 Version 1.0

# Usage:
 
This script fetches the webpage from a SX-3000GB Device Server (may or may not work with other silex device servers).
The purpose is to check if a license dongle is still connected and (optionally) if it's connected to the right host.
You need to specify the hostadress and either the device name shown in the web interface or the device id (a zero based value) for the port
This script either outputs OK (device still conntected) or CRITICAL (device disconnected or connected to wrong host).

# Examples:

./check_sx.pl -H 192.168.1.100 -i 0
checks if device is still connected
 
./check_sx.pl -H 192.168.1.100 -n "HASP HL 2.16" -C 192.168.1.11
checks if device is connected to IP 192.168.1.11

# Note:
The script outputs the duration from the web server response.
However, for the devices I testet it only contains a time value shorter 24h so you can't tell the total connection time.
