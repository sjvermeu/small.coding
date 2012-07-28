#!/bin/sh

##
## Usage:
## In ${BASE}, create a refpolicy-<version>.orig.
## Then call this script, start with "prep" and let it run.
## It will apply patches and as long as it doesn't fail, continue.
## When it fails, you should first copy over the patches in the base
## directory to the patch location again:
## ~$ cp *.patch ~/Development/Centralized/small.coding/selinux-modules/patches/
##
## This because those are "updated" patches (the "offsets" have been fixed).
##
## Then call the script, with "prep <patchname>" where <patchname> is the
## basename of the patch that is failing. You can then manually update the
## code in refpolicy-<version>, generate a patch your self:
## ~$ diff -uNr refpolicy-<version>.working refpolicy-<version> > ~/Development/.../<patch>.patch
##
## and continue

BASE=/home/swift/Development/build/tmp
VERSION=2.20120725

if [ $1 = "prep" ];
then
  rm -rf ${BASE}/refpolicy-${VERSION};
  rm -rf ${BASE}/refpolicy-${VERSION}.working;
  cp -r ${BASE}/refpolicy-${VERSION}.orig ${BASE}/refpolicy-${VERSION};
  cp -r ${BASE}/refpolicy-${VERSION}.orig ${BASE}/refpolicy-${VERSION}.working;
fi

for PATCH in /home/swift/Development/Centralized/small.coding/selinux-modules/patches/*.patch;
do
  P=`basename ${PATCH}`;
  if [ "${2}" = "${P}" ];
  then
    echo "Stopping before applying ${P} as requested.";
    break;
  fi
  cd refpolicy-${VERSION};
  patch --no-backup-if-mismatch -p1 -i ${PATCH};
  if [ $? -ne 0 ];
  then
    echo "Patch ${PATCH} <- workit!"
    break;
  fi
  cd ..
  # Generate new patch
  diff -uNr refpolicy-${VERSION}.working refpolicy-${VERSION} > ${P};
  cd refpolicy-${VERSION}.working;
  patch --no-backup-if-mismatch -p1 -i ../${P};
  cd ..;
done
