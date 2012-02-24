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

installSoftware() {
  emerge --binpkg-respect-use=y -g $*;
}

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
  echo "${STEPS}" | grep "\(^\| \)${STEPFROM}" > /dev/null 2>&1;
  if [ $? -ne 0 ];
  then
    # Check if last step
    [ "x${STEPTO}" = "x" ] && return 0;
    echo "${STEPS}" | grep "\(^\| \)${STEPTO}" > /dev/null 2>&1;
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

logTestMessage() {
  printf "%-8s - %-3s - %-53s - \n" $1 "$2" "$3" >> ${LOG};
  printf "%-8s - %-3s - %-53s - " $1 "$2" "$3" >&3;
}

logMessage() {
  printf "$*\n" >> ${LOG};
  printf "$*" >&3;
}

logOK() {
  logMessage "success\n";
}

logNOK() {
  logMessage "failed!\n";
}

getValue() {
  typeset KEY="$1";
  typeset RETVAL="";

  RETVAL=$(grep "^${KEY}=" ${CONFFILE} | sed -e 's:^[^=]*=::g';);
  FIRSTTWOCHAR=$(echo ${RETVAL} | sed -e 's:\(..\).*:\1:g');
  FIRSTTHREECHAR=$(echo ${RETVAL} | sed -e 's:\(...\).*:\1:g');
  if [ "${FIRSTTWOCHAR}" = "%_" ];
  then
    KEY=$(echo ${RETVAL} | sed -e 's:%_::g');
    RETVAL=$(getValue ${KEY});
  elif [ "${FIRSTTHREECHAR}" = "%%_" ];
  then
    RETVAL=$(echo ${RETVAL} | sed -e 's:^%%_:%_:g');
  fi
  echo ${RETVAL};
}

listSectionOverview() {
  SECTION="$1";
  FIELD=$(echo ${SECTION} | sed -e 's:[^\.]::g' | wc -c);	# Is number of .'s + 1
  FIELD=$((${FIELD}+1));

  grep "^${SECTION}." ${CONFFILE} | sed -e 's:=:\.:g' | awk -F'.' '{print $'${FIELD}'}' | sort | uniq;
}

initChangeFile() {
  typeset FILENAME=$1;
  typeset METAFILE=$(mktemp ${FILENAME}.meta-XXXXXX);
  typeset BACKUPFILE=$(mktemp ${FILENAME}.backup-XXXXXX);

  if [ ! -w ${FILENAME} ];
  then
    die "File ${FILENAME} does not exist or is not writeable.";
  fi

  typeset USER=$(stat --format '%U' ${FILENAME});
  typeset GROUP=$(stat --format '%G' ${FILENAME});
  typeset ACCESS=$(stat --format '%a' ${FILENAME});

  cp ${FILENAME} ${BACKUPFILE};

  echo "Backup ${BACKUPFILE}" > ${METAFILE};
  echo "Unix User ${USER}" >> ${METAFILE};
  echo "Unix Group ${GROUP}" >> ${METAFILE};
  echo "Unix Access ${ACCESS}" >> ${METAFILE};
  if [ -x /usr/bin/secon ] && [ -x /usr/sbin/sestatus ];
  then
    typeset SESTATUS=$(sestatus | awk '/^SELinux status/ { print $3}');
    if [ "${SESTATUS}" != "disabled" ];
    then
      secon -f ${FILENAME} | sed -e 's:^:SELinux :g' | sed -e 's:\:::g' >> ${METAFILE};
    fi
  fi

  echo ${METAFILE};
}

commitChangeFile() {
  typeset FILENAME=$1;
  typeset METAFILE=$2;

  typeset BACKUPFILE=$(awk '/^Backup/ {print $2}' ${METAFILE});

  rm ${BACKUPFILE} || die "Backup file ${BACKUPFILE} could not be found";
  rm ${METAFILE} || die "Meta file ${METAFILE} could not be found";
}

revertChangeFile() {
  typeset FILENAME=$1;
  typeset METAFILE=$2;

  typeset BACKUPFILE=$(awk '/^Backup/ {print $2}' ${METAFILE});

  rm ${FILENAME};
  mv ${BACKUPFILE} ${FILENAME};

  applyMetaOnFile ${FILENAME} ${METAFILE};

  rm ${METAFILE};
}

applyMetaOnFile() {
  typeset FILENAME=$1;
  typeset METAFILE=$2;

  typeset USER=$(awk '/^Unix User / {print $3}' ${METAFILE});
  typeset GROUP=$(awk '/^Unix Group / {print $3}' ${METAFILE});
  typeset ACCESS=$(awk '/^Unix Access / {print $3}' ${METAFILE});

  chown ${USER}:${GROUP} ${FILENAME} || die "Failed to restore ownership";
  chmod ${ACCESS} ${FILENAME} || die "Failed to restore permissions";

  if [ -x /usr/bin/secon ] && [ -x /usr/sbin/sestatus ];
  then
    typeset SESTATUS=$(sestatus | awk '/^SELinux status/ { print $3}');
    if [ "${SESTATUS}" != "disabled" ];
    then
      typeset SE_USER=$(awk '/SELinux user / {print $3}' ${METAFILE});
      typeset SE_ROLE=$(awk '/SELinux role / {print $3}' ${METAFILE});
      typeset SE_TYPE=$(awk '/SELinux type / {print $3}' ${METAFILE});

      chcon -u ${SE_USER} -r ${SE_ROLE} -t ${SE_TYPE} ${FILENAME} || die "Failed to restore SELinux info";
    fi
  fi
}

