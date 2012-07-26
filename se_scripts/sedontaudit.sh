#!/bin/sh

#
# cp /var/log/avc.log raw && ./sedontaudit.sh -u test.te raw && make -f /usr/share/selinux/strict/include/Makefile test.pp && semodule -i test.pp && > /var/log/avc.log && tail -f /var/log/avc.log
#

if [ $# -eq 0 ] || [ "$1" = "-h" ];
then
  echo "Usage: $0 -h		Show help"
  echo "       $0 -g domain	Generate dontaudit for given domain"
  echo "       $0 -u module.te avc.log";
  echo "            		Update module.te with grants from logfile"
  exit 1;
fi

genDontaudit() {
  TARGETS=$(mktemp);
  CLASSES=$(mktemp);
  DOMAIN=$1;

  echo "policy_module(test, 1.0)";
  echo "";


  sesearch -s ${DOMAIN} -A -d | grep allow | awk '{print $3}' | sort | uniq > ${TARGETS};
  sesearch -s ${DOMAIN} -A -d | grep allow | awk '{print $5}' | sort | uniq > ${CLASSES};

  echo "gen_require(\`";

  for CLASS in $(cat ${CLASSES});
  do
    PERMS=$(ls /sys/fs/selinux/class/${CLASS}/perms | tr '\n' ' ');
    echo "	class ${CLASS} { ${PERMS} };";
  done

  for TARGET in $(cat ${TARGETS});
  do
    seinfo -t | grep -q ${TARGET}$
    if [ $? -eq 0 ];
    then
      echo "	type ${TARGET};"
    else
      echo "	attribute ${TARGET};"
    fi
  done

  echo "')";
  echo "";

  for TARGET in $(cat ${TARGETS});
  do
    for CLASS in $(cat ${CLASSES});
    do
      sesearch -s ${DOMAIN} -t ${TARGET} -c ${CLASS} -A -d | grep allow | grep -q '{';
      if [ $? -eq 0 ];
      then
        # Contains set, listout
	PERMS=$(sesearch -s ${DOMAIN} -t ${TARGET} -c ${CLASS} -A -d | grep allow | grep '{' | sed -e 's:.*{\([^}]*\)}.*:\1:g');
	for PERM in ${PERMS};
	do
          echo "   auditallow ${DOMAIN} ${TARGET} : ${CLASS} ${PERM} ;"
	done
      else
        # No set, so direct hit
        sesearch -s ${DOMAIN} -t ${TARGET} -c ${CLASS} -A -d | grep allow | sed -e 's:allow:auditallow:g';
      fi
    done
  done

  rm ${TARGETS};
  rm ${CLASSES};
}

commentGranted() {
  MODULEFILE=$1;
  RAWFILE=$2;
  WORKFILE=$(mktemp)

  cat ${RAWFILE} | grep granted | sed -e 's|.*granted  {\([^}]*\) } for.*scontext=[^:]*:[^:]*:\([^ ]*\) tcontext=[^:]*:[^:]*:\([^ ]*\) tclass=\(.*\)$|\2:\3:\4:\1|g' | sort | uniq > ${WORKFILE};
  while read LINE
  do
    SOURCE=$(echo ${LINE} | awk -F':' '{print $1}');
    TARGET=$(echo ${LINE} | awk -F':' '{print $2}');
    CLASS=$(echo ${LINE} | awk -F':' '{print $3}');
    PERMS=$(echo ${LINE} | awk -F':' '{print $4}');

    for PERM in ${PERMS};
    do
      echo "Processing grant for: allow ${SOURCE} ${TARGET} : ${CLASS} ${PERM}..";
      sed -i -e "s| auditallow ${SOURCE} ${TARGET} : ${CLASS} ${PERM}|#auditallow ${SOURCE} ${TARGET} : ${CLASS} ${PERM}|g" ${MODULEFILE};
    done
  done < ${WORKFILE};

  rm ${WORKFILE};
}

CMD=$1;
ARG1=$2;
ARG2=$3;

if [ "${CMD}" = "-g" ];
then
  genDontaudit ${ARG1};
elif [ "${CMD}" = "-u" ];
then
  commentGranted ${ARG1} ${ARG2};
fi
