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
# runTestSet - Run the testset identified on the commandline
# 
runTestSet() {
  typeset TESTSET=$1;

  # Phase 1 - Look for the testset on the system
  for SOURCE in $(getKeyValue source.local ${MGLVERIFYCONF});
  do
    if [ -f ${SOURCE}/${TESTSET}/testset ];
    then
      executeTest ${SOURCE}/${TESTSET};
    fi
  done

  # Phase 2 - Look for the testset on web server locations
  for SOURCE in $(getKeyValue source.http ${MGLVERIFYCONF});
  do
    hasTestSuite ${SOURCE}/${TESTSET}/testset;
    if [ $? -eq 0 ];
    then
      typeset LOCALTEST=$(fetchTestSuite ${SOURCE}/${TESTSET});
      executeTest ${LOCALTEST};
    fi
  done
}

#
# executeDescription - Show the description 
#
executeDescription() {
  typeset TESTLINE="$1";
  typeset TESTDIR="$2";

  typeset STRING=$(echo ${TESTLINE} |  sed -e 's:\\\::%_BaCkSlAsH||7:g' | awk -F':' '{print $2}' | sed -e 's:%_BaCkSlAsH||7:\\\::g');
  MGLFAILMESSAGE=$(echo ${TESTLINE} | sed -e 's:\\\::%_BaCkSlAsH||7:g' | awk -F':' '{print $3}' | sed -e 's:%_BaCkSlAsH||7:\\\::g');
  MGLFAILFILE=$(echo ${MGLFAILMESSAGE} | awk -F'/' '{print $1}');
  MGLFAILPART=$(echo ${MGLFAILMESSAGE} | awk -F'/' '{print $2}');
  export MGLFAILFILE;
  export MGLFAILPART;

  echo ${STRING};
}

#
# displayFailureMessage - Display the description' failure message, if applicable
#
displayFailureMessage() {
  typeset TESTDIR="$1";
  typeset MSGFILE="$2";
  typeset MSGPART="$3";

  if [ -n "${MGLFAILFILE}" ] && [ "${MGLVERBOSE}" = "yes" ];
  then
    if [ -n "${MGLFAILPART}" ];
    then
      awk "BEGIN {P=0} /\/topic ${MGLFAILPART}/ {P=1; next} /\/topic / {P=0} P==1 {print}" ${TESTDIR}/${MGLFAILFILE};
    else
      cat ${TESTDIR}/${MGLFAILFILE};
    fi
    MGLFAILFILE="";
    export MGLFAILFILE;
    MGLFAILPART="";
    export MGLFAILPART;
  fi

  if [ -n "${MSGPART}" ];
  then
    awk "BEGIN {P=0} /\/topic ${MSGPART}/ {P=1; next} /\/topic / {P=0} P==1 {print}" ${TESTDIR}/${MSGFILE};
  else
    cat ${TESTDIR}/${MSGFILE};
  fi
}