setOrUpdateQuotedVariable() {
  VARIABLE=$1;
  SPACER="$2";
  VALUE="$3";
  FILE=$4;

  TESTER="${SPACER}";

  if [ "${SPACER}" = " " ];
  then
    TESTER="[ 	]";
  fi

  grep "^[ ]*${VARIABLE}${TESTER}" ${FILE} > /dev/null 2>&1;
  if [ $? -eq 0 ];
  then
    sed -i -e "s|^\([ ]*\)${VARIABLE}${TESTER}.*|\1${VARIABLE}${SPACER}\"${VALUE}\"|g" ${FILE};
  else
    echo "${VARIABLE}${SPACER}\"${VALUE}\"" >> ${FILE};
  fi
}

setOrUpdateUnquotedVariable() {
  VARIABLE=$1;
  SPACER="$2";
  VALUE="$3";
  FILE=$4;

  TESTER="${SPACER}";

  if [ "${SPACER}" = " " ];
  then
    TESTER="[ 	]";
  fi
    
  grep "^[ ]*${VARIABLE}${TESTER}" ${FILE} > /dev/null 2>&1;
  if [ $? -eq 0 ];
  then
    # Preserve indentation
    sed -i -e "s|^\([ ]*\)${VARIABLE}${TESTER}.*|\1${VARIABLE}${SPACER}${VALUE}|g" ${FILE};
  else
    echo "${VARIABLE}${SPACER}${VALUE}" >> ${FILE};
  fi
}

# updateEqualConfFile - Update the given configuration file
#
# Arguments:
#   arg1 = section within the setup configuration file (a.b.c.d)
#   arg2 = target configuration file to update
#
# The updateEqualConfFile will substitute the variables as given in the
# configuratino file (a.b.c.d.KEYWORD) in the configuration file to the
# new value. The value is automatically quoted (KEY="VALUE") unless the
# value starts with (, like in KEY=(foo bar bleh) to support arrays.
updateEqualConfFile() {
  SECTION="$1";
  FILE="$2";

  VARIABLES=$(listSectionOverview ${SECTION});
  
  for VARIABLE in ${VARIABLES};
  do
    VALUE=$(getValue ${SECTION}.${VARIABLE});
    FIRSTCHAR=$(echo ${VALUE} | sed -e 's:\(.\).*:\1:g');
    if [ "${FIRSTCHAR}" = "(" ];
    then
      setOrUpdateUnquotedVariable ${VARIABLE} "=" "${VALUE}" ${FILE};
    else
      setOrUpdateQuotedVariable ${VARIABLE} "=" "${VALUE}" ${FILE};
    fi
  done
}

# updateEqualNoQuotConfFile - Update the given configuration file
#
# Arguments:
#   arg1 = section within the setup configuration file (a.b.c.d)
#   arg2 = target configuration file to update
#
# The updateEqualNoQuotConfFile will substitute the variables as given in the
# configuratino file (a.b.c.d.KEYWORD) in the configuration file to the
# new value. The value is automatically quoted (KEY="VALUE") unless the
# value starts with (, like in KEY=(foo bar bleh) to support arrays.
updateEqualNoQuotConfFile() {
  SECTION="$1";
  FILE="$2";

  VARIABLES=$(listSectionOverview ${SECTION});
  
  for VARIABLE in ${VARIABLES};
  do
    VALUE=$(getValue ${SECTION}.${VARIABLE});
    setOrUpdateUnquotedVariable ${VARIABLE} "=" "${VALUE}" ${FILE};
  done
}


# updateWhitespaceNoQuotConfFile - Update the given configuration file
#
# Arguments:
#   arg1 = section within the setup configuration file (a.b.c.d)
#   arg2 = target configuration file to update
#
# The updateEqualNoQuotConfFile will substitute the variables as given in the
# configuratino file (a.b.c.d.KEYWORD) in the configuration file to the
# new value. The value is not quoted
updateWhitespaceNoQuotConfFile() {
  SECTION="$1";
  FILE="$2";

  VARIABLES=$(listSectionOverview ${SECTION});
  
  for VARIABLE in ${VARIABLES};
  do
    VALUE=$(getValue ${SECTION}.${VARIABLE});
    setOrUpdateUnquotedVariable  ${VARIABLE} " " "${VALUE}" ${FILE};
  done
}

# updateWhitespaceConfFile - Update the given configuration file
#
# Arguments:
#   arg1 = section within the setup configuration file (a.b.c.d)
#   arg2 = target configuration file to update
#
# The updateWhitespaceConfFile will substitute the variables as given in the
# configuratino file (a.b.c.d.KEYWORD) in the configuration file to the
# new value. The value is quoted
updateWhitespaceConfFile() {
  SECTION="$1";
  FILE="$2";

  VARIABLES=$(listSectionOverview ${SECTION});
  
  for VARIABLE in ${VARIABLES};
  do
    VALUE=$(getValue ${SECTION}.${VARIABLE});
    setOrUpdateQuotedVariable  ${VARIABLE} " " "${VALUE}" ${FILE};
  done
}


# Deprecated, use updateEqualConfFile
updateConfFile() {
  updateEqualConfFile $1 $2;
}

