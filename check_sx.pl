#!/usr/bin/perl -w
#
# check_sx.pl - nagios plugin for checking silex technology SX-3000GB Gigabit-Ethernet USB Device Server - http://www.silexeurope.com/de/home/produkte/usb-device-server3/sx-3000gb.html
#
# Copyright (C) 2015 Jürgen Steinblock
#
# Report bugs to: https://github.com/Steinblock/check_sx/issues
#
# 14.04.2015 Version 1.0
#
# Usage:
# 
# This script fetches the webpage from a SX-3000GB Device Server (may or may not work with other silex device servers).
# The purpose is to check if a license dongle is still connected and (optionally) if it's connected to the right host.
# You need to specify the hostadress and either the device name shown in the web interface or the device id (a zero based value) for the port
# This script either outputs OK (device still conntected) or CRITICAL (device disconnected or connected to wrong host).
#
# Examples:
#
# ./check_sx.pl -H 192.168.1.100 -i 0
# checks if device is still connected
# 
# ./check_sx.pl -H 192.168.1.100 -n "HASP HL 2.16" -C 192.168.1.11
# checks if device is connected to IP 192.168.1.11
#
# Note:
# The script outputs the duration from the web server response.
# However, for the devices I testet it only contains a time value shorter 24h so you can't tell the total connection time.
# 

use strict;
use File::Basename;
use Getopt::Long;
use LWP::Simple;
use vars qw($PROGNAME);
use utils qw ($TIMEOUT %ERRORS &print_revision &support);
 
sub print_help ();
sub print_version ();
 
my ($opt_h, $opt_V, $opt_H, $opt_p, $opt_d, $opt_i, $opt_n, $opt_C, $opt_t);
my ($result, $message, $age, $size, $st);
 
$PROGNAME=basename($0);
 
$opt_H="";
$opt_p=80;
$opt_d=0;
$opt_t="10";
 
Getopt::Long::Configure('bundling');
GetOptions(
	"h=s" => \$opt_h, "help"		=> \$opt_h,
	"V=s" => \$opt_V, "version"	=> \$opt_V,
	"H=s" => \$opt_H, "hostname"	=> \$opt_H,
	"p=i" => \$opt_p, "port"		=> \$opt_p,
	"d"   => \$opt_d, "debug"		=> \$opt_d,
	"i=i" => \$opt_i, "deviceid"	=> \$opt_i,
	"n=s" => \$opt_n, "devicename"	=> \$opt_n,
	"C=s" => \$opt_C, "client"	=> \$opt_C,
        "t=i" => \$opt_t, "timeout"	=> \$opt_t);
 
if ($opt_t) {
        $TIMEOUT=$opt_t;
}
 
# Just in case of problems, let's not hang Nagios
$SIG{'ALRM'} = sub {
        print "UNKNOWN - Plugin Timed out\n";
        exit $ERRORS{"UNKNOWN"};
};
alarm($TIMEOUT);
 
if ($opt_h) {
	print_help();
        exit $ERRORS{'UNKNOWN'};
}

if ($opt_V) {
	print_version();
        exit $ERRORS{'UNKNOWN'};
}

if (! $opt_H) {
        print "No Hostname specified\n";
        exit $ERRORS{'UNKNOWN'};
}

if (!defined($opt_i) && !defined($opt_n)) {
	print "No Device Id or Device Name specified\n";
	exit $ERRORS{'UNKNOWN'};
}
 
sub print_version () {
        print "$PROGNAME 1.0\n";
}

sub print_help () {
        print "Copyright (c) 2015 Jürgen Steinblock\n\n";
        print "Usage:\n";
        print "  $PROGNAME -H <hostname> [-p <port>] [-i <deviceid>|-n devicename] [-C client]\n";
        print "  $PROGNAME [-h | --help]\n";
        print "  $PROGNAME [-V | --version]\n\n";
	print "Options:\n";
	print "  -H, --hostname\n";
	print "     Host name or IP Address\n";
        print "  -p, --port\n";
        print "     Port number (default: 80)\n";
        print "  -i, --deviceid\n";
        print "     Device Id\n";
        print "  -n, --devicename\n";
        print "     Device Name\n";
        print "  -C, --client\n";
        print "     Expected Client\n";
        print "  -h, --help\n";
        print "     Print detailed help screen\n";
        print "  -V, --version\n";
        print "     Print version information\n\n";
}
 
my $url = "http://$opt_H:$opt_p/en/status/devstat.htm";
my $html = get("$url");
unless (length($html)) {
	print "Unable to load page for '$url'\n";
	exit $ERRORS{'UNKNOWN'};
}

# Example String:
# devs[0] = "Hardlock USB 1.02$AKS$Low Speed$192.168.143.200$00:29:19";

my ($found, $deviceid, $devicename, $manufacturer, $speed, $client, $duration);
foreach my $line (split("\n", $html)) {
	if ($line =~ /devs\[(\d+)\] = \"(.+)\$(.+)\$(.+)\$(.+)\$(.+)";/) {

		$deviceid = $1;
		$devicename = $2;
		$manufacturer = $3;
		$speed = $4;
		$client = $5;
		$duration = $6;

		$devicename =~ s/(^\s+|\s+$)//;
		$manufacturer =~ s/(^\s+|\s+$)//;

		if (defined($opt_d) && $opt_d) {
			print "DeviceId: $deviceid, Devicename: $devicename, Manufacturer: $manufacturer, Speed: $speed, Client: $client, Duration: $duration\n";
		}

		if ((defined($opt_i) && $deviceid == $opt_i) || (defined($opt_n) && $devicename eq $opt_n)) {
			$found = 1;
                	#print "deviceid:     $deviceid\n";
                	#print "devicename:   $devicename\n";
                	#print "manufacturer: $manufacturer\n";
                	#print "speed:        $speed\n";
                	#print "client:       $client\n";
                	#print "duration:     $duration\n";
			last;
		}

	}
}


if (!$found && defined($opt_i)) {
	# Device with given id not found
	print "Device [$opt_i] not found\n";
	exit $ERRORS{'CRITICAL'};
} elsif (!$found && defined($opt_n)) {
	# Device with given name not found
	print "Device '$opt_n' not found\n";
	exit $ERRORS{'CRITICAL'};
} elsif ($client =~ /Not Connected/i) {
	# device present but not connected. Include expected client in output to help admin find the right host
	print defined($opt_C)
		? "Device '$devicename' [$deviceid] not connected to $opt_C\n"
		: "Device '$devicename' [$deviceid] not connected\n";
	exit $ERRORS{'CRITICAL'};
} elsif (defined($opt_C) && $opt_C ne $client) {
	# device present but connected to wrong client
	print "Device '$devicename' [$deviceid] connected to wrong $client since $duration\n";
	exit $ERRORS{'CRITICAL'};	
} else {
	# device present and connected to expected client
	print "Device '$devicename' [$deviceid] connected to $client since $duration\n";
	exit $ERRORS{'OK'};
}
