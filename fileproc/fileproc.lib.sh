#!/bin/sh

PATH="${PATH}:.";

# Retrieve a setting from the configuration file
getSetting() {
  if [ -f ${HOME}/.fileproc.rc ];
  then
    awk -F '=' "/${1}[ 	]*=/ {print \$2}" ${HOME}/.fileproc.rc | sed -e 's:^[ 	]*::g';
  fi
}

# Check if a filename matches the given expression
filevalid() {
  EXPRESSION="$1";
  FILENAME="$2";
  RULE="$3";
  RUNDIR=$(getSetting rundir);

  if [ -f ${RUNDIR}/${FILENAME}.${RULE}.run ];
  then
    return 1;
  fi

  echo ${FILENAME} | grep -e ${EXPRESSION} > /dev/null 2>&1;
  return $?;
};

# Lock file
lock() {
  LOCKNAME=$1;
  LOCKDIR=$(getSetting lockdir);
  LOCKNUM=$(getSetting locktimeout);
  LOCKVALUE=0;

  while [ ${LOCKVALUE} -ne $$ ];
  do 
    ln -s $$ ${LOCKDIR}/${LOCKNAME}.lock > /dev/null 2>&1;
    LOCKVALUE=$(ls -l ${LOCKDIR}/${LOCKNAME}.lock | awk -F' ' '{print $NF}');
    if [ ${LOCKVALUE} -ne $$ ];
    then
      LOCKNUM=$((${LOCKNUM}-1));
      sleep 1;
    fi
    if [ ${LOCKNUM} -le 0 ];
    then
      echo "Failed to get lock ${LOCKNAME} (value is ${LOCKVALUE} but expected $$).";
      echo "Please check ${LOCKDIR}/${LOCKNAME}.lock.";
      exit 1;
    fi
  done
}

# Unlock file
unlock() {
  LOCKNAME=$1;
  LOCKDIR=$(getSetting lockdir);
  LOCKVALUE=$(ls -l ${LOCKDIR}/${LOCKNAME}.lock | awk -F' ' '{print $NF}');

  if [ ${LOCKVALUE} -ne $$ ];
  then
    echo "Tried to free lock ${LOCKNAME} but was not mine (value is ${LOCKVALUE} but expected $$) !!";
    exit 1;
  else
    rm ${LOCKDIR}/${LOCKNAME}.lock;
  fi
}

fileproc_sourced() {
  return 87;
};