#
# executeFileRegexpTest - Execute a regexp matching test against a file
#
executeFileRegexpTest() {
  typeset TESTLINE="$1";
  typeset TESTDIR="$2";

  typeset FILENAME=$(echo ${TESTLINE} | sed -e 's:\\\::%_BaCkSlAsH||7:g' | awk -F':' '{print $3}' | sed -e 's:%_BaCkSlAsH||7:\\\::g');
  typeset EXPRESSION=$(echo ${TESTLINE} | sed -e 's:\\\::%_BaCkSlAsH||7:g' | awk -F':' '{print $4}' | sed -e 's:%_BaCkSlAsH||7:\\\::g');
  typeset OKMSG=$(echo ${TESTLINE} | sed -e 's:\\\::%_BaCkSlAsH||7:g' | awk -F':' '{print $5}' | sed -e 's:%_BaCkSlAsH||7:\\\::g');
  typeset FAILMSG=$(echo ${TESTLINE} | sed -e 's:\\\::%_BaCkSlAsH||7:g' | awk -F':' '{print $6}' | sed -e 's:%_BaCkSlAsH||7:\\\::g');

  grep -q "${EXPRESSION}" "${FILENAME}";
  if [ $? -eq 0 ];
  then
    if [ -n "${OKMSG}" ];
    then
      typeset MSGFILE=$(echo ${OKMSG} | awk -F'/' '{print $1}');
      typeset MSGPART=$(echo ${OKMSG} | awk -F'/' '{print $2}');

      displayFailureMessage "${TESTDIR}" "${MSGFILE}" "${MSGPART}";
    fi
  else
    if [ -n "${FAILMSG}" ];
    then
      typeset MSGFILE=$(echo ${FAILMSG} | awk -F'/' '{print $1}');
      typeset MSGPART=$(echo ${FAILMSG} | awk -F'/' '{print $2}');

      displayFailureMessage "${TESTDIR}" "${MSGFILE}" "${MSGPART}";
    fi
  fi
}

#
# executeFileTest - Execute a single FILE test
#
executeFileTest() {
  typeset TESTLINE="$1";
  typeset TESTDIR="$2";

  typeset TESTACTION=$(echo ${TESTLINE} | awk -F':' '{print $2}');

  case "${TESTACTION}" in
    [Rr][Ee][Gg][Ee][Xx][Pp])
      executeFileRegexpTest "${TESTLINE}" "${TESTDIR}";
      ;;
  esac;
}

#
# executeTest - Execute the test(s) in the testsuite
#
executeTest() {
  typeset TESTDIR=$1;
  typeset TESTSET=${TESTDIR}/testset;

  while read line
  do
    typeset TYPE=$(echo ${line} | awk -F':' '{print $1}');
    case "${TYPE}" in
      [Ff][Ii][Ll][Ee])
        executeFileTest "${line}" "${TESTDIR}";
	;;
      [Dd][Ee][Ss][Cc]|[Dd][Ee][Ss][Cc][Rr][Ii][Pp][Tt][Ii][Oo][Nn])
        executeDescription "${line}" "${TESTDIR}";
	;;
    esac
  done < ${TESTSET};
}

#
# readConfig - Parse the configuration file
#
readConfig() {
  if [ -n "${MGLVERIFYCONF}" ] && [ -f ${MGLVERIFYCONF} ];
  then
    hasKey workdir ${MGLVERIFYCONF} || die "Key workdir is not found in the configuration file (${MGLVERIFYCONF})!"
    TMPWORKDIR=$(getKeyValue workdir ${MGLVERIFYCONF});
  elif [ -f ~/.mglverifyrc ];
  then
    export MGLVERIFYCONF=~/.mglverifyrc
    hasKey workdir ${MGLVERIFYCONF} || die "Key workdir is not found in the configuration file (${MGLVERIFYCONF})!"
    TMPWORKDIR=$(getKeyValue workdir ${MGLVERIFYCONF});
  else
    cat > ~/.mglverifyrc << EOF
workdir=/tmp
source.http=http://swift.siphos.be/mglverify/data
EOF
    export MGLVERIFYCONF=~/.mglverifyrc
    hasKey workdir ${MGLVERIFYCONF} || die "Key workdir is not found in the configuration file ${MGLVERIFYCONF})!"
    TMPWORKDIR=$(getKeyValue workdir ${MGLVERIFYCONF});
  fi
}

#
# usage - Display the command usage
#
usage() {
  cat << EOF
Usage: $0 [-v] <name>

Name is the name of the testset you want to execute. The testsets are loaded
from the location(s) that are stored in your ~/.mglverifyrc file (or in the 
file pointed towards by the MGLVERIFYCONF environment variable).
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

if [ "$1" = "-v" ];
then
  export MGLVERBOSE="yes";
  runTestSet $2;
else
  export MGLVERBOSE="no";
  runTestSet $1;
fi


