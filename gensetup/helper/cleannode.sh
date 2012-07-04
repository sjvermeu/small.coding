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
echo "cd /boot";
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
  [ -f ${F} ] && ${PRECMD} rm ${F};
done

echo "## Cleaning log files";
echo "cd /var/log"
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
echo "cd /root"
cd /root;
for F in .??*;
do
  [ ! -f ${F} ] && continue;
  ${PRECMD} rm ${F};
done
[ -d .ssh ] && ${PRECMD} rm -rf .ssh

for U in user oper;
do
  echo "cd /home/${U}"
  cd /home/${U};
  for F in .??*;
  do
    [ ! -f ${F} ] && continue;
    ${PRECMD} rm ${F};
  done
  [ -d .ssh ] && ${PRECMD} rm -rf .ssh
done

echo "## Cleaning caches"
echo "cd /var/cache"
cd /var/cache;
[ -d revdep-rebuild ] && ${PRECMD} rm -rf revdep-rebuild;
[ -d edb/dep ] && ${PRECMD} rm -rf edb/dep; # emerge --metadata regenerates this
for D in man/*;
do
  [ -d ${D} ] && ${PRECMD} rm -rf ${D};
done

echo "## Cleaning udev persistent rules"
echo "cd /etc/udev/rules.d"
cd /etc/udev/rules.d
for F in *;
do
  [ -f ${F} ] && ${PRECMD} rm -f ${F};
done

echo "## Cleaning SSHd host keys"
echo "cd /etc/ssh"
cd /etc/ssh
for F in *_key*;
do
  [ -f ${F} ] && ${PRECMD} rm -f ${F};
done

echo "## Cleaning /usr/poratge";
${PRECMD} rm -rf /usr/portage/*;

echo "## "
echo "## Do not forget:"
echo "## - reset /etc/conf.d/keymaps"
echo "## - /etc/localtime"
