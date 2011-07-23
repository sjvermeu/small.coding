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

typeset STEPS="configsystem setuppam setupzabbix";
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
