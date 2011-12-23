#!/bin/sh

#set -x;

if [ $# -ne 3 ];
then
  echo "Usage: $0 <xccdf-template> <oval-namespace> <save-dir>";
  echo "";
  echo " xccdf-template: Filename of the XCCDF template (must end in .template)";
  echo " oval-namespace: Namespace for the OVAL objects, like \"org.gentoo.dev.swift\"";
  echo " save-dir:       Directory in which to save the results (can be \".\")";
  exit 1;
fi

typeset XCCDF=$1;
typeset OVALNS=$2;
export OVALNS;
typeset OVAL=$(echo ${XCCDF} | sed -e 's:.template::g' | sed -e 's:[Xx][Cc][Cc][Dd][Ff]:oval:g');
typeset WORKDIR=$3;

# Error checking
if [ ! -f ${XCCDF} ];
then
  echo "File ${XCCDF} must exist!";
  exit 2;
fi

if [ ! -d ${WORKDIR} ];
then
  echo "Directory ${WORKDIR} must exist!";
  exit 3;
fi

if [ -f ${WORKDIR}/${OVAL} ];
then
  TIMESTAMP=$(date +%Y%m%d%H%M%S.%N);
  echo "File ${OVAL} already exists. Renaming to ${OVAL}.${TIMESTAMP}";
  mv ${WORKDIR}/${OVAL} ${WORKDIR}/${OVAL}.${TIMESTAMP};
fi

# Loading in libraries
for LIB in ./lib/*.sh;
do
  echo "Loading in ${LIB}...";
  source ${LIB};
done

# Preparing the work directory
cp ${XCCDF} ${WORKDIR}/${XCCDF%%.template};
XCCDF=${XCCDF%%.template};
cp definitions.conf ${WORKDIR} > /dev/null 2>&1;

pushd ${WORKDIR} > /dev/null 2>&1;
touch objects.conf;
touch states.conf;

###
### HERE STARTS THE REAL WORK
###
grep -B 9999 "@@GENOVAL START DEFINITIONS" ${OVAL}.template > ${OVAL};

##
## Regenerate XCCDF file and OVAL definitions based on definitions.conf.
##
for RULE in $(sed -e 's:.*\[\([^[]*\)\]$:\1:g' definitions.conf);
do
  export LINE=$(grep "\[${RULE}\]" definitions.conf | sed -e 's: \[[^[]*\]$::g');
  LINENUM=$(grep -n "\[${RULE}\]" definitions.conf | sed -e 's|:.*||g');
  grep -q "@@GEN START ${RULE} " ${XCCDF} || continue;

  # XCCDF
  grep -B 99999 "@@GEN START ${RULE} " ${XCCDF} > ${XCCDF}.work;
  echo "<Rule id=\"${RULE}\" selected=\"false\">" >> ${XCCDF}.work;
  echo "  <title>${LINE}</title>" >> ${XCCDF}.work;
  echo "  <description>${LINE}</description>" >> ${XCCDF}.work;
  if `hasFix`;
  then
    genFix >> ${XCCDF}.work;
  fi
  echo "  <check system=\"http://oval.mitre.org/XMLSchema/oval-definitions-5\">" >> ${XCCDF}.work;
  echo "    <check-content-ref name=\"oval:${OVALNS}:def:${LINENUM}\" href=\"${OVAL}\" />" >> ${XCCDF}.work;
  echo "  </check>" >> ${XCCDF}.work;
  echo "</Rule>" >> ${XCCDF}.work;
  grep -A 99999 "@@GEN END ${RULE} " ${XCCDF} >> ${XCCDF}.work;
  mv ${XCCDF}.work ${XCCDF};

  # OVAL
  echo "<definition class=\"compliance\" id=\"oval:${OVALNS}:def:${LINENUM}\" version=\"1\">" >> ${OVAL};
  echo "  <metadata>" >> ${OVAL};
  echo "    <title>${LINE}</title>" >> ${OVAL};
  echo "    <description>${LINE}</description>" >> ${OVAL};
  echo "  </metadata>" >> ${OVAL};
  echo "  <criteria>" >> ${OVAL};
  echo "    <criterion test_ref=\"oval:${OVALNS}:tst:${LINENUM}\" comment=\"${LINE}\" />" >> ${OVAL};
  echo "  </criteria>" >> ${OVAL};
  echo "</definition>" >> ${OVAL};
done

grep -A 9999 "@@GENOVAL END DEFINITIONS" ${OVAL}.template | grep -B 9999 "@@GENOVAL START TESTS" >> ${OVAL};

##
## Loop over definitions to generate tests
##
for RULE in $(sed -e 's:.*\[\([^[]*\)\]$:\1:g' definitions.conf);
do
  export LINE=$(grep "\[${RULE}\]" definitions.conf | sed -e "s: \[${RULE}\]$::g");
  export LINENUM=$(grep -n "\[${RULE}\]" definitions.conf | sed -e 's|:.*||g');

  ## Test for separate file system
  echo ${LINE} | egrep -q '^/[^ ]* is (a )?(separate )?file[ ]?system( of type [^ ]+)?$';
  if [ $? -eq 0 ];
  then
    PARTITION=$(echo ${LINE} | sed -e 's:^/\([^ ]*\).*:\1:g');
    TYPE=$(echo ${LINE} | sed -e 's:.*type \([^ ]*\).*:\1:g' -e 's:.* .*::g');
    export OBJNUM=$(getObjnum "partition" "${PARTITION}");
    export STENUM=$([[ ${TYPE} == "" ]] && echo "" || getStenum "filesystemtype" "${TYPE}");

    echo "<lin-def:partition_test id=\"oval:${OVALNS}:tst:${LINENUM}\" version=\"1\" check=\"all\" comment=\"${LINE}\" check_existence=\"at_least_one_exists\">" >> ${OVAL};
    echo "  <lin-def:object object_ref=\"oval:${OVALNS}:obj:${OBJNUM}\" />" >> ${OVAL};
    if [ "${TYPE}" != "" ];
    then
      echo "  <lin-def:state state_ref=\"oval:${OVALNS}:ste:${STENUM}\" />" >> ${OVAL};
    fi
    echo "</lin-def:partition_test>" >> ${OVAL};
    continue;
  fi

  ## Test for mount option
  echo ${LINE} | egrep -q 'mount[ ]?point /[^ ]* is mounted with .*option.*';
  if [ $? -eq 0 ];
  then
    PARTITION=$(echo ${LINE} | sed -e 's:^mount point /::g' -e 's: .*::g');
    OPTION=$(echo ${LINE} | sed -e 's:.*option \([a-zA-Z0-9]*\):\1:g' -e 's:.* \([a-zA-Z0-9]*\) option:\1:g');
    export OBJNUM=$(getObjnum "partition" "${PARTITION}");
    export STENUM=$(getStenum "mountoption" "${OPTION}");

    echo "<lin-def:partition_test id=\"oval:${OVALNS}:tst:${LINENUM}\" version=\"1\" check=\"all\" comment=\"${LINE}\" check_existence=\"at_least_one_exists\">" >> ${OVAL};
    echo "  <lin-def:object object_ref=\"oval:${OVALNS}:obj:${OBJNUM}\" />" >> ${OVAL};
    echo "  <lin-def:state state_ref=\"oval:${OVALNS}:ste:${STENUM}\" />" >> ${OVAL};
    echo "</lin-def:partition_test>" >> ${OVAL};
  fi

  ## Test for file regular expression
  echo ${LINE} | egrep -q '^file .* must have a line that matches.*';
  if [ $? -eq 0 ];
  then
    FILE=$(echo ${LINE} | sed -e 's:file \(.*\) must have a line.*:\1:g');
    REGEXP=$(echo "${LINE}" | sed -e 's:.*must have a line that matches ::g');
    export OBJNUM=$(getObjnum "file" "${FILE}");
    export STENUM=$(getStenum "regexp" "${REGEXP}");

    genTextfileMatch "at least one" >> ${OVAL};
  fi

  ## Test for NO file regular expression
  echo ${LINE} | egrep -q 'file .* may not have a line that matches.*';
  if [ $? -eq 0 ];
  then
    FILE=$(echo ${LINE} | sed -e 's:file \(.*\) may not have a line.*:\1:g');
    REGEXP=$(echo ${LINE} | sed -e 's:.*may not have a line that matches ::g' -e 's: \[[^[]*\]$::g');
    export OBJNUM=$(getObjnum "file" "${FILE}");
    export STENUM=$(getStenum "regexp" "${REGEXP}");
    
    genTextfileMatch "none satisfy" >> ${OVAL};
  fi

  ## Test for sysctl
  if `sysctlMatches`;
  then
    FILE=$(sysctlFile);
    REGEXP=$(sysctlRegexp);
    export OBJNUM=$(getObjnum "file" "${FILE}");
    export STENUM=$(getStenum "regexp" "${REGEXP}");

    genTextfileMatch "at least one" >> ${OVAL};
  fi

  ## Test for gentoo variables
  if `gentooVariableMatches`;
  then
    FILE=$(gentooVariableFile);
    REGEXP=$(gentooVariableRegexp);
    export OBJNUM=$(getObjnum "scriptoutput" "${FILE}");
    export STENUM=$(getStenum "regexp" "${REGEXP}");

    genTextfileMatch "at least one" >> ${OVAL};
  fi

  ## Test for gentoo profile
  if `gentooProfileMatches`;
  then
    FILE=$(gentooProfileFile);
    REGEXP=$(gentooProfileRegexp);
    export OBJNUM=$(getObjnum "scriptoutput" "${FILE}");
    export STENUM=$(getStenum "regexp" "${REGEXP}");

    genTextfileMatch "at least one" >> ${OVAL};
  fi

  ## Test for kernel config
  if `kernelMatches`;
  then
    FILE=$(kernelFile);
    REGEXP=$(kernelRegexp);
    export OBJNUM=$(getObjnum "scriptoutput" "${FILE}");
    export STENUM=$(getStenum "regexp" "${REGEXP}");

    genTextfileMatch "at least one" >> ${OVAL};
  fi
done

grep -A 9999 "@@GENOVAL END TESTS" ${OVAL}.template | grep -B 9999 "@@GENOVAL START OBJECTS" >> ${OVAL};

##
## Loop over objects.conf to generate objects
##
for OBJECT in $(cat objects.conf);
do
  OBJNUM=$(echo ${OBJECT} | awk -F':' '{print $1}');
  OBJTYPE=$(echo ${OBJECT} | awk -F':' '{print $2}' | awk -F'=' '{print $1}');
  OBJVALUE=$(echo ${OBJECT} | awk -F':' '{print $2}' | awk -F'=' '{print $2}');

  ## Partition objects
  if [ "${OBJTYPE}" == "partition" ];
  then
    echo "<lin-def:partition_object id=\"oval:${OVALNS}:obj:${OBJNUM}\" version=\"1\" comment=\"The /${OBJVALUE} partition\">" >> ${OVAL};
    echo "  <lin-def:mount_point>/${OBJVALUE}</lin-def:mount_point>" >> ${OVAL};
    echo "</lin-def:partition_object>" >> ${OVAL};
    continue;
  fi

  ## File content lines (non-commented)
  if [ "${OBJTYPE}" == "file" ];
  then
    echo "<ind-def:textfilecontent54_object id=\"oval:${OVALNS}:obj:${OBJNUM}\" version=\"1\" comment=\"Non-comment lines in ${OBJVALUE}\">" >> ${OVAL};
    echo "  <ind-def:filepath>${OBJVALUE}</ind-def:filepath>" >> ${OVAL};
    echo "  <ind-def:pattern operation=\"pattern match\">^[[:space:]]*([^#[:space:]].*[^[:space:]]?)[[:space:]]*$</ind-def:pattern>" >> ${OVAL};
    echo "  <ind-def:instance datatype=\"int\" operation=\"greater than or equal\">1</ind-def:instance>" >> ${OVAL};
    echo "</ind-def:textfilecontent54_object>" >> ${OVAL};
  fi

  ## Non-commented script output
  if [ "${OBJTYPE}" == "scriptoutput" ];
  then
    echo "<ind-def:textfilecontent54_object id=\"oval:${OVALNS}:obj:${OBJNUM}\" version=\"1\" comment=\"Non-comment lines in ${OBJVALUE}\">" >> ${OVAL};
    echo "  <ind-def:path var_check=\"at least one\" var_ref=\"oval:${OVALNS}.genoval:var:1\"/>" >> ${OVAL};
    echo "  <ind-def:filename>${OBJVALUE}</ind-def:filename>" >> ${OVAL};
    echo "  <ind-def:pattern operation=\"pattern match\">^[[:space:]]*([^#[:space:]].*[^[:space:]]?)[[:space:]]*$</ind-def:pattern>" >> ${OVAL};
    echo "  <ind-def:instance datatype=\"int\" operation=\"greater than or equal\">1</ind-def:instance>" >> ${OVAL};
    echo "</ind-def:textfilecontent54_object>" >> ${OVAL};
  fi
done

grep -A 9999 "@@GENOVAL END OBJECTS" ${OVAL}.template | grep -B 9999 "@@GENOVAL START STATES" >> ${OVAL};

##
## Loop over states.conf to generate states
##
while read STATE;
do
  STENUM=$(echo ${STATE} | awk -F':' '{print $1}');
  STETYPE=$(echo ${STATE} | awk -F':' '{print $2}' | awk -F'=' '{print $1}');
  STEVALUE=$(echo "${STATE}" | awk -F':' '{print $2}' | sed -e 's:^[^=]*=::g');
  STEVALUECOMMENT=$(echo ${STEVALUE} | tr -d '["]');

  # filesystemtype
  if [ "${STETYPE}" == "filesystemtype" ];
  then
    echo "<lin-def:partition_state id=\"oval:${OVALNS}:ste:${STENUM}\" version=\"1\" comment=\"The file system is ${STEVALUE}\">" >> ${OVAL};
    case ${STEVALUE} in
	"tmpfs")
		echo "    <lin-def:fs_type>TMPFS_MAGIC</lin-def:fs_type>" >> ${OVAL};
		;;
	*)
		echo "    <lin-def:fs_type>${STEVAL}</lin-def:fs_type>" >> ${OVAL};
		echo "WARNING - File system type ${STEVAL} does not have a known MAGIC!";
		;;
    esac
    echo "</lin-def:partition_state>" >> ${OVAL};
    continue;
  fi

  # mountoption
  if [ "${STETYPE}" == "mountoption" ];
  then
    echo "<lin-def:partition_state id=\"oval:${OVALNS}:ste:${STENUM}\" version=\"1\" comment=\"The mount option ${STEVALUE} is set\">" >> ${OVAL};
    echo "  <lin-def:mount_options entity_check=\"at least one\">${STEVALUE}</lin-def:mount_options>" >> ${OVAL};
    echo "</lin-def:partition_state>" >> ${OVAL};
    continue;
  fi;

  # regular expressions
  if [ "${STETYPE}" == "regexp" ];
  then
    echo "<ind-def:textfilecontent54_state id=\"oval:${OVALNS}:ste:${STENUM}\" version=\"1\" comment=\"The match of ${STEVALUECOMMENT}\">" >> ${OVAL};
    echo "  <ind-def:subexpression operation=\"pattern match\">${STEVALUE}</ind-def:subexpression>" >> ${OVAL};
    echo "</ind-def:textfilecontent54_state>" >> ${OVAL};
  fi
done < states.conf;

grep -A 9999 "@@GENOVAL END STATES" ${OVAL}.template >> ${OVAL};

# Substitute variables
sed -i -e "s:@@OVALNS@@:${OVALNS}:g" ${OVAL};
sed -i -e "s:@@OVALNS@@:${OVALNS}:g" ${XCCDF};

popd > /dev/null 2>&1;

