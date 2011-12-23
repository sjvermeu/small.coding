##
## Sysctl related functions
##

kernelMatches() {
  echo ${LINE} | grep -q '^kernel config ' && return 0;
  return 1;
}

kernelFile() {
  echo "kernel-config";
}

kernelRegexp() {
  local KEY=$(echo "${LINE}" | awk '{print $3}');
  echo "${LINE}" | grep -q 'must be ';
  if [[ $? -eq 0 ]];
  then
    local VAL=$(echo ${LINE} | awk '{print $6}');
    if [[ "${VAL}" = "enabled" ]];
    then
      echo "^${KEY}=[ym]";
    else
      echo "${KEY}=${VAL}";
    fi
    return 0;
  fi

  echo "${LINE}" | grep -q 'must not be set';
  if [[ $? -eq 0 ]];
  then
    echo "# ${KEY} is not set";
    return 0;
  fi

  return 1;
}

