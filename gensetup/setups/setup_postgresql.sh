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

typeset STEPS="configsystem installdb configdb labelfiles setuppam setupzabbix";
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
