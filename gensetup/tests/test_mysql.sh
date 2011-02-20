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

typeset STEPS="installdb configdb startdb createdb filldb createusers userok userfail dropuser droptable";
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
  emerge -pu mysql || die "Failed to install MySQL (emerge failed)";
  logMessage "done\n";
}

configdb() {
  typeset DBVERS=$(ls -d /var/db/pkg/dev-db/mysql-* | sed -e 's:.*dev-db/::g');
  logMessage "  > Running \"emerge --config =dev-db/${DBVERS}... ";
  MYSQL_ROOT_PASSWORD=$(getValue mysql.rootpassword);
  export MYSQL_ROOT_PASSWORD;
  emerge --config =dev-db/${DBVERS} || die "Failed to configure MySQL";
  logMessage "done\n";
}

startdb() {

}

createdb() {

}

filldb() {

}

createusers() {

}

userok() {

}

userfail() {

}

dropuser() {

}

dropdb() {

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

stepOK "createdb" && (
logMessage ">>> Step \"createdb\" starting...\n";
runStep createdb;
);
nextStep;

stepOK "filldb" && (
logMessage ">>> Step \"filldb\" starting...\n";
runStep filldb;
);
nextStep;

stepOK "createusers" && (
logMessage ">>> Step \"createusers\" starting...\n";
runStep createusers;
);
nextStep;

stepOK "userok" && (
logMessage ">>> Step \"userok\" starting...\n";
runStep userok;
);
nextStep;

stepOK "userfail" && (
logMessage ">>> Step \"userfail\" starting...\n";
runStep userfail;
);
nextStep;

stepOK "dropuser" && (
logMessage ">>> Step \"dropuser\" starting...\n";
runStep dropuser;
);
nextStep;

stepOK "dropdb" && (
logMessage ">>> Step \"dropdb\" starting...\n";
runStep dropdb;
);
nextStep;

cleanupTools;
rm ${FAILED};
