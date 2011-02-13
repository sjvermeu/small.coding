#!/bin/sh

##
## Master library
##
## This file contains all main functions used by the update scripts.
##
#
# Licensed under GPL-3
#
# To use this file, first declare / export the following variables:
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

die() {
  echo "!!! $*" >&3;
  rm -f ${FAILED};
  exit 2;
}

stepOK() {
  STEP=$1;

  echo "Step ${STEP}, FROM=${STEPFROM}, TO=${STEPTO}, Failed=`test -f ${FAILED}; echo $?`, STEPS=${STEPS}" >> ${LOG};

  [ -f ${FAILED} ] || return 1;

  [ "x${STEPFROM}" = "x" ] && return 0;
  echo "${STEPS}" | grep " ${STEPFROM}" > /dev/null 2>&1;
  if [ $? -ne 0 ];
  then
    # Check if last step
    [ "x${STEPTO}" = "x" ] && return 0;
    echo "${STEPS}" | grep " ${STEPTO}" > /dev/null 2>&1;
    if [ $? -eq 0 ];
    then
      return 0;
    else
      return 1;
    fi
  else
    [ "${STEP}" = "${STEPFROM}" ] || return 1;
    return 0;
  fi
}

nextStep() {
  STEPS=" $(echo ${STEPS} | sed -e 's:^[^ ]* ::g')";
  if [ ! -f ${FAILED} ];
  then
    exit 2;
  fi
}

runStep() {
  $1 >> ${LOG} 2>&1;
}

initTools() {
  # Ensure CONFFILE points to a fully qualified path
  echo "${CONFFILE}" | grep '^/' > /dev/null 2>&1;
  if [ $? -ne 0 ];
  then
    CONFFILE="$(pwd)/${CONFFILE}";
    export CONFFILE;
  fi

  # Error handling
  if [ ! -f "${CONFFILE}" ];
  then
    echo "Usage: $0 <conffile> [<stepfrom> [<stepto>]]";
    echo "";
    echo "If <stepto> is given, the step itself is also executed.";
    echo "Supported steps: ${STEPS}";
    exit 1;
  fi
 
  # Strip all comments from the configuration file and reassign
  cat ${CONFFILE} | grep -v '^#' | sed -e 's:#.*::g' > ${CONFFILE}.parsed;
  CONFFILE=${CONFFILE}.parsed;

  # Initialize the 3rd file descriptor for logging purposes
  exec 3>&1;

  # Give timestamp in logging
  echo ">>> $(date +%Y%m%d-%H%M%S) - Starting log." >> ${LOG}; 
}

cleanupTools() {
  echo ">>> $(date +%Y%m%d-%H%M%S) - Stopping log." >> ${LOG}; 
  rm ${CONFFILE};
};

logMessage() {
  printf "$*" >&3;
}

getValue() {
  KEY="$1";

  grep "^${KEY}=" ${CONFFILE} | sed -e 's:^[^=]*::g';
}

listSectionOverview() {
  SECTION="$1";
  FIELD=$(echo ${SECTION} | sed -e 's:[^\.]::g' | wc -c);	# Is number of .'s + 1
  FIELD=$((${FIELD}+1));

  grep "^${SECTION}." ${CONFFILE} | sed -e 's:=:\.:g' | awk -F'.' '{print $'${FIELD}'}' | sort | uniq;
}

updateConfFile() {
  SECTION="$1";
  FILE="$2";

  VARIABLES=$(listSectionOverview ${SECTION});
  
  for VARIABLE in ${VARIABLES};
  do
    VALUE=$(awk -F'=' "/${SECTION}.${VARIABLE}=/ {print \$2}" ${CONFFILE});
    FIRSTCHAR=$(echo ${VALUE} | sed -e 's:\(.\).*:\1:g');
    if [ "${FIRSTCHAR}" = "(" ];
    then
      grep "^${VARIABLE}=" ${FILE} > /dev/null 2>&1;
      if [ $? -eq 0 ];
      then
        sed -i -e "s:^${VARIABLE}=.*:${VARIABLE}=${VALUE}:g" ${FILE};
      else
        echo "${VARIABLE}=${VALUE}" >> ${FILE};
      fi
    else
      grep "^${VARIABLE}=" ${FILE} > /dev/null 2>&1;
      if [ $? -eq 0 ];
      then
        sed -i -e "s:^${VARIABLE}=.*:${VARIABLE}=\"${VALUE}\":g" ${FILE};
      else
        echo "${VARIABLE}=\"${VALUE}\"" >> ${FILE};
      fi
    fi
  done
}

