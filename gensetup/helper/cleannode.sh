#!/bin/sh
#
# cleannode.sh cleans up an image, reducing the file system usage
# considerably.

if [ "${1}" != "pretend" ] && [ "${1}" != "run" ];
then
  echo "Usage: $0 pretend";
  echo "       $0 run";
  exit 1;
fi

PRECMD="";

if [ "${1}" = "pretend" ];
then
  PRECMD="echo ";
fi

echo "## Removing obsoleted kernel files in /boot";

cd /boot;
for F in System.map-* config-* initramfs-* vmlinuz-*;
do
  if [ "${F}" != "System.map-`uname -r`" ] &&
     [ "${F}" != "config-`uname -r`" ] &&
     [ "${F}" != "initramfs-genkernel-x86_64-`uname -r`" ] && 
     [ "${F}" != "initramfs-`uname -r`" ] &&
     [ "${F}" != "vmlinuz-`uname -r`" ];
  then
    ${PRECMD} rm ${F};
  fi
done
for F in vmlinux-*;
do
  ${PRECMD} rm ${F};
done

echo "## Cleaning log files";

cd /var/log;
for F in *;
do
  [ -d ${F} ] && continue;
  if [ -n "${PRECMD}" ];
  then
    echo "> ${F}";
  else
    > ${F};
  fi
done

echo "## Cleaning root and user home directories"

cd /root;
for F in .??*;
do
  [ ! -f ${F} ] && continue;
  ${PRECMD} rm ${F};
done
[ -d .ssh ] && ${PRECMD} rm -rf .ssh

for U in user oper;
do
  cd /home/${U};
  for F in .??*;
  do
    [ ! -f ${F} ] && continue;
    ${PRECMD} rm ${F};
  done
  [ -d .ssh ] && ${PRECMD} rm -rf .ssh
done

echo "## Cleaning caches"

cd /var/cache;
[ -d revdep-rebuild ] && ${PRECMD} rm -rf revdep-rebuild;
[ -d edb/dep ] && ${PRECMD} rm -rf edb/dep; # emerge --metadata regenerates this
