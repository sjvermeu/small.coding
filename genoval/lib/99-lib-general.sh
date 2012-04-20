##
## General functions for genoval
##

getObjnum() {
  local KEY=$1;
  local VAL=$2;

  # Special case: @SOMETHING@ is an environment variable
  echo "${VAL}" | grep -q '@[^ ]*@';
  if [ $? -eq 0 ];
  then
    local VARNAME=$(echo "${VAL}" | sed -e 's:.*@\([^ ]*\)@.*:\1:g');
    local TEMPOBJNUM=$(grep -F ":environmentvariable=${VARNAME}:" objects.conf | awk -F':' '{print $1}');

    if [[ "${TEMPOBJNUM}" == "" ]];
    then
      # Environment variable not declared yet
      NEWTOBJNUM=$(wc -l objects.conf | awk '{print $1+1}');
      echo "${NEWTOBJNUM}:environmentvariable=${VARNAME}:" >> objects.conf;
    fi
  fi

  local OBJNUM=$(grep -F ":${KEY}=${VAL}:" objects.conf | awk -F':' '{print $1}');

  if [ "${OBJNUM}" == "" ];
  then
    # Definition doesn't exist yet
    NEWOBJNUM=$(wc -l objects.conf | awk '{print $1+1}');
    echo "${NEWOBJNUM}:${KEY}=${VAL}:" >> objects.conf;
    OBJNUM=${NEWOBJNUM};
  fi

  echo ${OBJNUM};
}

getStenum() {
  local KEY=$1;
  local VAL=$2;

  local STENUM=$(grep -F ":${KEY}=${VAL}:" states.conf | awk -F':' '{print $1}');

  if [ "${STENUM}" == "" ];
  then
    # State doesn't exist yet
    NEWSTENUM=$(wc -l states.conf | awk '{print $1+1}');
    echo "${NEWSTENUM}:${KEY}=${VAL}:" >> states.conf;
    STENUM=${NEWSTENUM};
  fi

  echo ${STENUM}
}

genTextfileMatch() {
  local CHECK=$1;

  # OVALNS, LINENUM and LINE are available through the calling function

  echo "<ind-def:textfilecontent54_test id=\"oval:${OVALNS}:tst:${LINENUM}\" version=\"1\" check=\"${CHECK}\" comment=\"${LINE}\" check_existence=\"at_least_one_exists\">";
  echo "  <ind-def:object object_ref=\"oval:${OVALNS}:obj:${OBJNUM}\" />";
  echo "  <ind-def:state state_ref=\"oval:${OVALNS}:ste:${STENUM}\" />";
  echo "</ind-def:textfilecontent54_test>";
}
