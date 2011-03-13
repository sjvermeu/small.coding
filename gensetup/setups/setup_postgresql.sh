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

typeset STEPS="configsystem installdb configdb labelfiles startdb";
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

initTools;


##
## Functions
##

configsystem() {
  logMessage "  > Updating /etc/conf.d/net... ";
  typeset FILE=/etc/conf.d/net;
  typeset META=$(initChangeFile ${FILE});
  updateEqualNoQuotConfFile conf.net ${FILE};
  applyMetaOnFile ${FILE} ${META};
  commitChangeFile ${FILE} ${META};
  logMessage "done\n";

  logMessage "  > Updating /etc/conf.d/hostname... ";
  typeset FILE=/etc/conf.d/hostname;
  typeset META=$(initChangeFile ${FILE});
  updateEqualNoQuotConfFile conf.hostname ${FILE};
  applyMetaOnFile ${FILE} ${META};
  commitChangeFile ${FILE} ${META};
  logMessage "done\n";

  logMessage "  > Setting hostname... ";
  hostname $(getValue conf.hostname.HOSTNAME);
  logMessage "done\n";

  logMessage "  > Updating /etc/resolv.conf... ";
  FILE=/etc/resolv.conf;
  META=$(initChangeFile ${FILE});
  echo "$(getValue sys.resolv)" > ${FILE};
  applyMetaOnFile ${FILE} ${META};
  commitChangeFile ${FILE} ${META};
  logMessage "done\n";

  logMessage "  > Updating 70-persistent-net.rules... ";
  FILE=/etc/udev/rules.d/70-persistent-net.rules;
  META=$(initChangeFile ${FILE});
  typeset MACA=$(ifconfig -a | awk '/eth/ {print $5}');
  sed -i -e "s|\(SUBSYSTEM.*ATTR{address}==\"\).*\(\", ATTR{dev_id}.*NAME=\"eth0\"\)|\1${MACA}\2|g" ${FILE};
  applyMetaOnFile ${FILE} ${META};
  commitChangeFile ${FILE} ${META};
  logMessage "done\n";

  logMessage "  > Updating /etc/hosts... ";
  FILE=/etc/hosts;
  META=$(initChangeFile ${FILE});
  echo "127.0.0.1     localhost" > ${FILE};
  echo "$(getValue sys.hosts)"  >> ${FILE};
  applyMetaOnFile ${FILE} ${META};
  commitChangeFile ${FILE} ${META};
  logMessage "done\n";

  logMessage "  > Updating /etc/make.conf... ";
  FILE=/etc/make.conf;
  META=$(initChangeFile ${FILE});
  updateEqualConfFile sys.makeconf ${FILE};
  applyMetaOnFile ${FILE} ${META};
  commitChangeFile ${FILE} ${META};
  logMessage "done\n";

  logMessage "  > Setting up swapspace (128M)... ";
  if [ ! -f /swapfile ];
  then
    dd if=/dev/zero of=/swapfile bs=1024k count=128;
    chcon -t swapfile_t /swapfile;
    mkswap /swapfile;
    swapon /swapfile;
    logMessage "done\n";
  else
    logMessage "skipped\n";
  fi

  logMessage "  > Configuring fstab... ";
  grep -q '/swapfile' /etc/fstab;
  if [ $? -ne 0 ];
  then
    typeset FILE=/etc/fstab;
    typeset META=$(initChangeFile ${FILE});
    echo "/swapfile	none	swap	sw	0 0" >> /etc/fstab
    applyMetaOnFile ${FILE} ${META};
    commitChangeFile ${FILE} ${META};
    logMessage "done\n";
  else
    logMessage "skipped\n";
  fi

  die "Please restart networking and continue with step installdb.";
}

installdb() {
  logMessage "  > Installing 'postgresql-server'... ";
  installSoftware -u postgresql-server || die "Failed to install PostgreSQL (emerge failed)";
  logMessage "done\n";

  logMessage "  > Adding postgresql-9.0 to default runlevel... ";
  rc-update add postgresql-9.0 default
  logMessage "done\n";
}

configdb() {
  typeset DBVERS=$(ls -d /var/db/pkg/dev-db/postgresql-server-[0-9]*.* | sed -e 's:.*dev-db/::g');
  logMessage "  > Temporary setting postgres password... ";
  typeset PGPW=$(echo ${RANDOM} | md5sum | cut -c1-12);
  printf "${PGPW}\n${PGPW}\n" | passwd postgres || die "Failed to set password";
  logMessage "done\n";

  logMessage "  > Running \"emerge --config =dev-db/${DBVERS}... ";
  printf "y\n${PGPW}\n" | installSoftware --config =dev-db/${DBVERS} || die "Failed to configure PostgreSQL";
  logMessage "done\n";

  logMessage "  > Locking postgres account... ";
  passwd -l postgres || die "Failed to lock postgres account";
  logMessage "done\n";
}

labelfiles() {
  logMessage "  > (Re)labelling database cluster files... ";
  restorecon -R /var/lib/postgresql || die "Failed to relabel files";
  logMessage "done\n";
}

startdb() {
  logMessage "** Run the following commands to initialize the database:\n";
  logMessage "**   /etc/init.d/postgresql-* start\n";
  die "Please follow above manual commands. No further actions needed then.";
}

stepOK "configsystem" && (
logMessage ">>> Step \"configsystem\" starting...\n";
runStep configsystem;
);
nextStep;

stepOK "installdb" && (
logMessage ">>> Step \"installdb\" starting...\n";
runStep installdb;
);
nextStep;

stepOK "configdb" && (
logMessage ">>> Step \"configdb\" starting...\n";
runStep configdb;
);
nextStep;

stepOK "labelfiles" && (
logMessage ">>> Step \"labelfiles\" starting...\n";
runStep labelfiles;
);
nextStep;

stepOK "startdb" && (
logMessage ">>> Step \"startdb\" starting...\n";
runStep startdb;
);
nextStep;

cleanupTools;
rm ${FAILED};
