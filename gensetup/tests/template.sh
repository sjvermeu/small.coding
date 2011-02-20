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

typeset STEPS="one two three four";
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

stepOne() {
  echo "Yes";
  echo "No";
  echo "Maybe";
  logMessage "    - Decision made\n";
  sleep 2;
  echo "Hmmm...";
  echo "Not sure...";
  logMessage "    - Decision countered\n";
}

stepTwo() {
  printf "Thinking ";
  logMessage "    > Thinking ";
  sleep 1;
  printf "about ";
  logMessage "about ";
  sleep 1;
  printf "nothing.\n";
  logMessage "nothing\n";
  sleep 1;
}

stepThree() {
  echo "yes" && die "Failed to say \"yes\"";
}

stepFour() {
  echo "This should only be available if 3 is skipped!";
  logMessage "  If I'm started, then the previous step was skipped.\n";
}

stepOK "one" && (
logMessage ">>> Step \"one\" starting...\n";
runStep stepOne;
);
nextStep;

stepOK "two" && (
logMessage ">>> Step \"two\" starting...\n";
runStep stepTwo;
);
nextStep;

stepOK "three" && (
logMessage ">>> Step \"three\" starting...\n";
runStep stepThree;
);
nextStep;

stepOK "four" && (
logMessage ">>> Step \"four\" starting...\n";
runStep stepFour;
);
nextStep;

cleanupTools;
rm ${FAILED};
