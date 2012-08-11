#!/bin/sh

[[ -n ${ORIGSRC} ]] || ORIGSRC=/home/swift/Development/build/refpolicy-20120725/policy/modules;
[[ -n ${NEWDST} ]] || NEWDST=/home/swift/Development/Centralized/hardened-refpolicy/policy/modules;
[[ -n ${PATCHES} ]] || PATCHES=/home/swift/Development/Centralized/small.coding/selinux-modules/patches;
[[ -n ${TMPLOC} ]] || TMPLOC=/home/swift/Development/build/tmp/segenfix_policy;

typeset TARGET=$2;
typeset TYPE=$1;
typeset TRANSLATE="s:\(${TMPLOC}\|${NEWDST%%/policy/modules}\):refpolicy:g";
typeset MODULETRANSLATE="s:/.*/policy/modules/::g";

typeset SUBJECT="";

##
## Input validation
##

if [ $# -ne 2 ];
then
  echo "Usage: $0 <type> <target>";
  echo "";
  echo "<type> can be 'fullpath', 'minimal', 'incremental', 'incremental-r#' or 'clean'";
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
  if [ "${TARGET}" = "all" ];
  then
    SUBJECT=${TARGET};
    NEWDST=${NEWDST%%/policy/modules};
  elif [ "${SUBJECT}" = "" ];
  then
    SUBJECT=${TARGET};
  fi
fi

if [ "${TYPE}" = "fullpath" ] && [ "${SUBJECT}" != "modules" ];
then
  diff -uN ${ORIGSRC}/${SUBJECT}.te ${NEWDST}/${SUBJECT}.te | sed -e ${TRANSLATE};
  diff -uN ${ORIGSRC}/${SUBJECT}.if ${NEWDST}/${SUBJECT}.if | sed -e ${TRANSLATE};
  diff -uN ${ORIGSRC}/${SUBJECT}.fc ${NEWDST}/${SUBJECT}.fc | sed -e ${TRANSLATE};
  [ -f ${NEWDST}/${SUBJECT}.te.in ] && diff -uN ${ORIGSRC}/${SUBJECT}.te.in ${NEWDST}/${SUBJECT}.te.in | sed -e ${TRANSLATE};
elif [ "${TYPE}" = "fullpath" ] && [ "${SUBJECT}" = "modules" ];
then
  diff -uN ${ORIGSRC}/../modules.conf ${NEWDST}/../modules.conf;
elif [ "${TYPE}" = "minimal" ];
then
  diff -uN ${ORIGSRC}/${SUBJECT}.te ${NEWDST}/${SUBJECT}.te | sed -e ${MODULETRANSLATE};
  diff -uN ${ORIGSRC}/${SUBJECT}.fc ${NEWDST}/${SUBJECT}.fc | sed -e ${MODULETRANSLATE};
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
    patch --no-backup-if-mismatch -p1 < ${PATCH} > /dev/null 2>&1;
    [[ $? -ne 0 ]] && echo "Patch ${PATCH} failed to apply!" && return 1;
  done
  popd > /dev/null 2>&1;
  # Now take the diff of the requested target
  if [ "${SUBJECT}" == "all" ];
  then
    diff -uNr -x ".git*" -x "CVS" -x "*.autogen*" -x "*.part" ${TMPLOC} ${NEWDST} | sed -e ${TRANSLATE};
  else
    diff -uN ${TMPLOC}/policy/modules/${SUBJECT}.te ${NEWDST}/${SUBJECT}.te | sed -e ${TRANSLATE};
    diff -uN ${TMPLOC}/policy/modules/${SUBJECT}.if ${NEWDST}/${SUBJECT}.if | sed -e ${TRANSLATE};
    diff -uN ${TMPLOC}/policy/modules/${SUBJECT}.fc ${NEWDST}/${SUBJECT}.fc | sed -e ${TRANSLATE};
    [ -f ${NEWDST}/${SUBJECT}.te.in ] && diff -uN ${TMPLOC}/policy/modules/${SUBJECT}.te.in ${NEWDST}/${SUBJECT}.te.in | sed -e ${TRANSLATE};
  fi
  # Clear working dir
  rm -rf ${TMPLOC};
elif [ "${TYPE%%-r*}" = "incremental" ];
then
  REV="${TYPE##incremental-r}";
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
    PREV=$(echo ${PATCH} | sed -e "s:.*-r\([0-9]*\).patch:\1:g");
    [ ${PREV} -gt ${REV} ] && continue;
    patch --no-backup-if-mismatch -p1 < ${PATCH} > /dev/null 2>&1;
  done
  popd > /dev/null 2>&1;
  # Now take the diff of the requested target
  if [ "${SUBJECT}" == "all" ];
  then
    diff -uNr -x ".git" -x "CVS" ${TMPLOC} ${NEWDST} | sed -e ${TRANSLATE};
  else
    diff -uN ${TMPLOC}/policy/modules/${SUBJECT}.te ${NEWDST}/${SUBJECT}.te | sed -e ${TRANSLATE};
    diff -uN ${TMPLOC}/policy/modules/${SUBJECT}.if ${NEWDST}/${SUBJECT}.if | sed -e ${TRANSLATE};
    diff -uN ${TMPLOC}/policy/modules/${SUBJECT}.fc ${NEWDST}/${SUBJECT}.fc | sed -e ${TRANSLATE};
    [ -f ${NEWDST}/${SUBJECT}.te.in ] && diff -uN ${TMPLOC}/policy/modules/${SUBJECT}.te.in ${NEWDST}/${SUBJECT}.te.in | sed -e ${TRANSLATE};
  fi
  # Clear working dir
  rm -rf ${TMPLOC};
else
  diff -uN ${ORIGSRC}/../../${TARGET} ${NEWDST}/../../${TARGET} | sed -e 's:../Centralized/hardened-refpolicy/:refpolicy:g';
fi
