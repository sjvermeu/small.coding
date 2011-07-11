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

typeset STEPS="inittest portage exittest";
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

inittest() {
  return
}

portage() {
  logTestMessage portage 001 "Run emerge --info";
  emerge --info | grep -q '^SYNC="' && logOK || logNOK;

  logTestMessage portage 002 "Run emerge -puDN world";
  emerge -puDN world && logOK || logNOK;

  logTestMessage portage 003 "Run emerge cowsay";
  rm /usr/portage/distfiles/cowsay* > /dev/null 2>&1;
  emerge cowsay && logOK || logNOK;

  logTestMessage portage 004 "Run emerge -C cowsay (remove)";
  emerge -C cowsay && logOK || logNOK;

  logTestMessage portage 005 "Run eselect profile list";
  eselect profile list && logOK || logNOK;

  logTestMessage portage 006 "Run gcc-config -l";
  gcc-config -l && logOK || logNOK;
}

exittest() {
  return
}

stepOK "inittest" && (
logTestMessage inittest "- -" "(No need to initialize tests)";
logMessage "\n";
runStep inittest;
);
nextStep;

stepOK "portage" && (
logTestMessage portage "- -" "Performing portage activities";
logMessage "\n";
runStep portage;
);
nextStep;

stepOK "exittest" && (
logTestMessage exittest "- -" "(No need to clean up tests)";
logMessage "\n";
runStep exittest;
);
nextStep;

cleanupTools;
rm ${FAILED};
