##
## Sysctl related functions
##

environmentMatches() {
  echo ${LINE} | grep -q '^environmentvariable ' && return 0;
  return 1;
}

environmentName() {
  local SETTING=$(echo ${LINE} | awk '{print $2}');
  echo "${SETTING}";
}

environmentRegexp() {
  local VARIABLE=$(echo "${LINE}" | sed -e 's:environmentvariable \([^ ]*\) .*:\1:g' | sed -e 's:\.:/:g');
  local REGEXP="";

  echo "${LINE}" | grep -q 'must match';
  if [ $? -eq 0 ];
  then
    REGEXP=$(echo "${LINE}" | awk '{print $5}');
    echo "${REGEXP}";
    return 0;
  fi

  echo "${LINE}" | grep -q 'may not match';
  if [ $? -eq 0 ];
  then
    REGEXP=$(echo "${LINE}" | awk '{print $6}');
    echo "${REGEXP}";
    return 0;
  fi
}

genEnvironmentMatch() {
  local CHECK=$1;

  # OVALNS, LINENUM and LINE are available through the calling function

  echo "<ind-def:environmentvariable_test id=\"oval:${OVALNS}:tst:${LINENUM}\" version=\"1\" check=\"${CHECK}\" comment=\"${LINE}\" check_existence=\"at_least_one_exists\">";
  echo "  <ind-def:object object_ref=\"oval:${OVALNS}:obj:${OBJNUM}\" />";
  echo "  <ind-def:state state_ref=\"oval:${OVALNS}:ste:${STENUM}\" />";
  echo "</ind-def:environmentvariable_test>";
}
