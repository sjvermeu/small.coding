#!/bin/sh

[[ -n ${ORIGSRC} ]] && ORIGSRC=/home/swift/Development/build/refpolicy-20110726/policy/modules;
[[ -n ${NEWDST} ]] && NEWDST=/home/swift/Development/Centralized/hardened-refpolicy/policy/modules;
[[ -n ${PATCHES} ]] && PATCHES=/home/swift/Development/Centralized/small.coding/selinux-modules/patches;
[[ -n ${TMPLOC} ]] && TMPLOC=/home/swift/Development/build/tmp/segenfix_policy;

typeset TARGET=$2;
typeset TYPE=$1;

typeset SUBJECT="";

##
## Input validation
##

if [ $# -ne 2 ];
then
  echo "Usage: $0 <type> <target>";
  echo "";
  echo "<type> can be 'fullpath', 'minimal', 'incremental' or 'clean'";
  echo "<target> is the name of the module (which can be <category>/<module> as well)";
  echo "or the name of the file (from the refpolicy/ location upwards)";
  exit 1;
fi

[ ! -d "${ORIGSRC}" ] && echo "Directory ORIGSRC = ${ORIGSRC} does not exist!" && exit 1;
[ ! -d "${NEWDST}" ] && echo "Directory NEWDST = ${NEWDST} does not exist!" && exit 1;
[ ! -d "${PATCHES}" ] && echo "Directory PATCHES = ${PATCHES} does not exist!" && exit 1;
[ -d "${TMPLOC}" ] || [ -f "${TMPLOC}" ] && echo "Directory TMPLOC = ${TMPLOC} may NOT exist!" && exit 1;

##
## Main
##

if [ -f "${ORIGSRC}/${TARGET}.te" ];
then
  SUBJECT="${TARGET}";
else
  SUBJECT=$(find ${NEWDST} -type f -name ${TARGET}.te 2>/dev/null | awk -F'/' '{print $(NF-1)"/"$NF}' | sed -e "s:.te$::g");
  if [ "${SUBJECT}" = "" ];
  then
    SUBJECT=${TARGET};
  fi
fi

if [ "${TYPE}" = "fullpath" ] && [ "${SUBJECT}" != "modules" ];
then
  diff -uN ${ORIGSRC}/${SUBJECT}.te ${NEWDST}/${SUBJECT}.te | sed -e 's:../Centralized/hardened-refpolicy:refpolicy:g';
  diff -uN ${ORIGSRC}/${SUBJECT}.if ${NEWDST}/${SUBJECT}.if | sed -e 's:../Centralized/hardened-refpolicy:refpolicy:g';
  diff -uN ${ORIGSRC}/${SUBJECT}.fc ${NEWDST}/${SUBJECT}.fc | sed -e 's:../Centralized/hardened-refpolicy:refpolicy:g';
  [ -f ${NEWDST}/${SUBJECT}.te.in ] && diff -uN ${ORIGSRC}/${SUBJECT}.te.in ${NEWDST}/${SUBJECT}.te.in | sed -e 's:../Centralized/hardened-refpolicy:refpolicy:g';
elif [ "${TYPE}" = "fullpath" ] && [ "${SUBJECT}" = "modules" ];
then
  diff -uN ${ORIGSRC}/../modules.conf ${NEWDST}/../modules.conf;
elif [ "${TYPE}" = "minimal" ];
then
  diff -uN ${ORIGSRC}/${SUBJECT}.te ${NEWDST}/${SUBJECT}.te | sed -e 's:../Centralized/hardened-refpolicy/policy/modules/::g' -e 's:refpolicy.orig/policy/modules/::g';
  diff -uN ${ORIGSRC}/${SUBJECT}.fc ${NEWDST}/${SUBJECT}.fc | sed -e 's:../Centralized/hardened-refpolicy/policy/modules/::g' -e 's:refpolicy.orig/policy/modules/::g';
elif [ "${TYPE}" = "incremental" ];
then
  if [ -d "${TMPLOC}" ];
  then
    echo "Failed - ${TMPLOC} exists!";
    exit 1;
  fi
  # Create a blank location
  mkdir ${TMPLOC};
  rsync -aug ${ORIGSRC}/../../ ${TMPLOC};
  # Patch the current location
  pushd ${TMPLOC} > /dev/null 2>&1;
  for PATCH in ${PATCHES}/*.patch;
  do
    patch -p1 < ${PATCH} > /dev/null 2>&1;
  done
  popd > /dev/null 2>&1;
  # Now take the diff of the requested target
  diff -uN ${TMPLOC}/policy/modules/${SUBJECT}.te ${NEWDST}/${SUBJECT}.te | sed -e "s:${TMPLOC}:refpolicy.orig:g" | sed -e 's:../Centralized/hardened-refpolicy:refpolicy:g';
  diff -uN ${TMPLOC}/policy/modules/${SUBJECT}.if ${NEWDST}/${SUBJECT}.if | sed -e "s:${TMPLOC}:refpolicy.orig:g" | sed -e 's:../Centralized/hardened-refpolicy:refpolicy:g';
  diff -uN ${TMPLOC}/policy/modules/${SUBJECT}.fc ${NEWDST}/${SUBJECT}.fc | sed -e "s:${TMPLOC}:refpolicy.orig:g" | sed -e 's:../Centralized/hardened-refpolicy:refpolicy:g';
  [ -f ${NEWDST}/${SUBJECT}.te.in ] && diff -uN ${TMPLOC}/policy/modules/${SUBJECT}.te.in ${NEWDST}/${SUBJECT}.te.in | sed -e "s:${TMPLOC}:refpolicy.orig:g" | sed -e 's:../Centralized/hardened-refpolicy:refpolicy:g';
  # Clear working dir
  rm -rf ${TMPLOC};
else
  diff -uN ${ORIGSRC}/../../${TARGET} ${NEWDST}/../../${TARGET} | sed -e 's:../Centralized/hardened-refpolicy/:refpolicy:g';
fi
