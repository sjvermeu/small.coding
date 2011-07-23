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

typeset STEPS="configsystem installbind configbind setuppam setupzabbix";
export STEPS;

typeset STEPFROM=$2;
export STEPFROM;

typeset STEPTO=$3;
export STEPTO;

typeset LOG=/tmp/build.log;
export LOG;

typeset FAILED=$(mktemp);
export FAILED;

[ -f master.lib.sh ] && source ./master.lib.sh || exit 1;
[ -f common.lib.sh ] && source ./common.lib.sh || exit 1;

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
  typeset FILE="/etc/bind/named.conf";
  typeset META=$(initChangeFile ${FILE});
  cat > /etc/bind/named.conf << EOF
acl "xfer" {
	@SECUNDARY@;
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
	listen-on { 127.0.0.1; @IPADDRESS@; };

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
		xfer;
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
EOF
  sed -i -e "s:@IPADDRESS@:$(getValue dns.listen):g" ${FILE};
  sed -i -e "s:@SECUNDARY@:$(getValue dns.secundary):g" ${FILE};
  typeset DNSTYPE="$(getValue dns.type)";
  if [ "${DNSTYPE}" = "master" ];
  then
    cat >> ${FILE} << EOF
view "internal" {
	match-clients { 192.168.100.0/24; localhost; };
	recursion yes;

	zone "virtdomain.com" {
		type master;
		file "pri/virtdomain.com.internal";
		allow-transfer { xfer; };
	};

	zone "virt-domain.com" {
		type master;
		file "pri/virt-domain.com.internal";
		allow-transfer { xfer; };
	};

	zone "100.168.192.in-addr.arpa" {
		type master;
		file "pri/192.168.100.internal";
		allow-transfer { xfer; };
	};
};
EOF
  elif [ "${DNSTYPE}" = "slave" ];
  then
    cat >> ${FILE} << EOF
view "internal" {
	match-clients { 192.168.100.0/24; localhost; };
	recursion yes;

	zone "virtdomain.com" {
		type slave;
		file "pri/virtdomain.com.internal";
		masters {@MASTER@;};
	};

	zone "virt-domain.com" {
		type slave;
		file "pri/virt-domain.com.internal";
		masters {@MASTER@;};
	};

	zone "100.168.192.in-addr.arpa" {
		type slave;
		file "pri/192.168.100.internal";
		masters {@MASTER@;};
	};
};
EOF
    sed -i -e "s:@MASTER@:$(getValue dns.master):g" ${FILE};
  fi
  applyMetaOnFile ${FILE} ${META};
  commitChangeFile ${FILE} ${META};
  logMessage "done\n";

  if [ "$(getValue dns.type)" = "master" ];
  then
    logMessage "  > Configuring virtdomain.com.internal zone file... ";
    FILE="/var/bind/pri/virtdomain.com.internal";
    touch ${FILE};
    META=$(initChangeFile ${FILE});
    cat > /var/bind/pri/virtdomain.com.internal << EOF
\$TTL 1200 
@	IN SOA	ns.virtdomain.com.	admin.virtdomain.com. (
	2011061001	; serial
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
postgres.virtdomain.com.	IN A	192.168.100.52
www1.virtdomain.com.	IN A	192.168.100.61
www2.virtdomain.com.	IN A	192.168.100.62
ldap1.virtdomain.com.	IN A	192.168.100.55
ldap2.virtdomain.com.	IN A	192.168.100.56
ldap.virtdomain.com.	IN A	192.168.100.55
			IN A	192.168.100.56
mail1.virtdomain.com.	IN A	192.168.100.51
build.virtdomain.com.	IN A	192.168.100.50
rsync.virtdomain.com.	IN CNAME build.virtdomain.com.
proxy.virtdomain.com.	IN A	192.168.100.63
zabbix.virtdomain.com.	IN A	192.168.100.64
EOF
    applyMetaOnFile ${FILE} ${META};
    commitChangeFile ${FILE} ${META};
    logMessage "done\n";

    logMessage "  > Configuring virt-domain.com.internal zone file... ";
    FILE="/var/bind/pri/virt-domain.com.internal";
    touch ${FILE};
    META=$(initChangeFile ${FILE});
    cat > /var/bind/pri/virt-domain.com.internal << EOF
\$TTL 1200 
@	IN SOA	ns.virt-domain.com.	admin.virt-domain.com. (
	2011061001	; serial
	3h		; refresh
	1h		; retry
	1w		; expiry
	1d )		; minimum

virt-domain.com.		IN MX	0	mail1.virtdomain.com.
virt-domain.com.		IN TXT	"v=spf1 ip4:192.168.100.71/32 mx ptr mx:mail1.virtdomain.com ~all"
virt-domain.com.		IN NS	ns1.virtdomain.com.
virt-domain.com.		IN NS	ns2.virtdomain.com.
ns1.virt-domain.com.	IN A	192.168.100.71
ns2.virt-domain.com.	IN A	192.168.100.72
EOF
    applyMetaOnFile ${FILE} ${META};
    commitChangeFile ${FILE} ${META};
    logMessage "done\n";

    logMessage "  > Configuring 192.168.100.internal zone file... ";
    FILE="/var/bind/pri/192.168.100.internal";
    touch ${FILE};
    META=$(initChangeFile ${FILE});
    cat > /var/bind/pri/192.168.100.internal << EOF
\$TTL 1200
@	IN SOA	ns.virtdomain.com.	admin.virtdomain.com. (
	2011061001	; serial
	3h		; refresh
	1h		; retry
	1w		; expiry
	1d )		; minimum

100.168.192.in-addr.arpa.	IN	NS	ns1.virtdomain.com.
100.168.192.in-addr.arpa.	IN	NS	ns1.virtdomain.com.
71.100.168.192.in-addr.arpa.	IN	PTR	ns1.virtdomain.com.
72.100.168.192.in-addr.arpa.	IN	PTR	ns2.virtdomain.com.
52.100.168.192.in-addr.arpa.	IN	PTR	postgres.virtdomain.com.
61.100.168.192.in-addr.arpa.	IN	PTR	www1.virtdomain.com.
62.100.168.192.in-addr.arpa.	IN	PTR	www2.virtdomain.com.
55.100.168.192.in-addr.arpa.	IN	PTR	ldap1.virtdomain.com.
56.100.168.192.in-addr.arpa.	IN	PTR	ldap2.virtdomain.com.
51.100.168.192.in-addr.arpa.	IN	PTR	mail1.virtdomain.com.
50.100.168.192.in-addr.arpa.	IN	PTR	build.virtdomain.com.
63.100.168.192.in-addr.arpa.	IN	PTR	proxy.virtdomain.com.
64.100.168.192.in-addr.arpa.	IN	PTR	zabbix.virtdomain.com.
EOF
    applyMetaOnFile ${FILE} ${META};
    commitChangeFile ${FILE} ${META};
    logMessage "done\n";
  fi

  if [ "$(getValue dns.type)" = "slave" ];
  then
    logMessage "  > Allowing slave to write master zone information locally... ";
    chmod g+w /var/bind/pri /var/bind/sec;
    setsebool -P named_write_master_zones on;
    logMessage "done\n";
  fi
}

setuppam() {
  _setuppam;
}

setupzabbix() {
  _setupzabbix;
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

stepOK "setuppam" && (
logMessage ">>> Step \"setuppam\" starting...\n";
runStep setuppam;
);
nextStep;

stepOK "setupzabbix" && (
logMessage ">>> Step \"setupzabbix\" starting...\n";
runStep setupzabbix;
);
nextStep;

cleanupTools;
rm ${FAILED};
