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

typeset STEPS="configurenet configureportage installsoftware setuplighttpd setupsystem";
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

configurenet() {
  logMessage "  > Updating /etc/conf.d/net... ";
  typeset FILE=/etc/conf.d/net;
  typeset META=$(initChangeFile ${FILE});
  updateEqualNoQuotConfFile conf.net ${FILE};
  applyMetaOnFile ${FILE} ${META};
  commitChangeFile ${FILE} ${META};
  logMessage "done\n";

  logMessage "  > Updating /etc/conf.d/hostname... ";
  FILE=/etc/conf.d/hostname;
  META=$(initChangeFile ${FILE});
  updateEqualQuotConfFile conf.hostname ${FILE};
  applyMetaOnFile ${FILE} ${META};
  commitChangeFile ${FILE} ${META};
  logMessage "done\n";

  logMessage "  > Updating /etc/hosts... ";
  FILE=/etc/hosts;
  META=$(initChangeFile ${FILE});
  echo "127.0.0.1       localhost" > ${FILE};
  echo "$(getValue etc.hosts)"    >> ${FILE};
  applyMetaOnFile ${FILE} ${META};
  commitChangeFile ${FILE} ${META};
  logMessage "done\n";

  logMessage "  > Updating /etc/resolv.conf... ";
  FILE=/etc/resolv.conf
  META=$(initChangeFile ${FILE});
  echo "$(getValue etc.resolv)" > ${FILE};
  applyMetaOnFile ${FILE} ${META};
  commitChangeFile ${FILE} ${META};
  logMessage "done\n";

  logMessage "  > Editing 70-persistent-net.rules... ";
  FILE=/etc/udev/rules.d/70-persistent-net.rules;
  META=$(initChangeFile ${FILE});
  typeset MACA=$(ifconfig -a | awk '/eth/ {print $5}');
  sed -i -e "s|\(SUBSYSTEM.*ATTR{address}==\"\).*\(\", ATTR{dev_id}.*NAME=\"eth0\"\)|\1${MACA}\2|g" ${FILE};
  applyMetaOnFile ${FILE} ${META};
  commitChangeFile ${FILE} ${META};
  logMessage "done\n";
}

configureportage() {
  logMessage "  > Editing make.conf... ";
  typeset FILE=/etc/make.conf;
  typeset META=$(initChangeFile ${FILE});
  updateEqualQuotConfFile etc.makeconf ${FILE};
  applyMetaOnFile ${FILE} ${META};
  commitChangeFile ${FILE} ${META};
  logMessage "done\n";

  logMessage "  > Migrating packages... ";
  mkdir -p /var/www/localhost/htdocs/packages;
  mv /usr/portage/packages/* /var/www/localhost/htdocs/packages;
  restorecon -R -r /var/www;
  logMessage "done\n";
}

installsoftware() {
  for PACKAGE in $(getValue packages);
  do
    logMessage "  > Installing '${PACKAGE}'... ";
    installSoftware -u ${PACKAGE} || die "Failed to install ${PACKAGE} (emerge failed)";
    logMessage "done\n";
  done
}

setuplighttpd() {
  logMessage "  > Removing squirrelmail from install... ";
  webapp-config --li | grep -q "squirrelmail";
  if [ $? -eq 0 ];
  then
    webapp-config -C -h localhost -d squirrelmail || die "Failed running webapp-config for squirrelmail";
    logMessage "done\n";
  else
    logMessage "skipped\n";
  fi

  logMessage "  > Removing phpmyadmin from install... ";
  webapp-config --li | grep -q "phpmyadmin";
  if [ $? -eq 0 ];
  then
    webapp-config -C -h localhost -d phpmyadmin || die "Failed running webapp-config for phpmyadmin";
    logMessage "done\n";
  else
    logMessage "skipped\n";
  fi

  logMessage "  > Enabling auto-startup... ";
  rc-update add lighttpd default;
  logMessage "done\n";
}

setupsystem() {
  logMessage "  > Setting up swapspace (128M)... ";
  if [ ! -f /swapfile ];
  then
    dd if=/dev/zero of=/swapfile bs=1024k count=128;
    chcon -t swapfile_t /swapfile;
    mkswap /swapfile;
    swapon /swapfile;
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
}

stepOK "configurenet" && (
logMessage ">>> Step \"configurenet\" starting...\n";
runStep configurenet;
);
nextStep;

stepOK "configureportage" && (
logMessage ">>> Step \"configureportage\" starting...\n";
runStep configureportage;
);
nextStep;

stepOK "installsoftware" && (
logMessage ">>> Step \"installsoftware\" starting...\n";
runStep installsoftware;
);
nextStep;

stepOK "setuplighttpd" && (
logMessage ">>> Step \"setuplighttpd\" starting...\n";
runStep setuplighttpd;
);
nextStep;

stepOK "setupsystem" && (
logMessage ">>> Step \"setupsystem\" starting...\n";
runStep setupsystem;
);
nextStep;

cleanupTools;
rm ${FAILED};
