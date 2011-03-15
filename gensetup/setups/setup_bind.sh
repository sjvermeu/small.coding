#!/bin/sh

# - CONFFILE (path to the configuration file)
# - STEPS (list of steps supported by the script)
# - STEPFROM (step to start from - can be empty)
# - STEPTO (step to go to - can be empty)
# - LOG (log file to use - will always be appended)
# - FAILED (temporary file; as long as it exists, the system did not fail)
# 
# Next, run the following functions:
# initTools;
#
# If you ever want to finish using the libraries, but want to keep the
# script alive, use cleanupTools;
##
## Helper commands
##

typeset CONFFILE=$1;
export CONFFILE;

typeset STEPS="configsystem installbind configbind";
export STEPS;

typeset STEPFROM=$2;
export STEPFROM;

typeset STEPTO=$3;
export STEPTO;

typeset LOG=/tmp/build.log;
export LOG;

typeset FAILED=$(mktemp);
export FAILED;

[ -f master.lib.sh ] && source ./master.lib.sh;
[ -f common.lib.sh ] && source ./common.lib.sh;

initTools;


##
## Functions
##

configsystem() {
  _configsystem;
  die "Please restart the network and continue with step installbind.";
}

installbind() {
  logMessage "  > Installing 'bind'... ";
  installSoftware -u bind || die "Failed to install Bind (emerge failed)";
  logMessage "done\n";

  logMessage "  > Adding bind to default runlevel... ";
  rc-update add named default
  logMessage "done\n";
}

configbind() {
  logMessage "  > Configuring named.conf... ";
  cat > /etc/bind/named.conf << EOF
acl "xfer" {
	/* Deny transfers by default except for the listed hosts.
	 * If we have other name servers, place them here.
	 */
	none;
};

acl "trusted" {
	127.0.0.0/8;
	::1/128;
	192.168.100.0/24;
};

options {
	directory "/var/bind";
	pid-file "/var/run/named/named.pid";

	listen-on-v6 { ::1; };
	listen-on { 127.0.0.1; 192.168.100.71; };

	allow-query {
		trusted;
	};

	allow-query-cache {
		trusted;
	};

	allow-recursion {
		trusted;
	};

	allow-transfer {
		none;
	};

	allow-update {
		none;
	};

	forward first;
	forwarders {
		192.168.100.1;
		8.8.8.8;
		8.8.4.4;
	};
};

logging {
	channel default_syslog {
		file "/var/log/named/named.log" versions 5 size 50M;
		print-time yes;
		print-severity yes;
		print-category yes;
	};

	category default { default_syslog; };
	category general { default_syslog; };
};

include "/etc/bind/rndc.key";
controls {
	inet 127.0.0.1 port 953 allow { 127.0.0.1/32; ::1/128; } keys { "rndc-key"; };
};

view "internal" {
	match-clients { 192.168.100.0/24; localhost; };
	recursion yes;

	zone "virtdomain.com" {
		type master;
		file "pri/virtdomain.com.internal";
		allow-transfer { any; };
	};
};
EOF
  logMessage "done\n";

  logMessage "  > Configuring virtdomain.com.internal zone file... ";
  cat > /var/bind/pri/virtdomain.com.internal << EOF
$TTL 2d
@	IN SOA	ns.virtdomain.com.	admin.virtdomain.com. (
	2011031502	; serial
	3h		; refresh
	1h		; retry
	1w		; expiry
	1d )		; minimum

virtdomain.com.		IN MX	0	mail1.virtdomain.com.
virtdomain.com.		IN TXT	"v=spf1 ip4:192.168.100.71/32 mx ptr mx:mail1.virtdomain.com ~all"
virtdomain.com.		IN NS	ns1.virtdomain.com.
virtdomain.com.		IN NS	ns2.virtdomain.com.
ns1.virtdomain.com.	IN A	192.168.100.71
ns2.virtdomain.com.	IN A	192.168.100.72
postgres.virtdomain.com	IN A	192.168.100.52
www1.virtdomain.com.	IN A	192.168.100.61
www2.virtdomain.com.	IN A	192.168.100.62
ldap1.virtdomain.com.	IN A	192.168.100.55
ldap2.virtdomain.com.	IN A	192.168.100.56
mail1.virtdomain.com.	IN A	192.168.100.51
build.virtdomain.com.	IN A	192.168.100.50
EOF
  logMessage "done\n";
}

stepOK "configsystem" && (
logMessage ">>> Step \"configsystem\" starting...\n";
runStep configsystem;
);
nextStep;

stepOK "installbind" && (
logMessage ">>> Step \"installbind\" starting...\n";
runStep installbind;
);
nextStep;

stepOK "configbind" && (
logMessage ">>> Step \"configbind\" starting...\n";
runStep configbind;
);
nextStep;

cleanupTools;
rm ${FAILED};
