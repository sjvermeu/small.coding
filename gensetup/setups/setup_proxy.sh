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

typeset STEPS="configsystem installsquid installprivoxy configsquid configprivoxy setuppam setupzabbix finalize";
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
  die "Please restart the network and continue with step installsquid.";
}

installsquid() {
  logMessage "  > Installing 'squid'... ";
  installSoftware -u squid || die "Failed to install Squid (emerge failed)";
  logMessage "done\n";

  logMessage "  > Adding squid to default runlevel... ";
  rc-update add squid default
  logMessage "done\n";
}

installprivoxy() {
  logMessage "  > Installing 'privoxy'... ";
  installSoftware -u privoxy || die "Failed to install privoxy (emerge failed)";
  logMessage "done\n";

  logMessage "  > Adding privoxy to default runlevel... ";
  rc-update add privoxy default
  logMessage "done\n";
}

configsquid() {
  # If not created, /etc/init.d/squid wants to create it but the policy
  # dictates that initrc can't.
  logMessage "  > Creating cache directory for init... ";
  mkdir -p /var/cache/squid/00 || die "Failed to create cache location";
  chown squid:squid /var/cache/squid/00 || die "Failed to change ownership of cache location";
  logMessage "done\n";

  logMessage "  > Setting cache location... ";
  typeset FILE=/etc/squid/squid.conf;
  typeset META=$(initChangeFile ${FILE});
  setOrUpdateUnquotedVariable cache_dir " " "ufs /var/cache/squid 256 16 256" ${FILE};
  setOrUpdateUnquotedVariable shutdown_lifetime " " "5 seconds" ${FILE};
  applyMetaOnFile ${FILE} ${META};
  commitChangeFile ${FILE} ${META};
  logMessage "done\n";

  logMessage "  > Setting the cache label... ";
  restorecon -R /var/cache/squid;
  logMessage "done\n";
}

configprivoxy() {
  logMessage "  > Updating 'config' file... ";
  typeset FILE=/etc/privoxy/config;
  typeset META=$(initChangeFile ${FILE});
  setOrUpdateUnquotedVariable listen-address " " 0.0.0.0:8118 ${FILE};
  applyMetaOnFile ${FILE} ${META};
  commitChangeFile ${FILE} ${META};
  logMessage "done\n";

  logMessage "  > Blocking cnn.com... ";
  FILE=/etc/privoxy/user.action;
  META=$(initChangeFile ${FILE});
  grep -v GENSETUP_ADDED ${FILE} > ${FILE}.new;
  echo "{ +block{News Portals are not allowed}} #GENSETUP_ADDED" >> ${FILE}.new;
  echo ".cnn.com #GENSETUP_ADDED" >> ${FILE}.new;
  mv ${FILE}.new ${FILE};
  applyMetaOnFile ${FILE} ${META};
  commitChangeFile ${FILE} ${META};
  logMessage "done\n";
}

setuppam() {
  _setuppam;
}

setupzabbix() {
  _setupzabbix;
}

finalize() {
  logMessage "  > Creating cache directory (by squid).\n";
  LogMessage "    Please run 'run_init squid -z'.\n"
}

stepOK "configsystem" && (
logMessage ">>> Step \"configsystem\" starting...\n";
runStep configsystem;
);
nextStep;

stepOK "installsquid" && (
logMessage ">>> Step \"installsquid\" starting...\n";
runStep installsquid;
);
nextStep;

stepOK "installprivoxy" && (
logMessage ">>> Step \"installprivoxy\" starting...\n";
runStep installprivoxy;
);
nextStep;

stepOK "configsquid" && (
logMessage ">>> Step \"configsquid\" starting...\n";
runStep configsquid;
);
nextStep;

stepOK "configprivoxy" && (
logMessage ">>> Step \"configprivoxy\" starting...\n";
runStep configprivoxy;
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

stepOK "finalize" && (
logMessage ">>> Step \"finalize\" starting...\n";
runStep finalize;
);
nextStep;

cleanupTools;
rm ${FAILED};
