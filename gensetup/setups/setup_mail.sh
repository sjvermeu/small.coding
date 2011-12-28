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

typeset STEPS="configsystem setuppostfix setuppam";
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

setuppostfix() {
  logMessage "  > Installing 'postfix'... ";
  installSoftware -u postfix || die "Failed to install Postfix (emerge failed)";
  logMessage "done\n";

  logMessage "  > Updating main.cf... ";
  updateEqualNoQuotConfFile postfix.main /etc/postfix/main.cf;
  logMessage "done\n";

  logMessage "  > Setup aliases... ";
  postalias /etc/mail/aliases > /dev/null 2>&1;
  logMessage "done\n";

  logMessage "::: Start postfix service (it will fail)\n";
  logMessage "::: Run restorecon -R /var\n";
  logMessage "::: Start postfix service again (should succeed)\n";
}

setuppam() {
  _setuppam;
}

stepOK "configsystem" && (
logMessage ">>> Step \"configsystem\" starting...\n";
runStep configsystem;
);
nextStep;

stepOK "setuppostfix" && (
logMessage ">>> Step \"setuppostfix\" starting...\n";
runStep setuppostfix;
);
nextStep;

stepOK "setuppam" && (
logMessage ">>> Step \"setuppam\" starting...\n";
runStep setuppam;
);
nextStep;

cleanupTools;
rm ${FAILED};
