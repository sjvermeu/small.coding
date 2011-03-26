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
# fetchIndex - Fetch the index file
#
fetchIndex() {
  typeset ONLINEDIR="$1";
  typeset SUITEDIR=$(mktemp -d ${TMPWORKDIR}/mgl_XXXXXXXX);

  pushd ${SUITEDIR} > /dev/null 2>&1;
  wget -q ${ONLINEDIR};
  popd > /dev/null 2>&1;

  echo ${SUITEDIR};
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
  typeset SPEED=$2;

  # Phase 1 - Look for the testset on the system
  for SOURCE in $(getKeyValue source.local ${MGLSHOWCONF});
  do
    if [ -f ${SOURCE}/${REPLAYSCRIPT}.session ];
    then
      executeReplayScript ${SOURCE}/${REPLAYSCRIPT} ${SPEED};
    fi
  done

  # Phase 2 - Look for the testset on web server locations
  for SOURCE in $(getKeyValue source.http ${MGLSHOWCONF});
  do
    hasReplayScript ${SOURCE}/${REPLAYSCRIPT}.session;
    if [ $? -eq 0 ];
    then
      typeset LOCALTEST=$(fetchReplayScript ${SOURCE}/${TESTSET});
      executeReplayScript ${LOCALTEST} ${SPEED};
      # Cleanup files
      cleanupFolder ${LOCALTEST};
    fi
  done
}

#
# showIndex - Show the current list of replayable activities
# 
showIndex() {
  typeset INDEXNAME=$1;

  # Phase 1 - Look for the index on the system
  for SOURCE in $(getKeyValue source.local ${MGLSHOWCONF});
  do
    if [ -f ${SOURCE}/${INDEXNAME}/INDEX ];
    then
      cat ${SOURCE}/${INDEXNAME}/INDEX;
    fi
  done

  # Phase 2 - Look for the testset on web server locations
  for SOURCE in $(getKeyValue source.http ${MGLSHOWCONF});
  do
    hasReplayScript ${SOURCE}/${INDEXNAME}/INDEX;
    if [ $? -eq 0 ];
    then
      typeset LOCALTEST=$(fetchIndex ${SOURCE}/${INDEXNAME}/INDEX);
      cat ${LOCALTEST}/INDEX;
      # Cleanup files
      cleanupFolder ${LOCALTEST};
    fi
  done
}


#
# executeReplayScript - Execute the test(s) in the testsuite
#
executeReplayScript() {
  typeset TESTDIR=$1;
  typeset SPEED=$2;
  typeset SESSIONSCRIPT=${TESTDIR}.session;
  typeset TIMINGSCRIPT=${TESTDIR}.timing;

  scriptreplay ${TIMINGSCRIPT} ${SESSIONSCRIPT} ${SPEED};
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
Usage: $0 <name> [<speed>]
       $0 -i [<category>]

<name> is the name of the replay session you want to execute. The sessions
are loaded from the location(s) that are stored in your ~/.mglshowrc file
(or in the file pointed towards by the MGLSHOWCONF environment variable).

<speed> is the optional speed factor in which the scriptreplay function 
should display the information. For instance, a <speed> value of 2 means
that the output is shown at twice the regular speed. 0.5 is half the regular
speed.

In case of -i, then the list of supported replays is shown (or categories
if there are subcategories). If a <category> is given, then the replays for
that particular category and its subcategories is shown.
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

if [ "$1" = "-i" ];
then
  showIndex $2;
else
  runReplayScript $1 $2;
fi


