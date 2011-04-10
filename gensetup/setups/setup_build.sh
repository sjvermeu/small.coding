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

typeset STEPS="configsystem configureportage installsoftware setuplighttpd";
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
  die "Please restart the system and continue with step configureportage.";
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

  logMessage "  > Run restorecon on packages folder... ";
  restorecon -R /var/www/localhost/htdocs;
  logMessage "done\n";
}

stepOK "configsystem" && (
logMessage ">>> Step \"configsystem\" starting...\n";
runStep configsystem;
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

cleanupTools;
rm ${FAILED};
