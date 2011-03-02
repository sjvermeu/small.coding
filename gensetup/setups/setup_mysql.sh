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

typeset STEPS="installdb configdb startdb";
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

installdb() {
  logMessage "  > Installing 'mysql'... ";
  installSoftware -u mysql || die "Failed to install MySQL (emerge failed)";
  logMessage "done\n";
}

configdb() {
  typeset DBVERS=$(ls -d /var/db/pkg/dev-db/mysql-[0-9]*.* | sed -e 's:.*dev-db/::g');
  logMessage "  > Running \"emerge --config =dev-db/${DBVERS}... ";
  MYSQL_ROOT_PASSWORD=$(getValue mysql.rootpassword);
  if [ -f /root/.my.cnf ];
  then
    die "File /root/.my.cnf exists. Remove and retry please.";
  fi
  echo "password=${MYSQL_ROOT_PASSWORD}" >> /root/.my.cnf;
  installSoftware --config =dev-db/${DBVERS} || die "Failed to configure MySQL";
  rm /root/.my.cnf;
  logMessage "done\n";
}

startdb() {
  die "Please start MySQL (/etc/init.d/mysql start). No further actions needed then.";
}

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

stepOK "startdb" && (
logMessage ">>> Step \"startdb\" starting...\n";
runStep startdb;
);
nextStep;

cleanupTools;
rm ${FAILED};
