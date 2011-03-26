#!/bin/sh

##
## Global variables
##
## Yes, I know, global variables are considered evil. But seriously, 
## i'm hoping to keep this application as a simple shell script.
typeset TMPWORKDIR="";


#
# die - Finish off with a BANG
# 
die() {
  echo $* >&2
  exit 1;
}

#
# getKeyValue - Return the value for the given key in the given file
#
getKeyValue() {
  awk -F'=' "/^$1=/ {print \$2}" $2;
}

#
# hasKey - Check if the given file has the given key
#
hasKey() {
  grep -q "^${1}=" ${2};
}

#
# hasReplayScript - Test if the online resource holds a replay script
#
hasReplayScript() {
  typeset ONLINERES="$1";
  wget -q --spider "${ONLINERES}";
  return $?;
}

#
# fetchReplayScript - Fetch the session and timing scripts
#
fetchReplayScript() {
  typeset ONLINEDIR="$1";
  typeset SUITEDIR=$(mktemp -d ${TMPWORKDIR}/mgl_XXXXXXXX);
  
  pushd ${SUITEDIR} > /dev/null 2>&1;
  wget -q ${ONLINEDIR}.session;
  wget -q ${ONLINEDIR}.timing;
  popd > /dev/null 2>&1;

  echo ${SUITEDIR};
}

#
# cleanupFolder - Clean up temporary folder
#
cleanupFolder() {
  typeset DIR="${1}";

  [ ! -d "${DIR}" ] && die "Failed to clean up location ${DIR} - not a directory!";
  echo ${DIR} | grep -q '/mgl_[^/]*';
  if [ $? -eq 0 ];
  then
    rm -r "${DIR}";
  fi
}

#
# runReplayScript - Run the testset identified on the commandline
# 
runReplayScript() {
  typeset REPLAYSCRIPT=$1;

  # Phase 1 - Look for the testset on the system
  for SOURCE in $(getKeyValue source.local ${MGLSHOWCONF});
  do
    if [ -f ${SOURCE}/${REPLAYSCRIPT}.session ];
    then
      executeReplayScript ${SOURCE}/${REPLAYSCRIPT};
    fi
  done

  # Phase 2 - Look for the testset on web server locations
  for SOURCE in $(getKeyValue source.http ${MGLSHOWCONF});
  do
    hasReplayScript ${SOURCE}/${REPLAYSCRIPT}.session;
    if [ $? -eq 0 ];
    then
      typeset LOCALTEST=$(fetchTestSuite ${SOURCE}/${TESTSET});
      executeReplayScript ${LOCALTEST};
      # Cleanup files
      cleanupFolder ${LOCALTEST};
    fi
  done
}

#
# executeTest - Execute the test(s) in the testsuite
#
executeReplayScript() {
  typeset TESTDIR=$1;
  typeset SESSIONSCRIPT=${TESTDIR}.session;
  typeset TIMINGSCRIPT=${TESTDIR}.timing;

  scriptreplay ${TIMINGSCRIPT} ${SESSIONSCRIPT};
}

#
# readConfig - Parse the configuration file
#
readConfig() {
  if [ -n "${MGLSHOWCONF}" ] && [ -f ${MGLSHOWCONF} ];
  then
    hasKey workdir ${MGLSHOWCONF} || die "Key workdir is not found in the configuration file (${MGLSHOWCONF})!"
    TMPWORKDIR=$(getKeyValue workdir ${MGLSHOWCONF});
  elif [ -f ~/.mglshowrc ];
  then
    export MGLSHOWCONF=~/.mglshowrc
    hasKey workdir ${MGLSHOWCONF} || die "Key workdir is not found in the configuration file (${MGLSHOWCONF})!"
    TMPWORKDIR=$(getKeyValue workdir ${MGLSHOWCONF});
  else
    cat > ~/.mglshowrc << EOF
workdir=/tmp
source.http=http://swift.siphos.be/mglshow/data
EOF
    export MGLSHOWCONF=~/.mglshowrc
    hasKey workdir ${MGLSHOWCONF} || die "Key workdir is not found in the configuration file ${MGLSHOWCONF})!"
    TMPWORKDIR=$(getKeyValue workdir ${MGLSHOWCONF});
  fi
}

#
# usage - Display the command usage
#
usage() {
  cat << EOF
Usage: $0 <name>

Name is the name of the replay session you want to execute. The sessions are loaded
from the location(s) that are stored in your ~/.mglshowrc file (or in the 
file pointed towards by the MGLSHOWCONF environment variable).
EOF
}


##
## Main
##
if [ $# -lt 1 ] || [ $# -gt 2 ] || [ "$1" = "-h" ] || [ "$1" = "--help" ] || [ "$1" = "/?" ];
then
  usage;
  exit 0;
fi

readConfig

runReplayScript $1;


