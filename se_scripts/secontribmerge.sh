#!/bin/sh

SRC=/home/swift/Development/Centralized/refpolicy/policy/modules/contrib

if [ $# -ne 1 ] || [ $1 = "-h" ] || [ $1 = "--help" ] ; then
  echo "Usage: $0 <patch-num>"
  echo "";
  echo "Execute it inside the contrib/ folder where the patches are to be applied."
  exit 1;
fi

NUM=${1};
PATCH=$(ls ${SRC}/${NUM}*.patch);

git am ${PATCH};

if [ $? -ne 0 ];
then
	patch -p1 < ${PATCH};
	rm -f *.orig;
	ls *.rej > /dev/null 2>&1;
	if [ $? -eq 0 ];
	then
		echo "";
		echo " Patch rejections found. Clean this up manually please."
		echo "";
	else
		git add -A .;
		git am --resolved;
	fi
else
	ls ../../../*.te > /dev/null 2>&1 || echo "!! Wrong root applied!";
	ls ../../../*.fc > /dev/null 2>&1 || echo "!! Wrong root applied!";
	ls ../../../*.if > /dev/null 2>&1 || echo "!! Wrong root applied!";
fi
