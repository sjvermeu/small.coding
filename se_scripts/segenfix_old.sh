#!/bin/sh

typeset BASEDIR=/home/swift/Development/build
typeset ORIGSRC=refpolicy-20101213/policy/modules;
typeset NEWDST=../Centralized/hardened-refpolicy/policy/modules;

typeset TARGET=$2;
typeset TYPE=$1;

typeset SUBJECT="";

if [ $# -ne 2 ];
then
  echo "Usage: $0 <type> <target>";
  echo "";
  echo "<type> can be 'fullpath', 'minimal' or 'clean'";
  echo "<target> is the name of the module (which can be <category>/<module> as well)";
  echo "or the name of the file (from the refpolicy/ location upwards)";
  exit 1;
fi

if [ -f "${BASEDIR}/${ORIGSRC}/${TARGET}.te" ];
then
  SUBJECT="${TARGET}";
else
  SUBJECT=$(find ${BASEDIR}/${NEWDST} -type f -name ${TARGET}.te 2>/dev/null | awk -F'/' '{print $(NF-1)"/"$NF}' | sed -e "s:.te$::g");
  if [ "${SUBJECT}" = "" ];
  then
    SUBJECT=${TARGET};
  fi
fi

if [ "${TYPE}" = "fullpath" ] && [ "${SUBJECT}" != "modules" ];
then
  cd ${BASEDIR};
  diff -uN ${ORIGSRC}/${SUBJECT}.te ${NEWDST}/${SUBJECT}.te | sed -e 's:../Centralized/hardened-refpolicy:refpolicy:g';
  diff -uN ${ORIGSRC}/${SUBJECT}.if ${NEWDST}/${SUBJECT}.if | sed -e 's:../Centralized/hardened-refpolicy:refpolicy:g';
  diff -uN ${ORIGSRC}/${SUBJECT}.fc ${NEWDST}/${SUBJECT}.fc | sed -e 's:../Centralized/hardened-refpolicy:refpolicy:g';
  [ -f ${NEWDST}/${SUBJECT}.te.in ] && diff -uN ${ORIGSRC}/${SUBJECT}.te.in ${NEWDST}/${SUBJECT}.te.in | sed -e 's:../Centralized/hardened-refpolicy:refpolicy:g';
elif [ "${TYPE}" = "fullpath" ] && [ "${SUBJECT}" = "modules" ];
then
  cd ${BASEDIR};
  diff -uN ${ORIGSRC}/../modules.conf ${NEWDST}/../modules.conf;
elif [ "${TYPE}" = "minimal" ];
then
  cd ${BASEDIR};
  diff -uN ${ORIGSRC}/${SUBJECT}.te ${NEWDST}/${SUBJECT}.te | sed -e 's:../Centralized/hardened-refpolicy/policy/modules/::g' -e 's:refpolicy.orig/policy/modules/::g';
  diff -uN ${ORIGSRC}/${SUBJECT}.fc ${NEWDST}/${SUBJECT}.fc | sed -e 's:../Centralized/hardened-refpolicy/policy/modules/::g' -e 's:refpolicy.orig/policy/modules/::g';
else
  cd ${BASEDIR};
  diff -uN ${ORIGSRC}/../../${TARGET} ${NEWDST}/../../${TARGET} | sed -e 's:../Centralized/hardened-refpolicy/:refpolicy:g';
fi
