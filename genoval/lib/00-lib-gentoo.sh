##
## Sysctl related functions
##

gentooVariableMatches() {
  echo ${LINE} | grep -q '^gentoo variable ' && return 0;
  return 1;
}

gentooProfileMatches() {
  echo ${LINE} | grep -q '^gentoo profile ' && return 0;
  return 1;
}

gentooVariableFile() {
  echo "emerge-info-verbose";
}

gentooProfileFile() {
  echo "emerge-info-verbose";
}

gentooVariableRegexp() {
  local VARIABLE=$(echo "${LINE}" | sed -e 's:gentoo variable \([^ ]*\) .*:\1:g' | sed -e 's:\.:/:g');
  local REGEXP="";

  echo "${LINE}" | grep -q 'must contain';
  if [ $? -eq 0 ];
  then
    REGEXP=$(echo "${LINE}" | sed -e 's:.*must contain ::g');
    echo "${VARIABLE}=[\"]?.*${REGEXP}.*[\"]?$";
    return 0;
  fi

  echo "${LINE}" | grep -q 'must be';
  if [ $? -eq 0 ];
  then
    REGEXP=$(echo "${LINE}" | sed -e 's:.*must be ::g');
    echo "${VARIABLE}=[\"]?${REGEXP}[\"]?$";
    return 0;
  fi
}

gentooProfileRegexp() {
  local REGEXP=$(echo "${LINE}" | sed -e 's:^gentoo profile must contain ::g');
  # profile is first line of output, after (
  echo "^Portage.*\\\(.*${REGEXP}.*, gcc.*";
  return 0;
}

gentooProfileFix() {
  local VALUE=$(echo "${LINE}" | sed -e 's:^gentoo profile must contain ::g');
  echo 'eselect profile set `eselect profile list | awk /${VALUE}/ '"{print \$2; exit}"'`';
  return 0;
}
