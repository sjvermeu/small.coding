#!/bin/sh

typeset BASEDIR=/home/swift/Development/build
typeset ORIGSRC=refpolicy-20110726/policy/modules;
typeset NEWDST=../Centralized/hardened-refpolicy/policy/modules;
typeset PATCHES=../Centralized/small.coding/selinux-modules/patches;
typeset TMPLOC=tmp/segenfix_policy;

typeset TARGET=$2;
typeset TYPE=$1;

typeset SUBJECT="";

if [ $# -ne 2 ];
then
  echo "Usage: $0 <type> <target>";
  echo "";
  echo "<type> can be 'fullpath', 'minimal', 'incremental' or 'clean'";
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
elif [ "${TYPE}" = "incremental" ];
then
  if [ -d "${BASEDIR}/${TMPLOC}" ];
  then
    echo "Failed - ${BASEDIR}/${TMPLOC} exists!";
    exit 1;
  fi
  # Create a blank location
  mkdir ${BASEDIR}/${TMPLOC};
  rsync -aug ${BASEDIR}/${ORIGSRC}/../../ ${BASEDIR}/${TMPLOC};
  # Patch the current location
  pushd ${BASEDIR}/${TMPLOC} > /dev/null 2>&1;
  for PATCH in ${BASEDIR}/${PATCHES}/*.patch;
  do
    patch -p1 < ${PATCH} > /dev/null 2>&1;
  done
  popd > /dev/null 2>&1;
  pushd ${BASEDIR} > /dev/null 2>&1;
  # Now take the diff of the requested target
  diff -uN ${TMPLOC}/policy/modules/${SUBJECT}.te ${NEWDST}/${SUBJECT}.te | sed -e "s:${TMPLOC}:refpolicy.orig:g" | sed -e 's:../Centralized/hardened-refpolicy:refpolicy:g';
  diff -uN ${TMPLOC}/policy/modules/${SUBJECT}.if ${NEWDST}/${SUBJECT}.if | sed -e "s:${TMPLOC}:refpolicy.orig:g" | sed -e 's:../Centralized/hardened-refpolicy:refpolicy:g';
  diff -uN ${TMPLOC}/policy/modules/${SUBJECT}.fc ${NEWDST}/${SUBJECT}.fc | sed -e "s:${TMPLOC}:refpolicy.orig:g" | sed -e 's:../Centralized/hardened-refpolicy:refpolicy:g';
  [ -f ${NEWDST}/${SUBJECT}.te.in ] && diff -uN ${TMPLOC}/policy/modules/${SUBJECT}.te.in ${NEWDST}/${SUBJECT}.te.in | sed -e "s:${TMPLOC}:refpolicy.orig:g" | sed -e 's:../Centralized/hardened-refpolicy:refpolicy:g';
  # Clear working dir
  popd > /dev/null 2>&1;
  rm -rf ${BASEDIR}/${TMPLOC};
else
  cd ${BASEDIR};
  diff -uN ${ORIGSRC}/../../${TARGET} ${NEWDST}/../../${TARGET} | sed -e 's:../Centralized/hardened-refpolicy/:refpolicy:g';
fi
