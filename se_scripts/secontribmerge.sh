#!/bin/sh

SRC=/home/swift/Development/Centralized/refpolicy/policy/modules/contrib

NUM=${1};

git am ${SRC}/${NUM}*.patch;

if [ $? -ne 0 ];
then
	patch -p1 < ${SRC}/${NUM}*.patch;
	rm -f *.orig;
	ls *.rej > /dev/null 2>&1;
	if [ $? -ne 0 ];
	then
		echo "";
		echo " Patch rejections found. Clean this up manually please."
		echo "";
	else
		git add -A;
		git am --resolved;
	fi
else
	ls ../../../*.te > /dev/null 2>&1 || echo "!! Wrong root applied!";
	ls ../../../*.fc > /dev/null 2>&1 || echo "!! Wrong root applied!";
	ls ../../../*.if > /dev/null 2>&1 || echo "!! Wrong root applied!";
fi
