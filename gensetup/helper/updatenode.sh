#!/bin/sh

# First, we check if we have an address that can ping "workstation"
WORKSTATION="2001:db8:81:e2:0:26b5:365b:5072"
ERR=1;

echo ">>> Trying to ping the workstation target... ";
ping6 -c 1 ${WORKSTATION}
if [ $? -ne 0 ];
then
  echo "<<< Failed to ping the workstation target."
  echo "<<< Please setup networking and make sure an IPv6 address"
  echo "<<< is assigned to the system."
  exit ${ERR};
fi

ERR=$((${ERR}+1));

# Great, now let us try and mount the portage tree
echo ">>> Mounting remote portage tree... ";
mount "[${WORKSTATION}]:gentoo/portage" -t nfs4 -o ro,soft,timeo=30 /usr/portage
if [ $? -ne 0 ];
then
  echo "<<< Failed to mount remote Portage tree."
  echo "<<< Check the logs, update this script."
  exit ${ERR};
fi

ERR=$((${ERR}+1));

# Mount packages
echo ">>> Ensuring /var/portage/packages exists.";
mkdir -p /var/portage/packages && restorecon -Rv /var/portage;
if [ $? -ne 0 ];
then
  echo "<<< Could not create /var/portage/packages and/or restore its context.";
  exit ${ERR};
fi

ERR=$((${ERR}+1));

echo ">>> Mounting remote packages location... ";
mount "[${WORKSTATION}]:gentoo/packages" -t nfs4 -o rw,soft,timeo=30,context="system_u:object_r:portage_ebuild_t" /var/portage/packages;
if [ $? -ne 0 ];
then
  echo "<<< Failed to mount remote Packages location."
  echo "<<< Check the logs, and update this script"
  exit ${ERR};
fi

ERR=$((${ERR}+1));

echo ">>> Ensuring /mnt/puppet exists.";
mkdir -p /mnt/puppet && restorecon -Rv /mnt/puppet;
if [ $? -ne 0 ];
then
  echo "<<< Could not create /mnt/puppet and/or restore its context.";
  exit ${ERR};
fi

ERR=$((${ERR}+1));

echo ">>> Mounting remote puppet... ";
mount "[${WORKSTATION}]:puppet" -t nfs4 -o ro,soft,timeo=30 /mnt/puppet;
if [ $? -ne 0 ];
then
  echo "<<< Failed to mount remote Puppet location."
  exit ${ERR};
fi

ERR=$((${ERR}+1));

echo ">>> Creating temporary make.conf";
if [ -f /etc/portage/make.conf ];
then
  mv /etc/portage/make.conf /etc/portage/make.conf.orig;
  if [ $? -ne 0 ];
  then
    echo "<<< Failed to move make.conf to make.conf.orig";
    exit ${ERR};
  fi

  ERR=$((${ERR}+1));
fi

echo > /etc/portage/make.conf.upgrade << EOF
CFLAGS="-march=x86-64 -O2 -pipe"
CXXFLAGS="-march=x86-64 -O2 -pipe"
FEATURES="buildpkg"
GENTOO_MIRRORS="http://workstation:8080/gensetup/gentoo \${GENTOO_MIRRORS}"
LDFLAGS="\${LDFLAGS} -Wl,--hash-style=gnu"
MAKEOPTS="-j2"
POLICY_TYPES="targeted strict mcs mls"
USE="-ldap -gtk -xorg -pppe mysql imap ipv6 libwww maildir sasl ssl unicode xml apache2 -gpm ubac bcmath gd sockets truetype agent png -sqlite3 device-mapper dlz"
DISTDIR="/var/portage/distfiles"
PKGDIR="/var/portage/packages"
EOF
if [ $? -ne 0 ];
then
  echo "<<< Could not create make.conf.upgrade";
  exit ${ERR};
fi

ERR=$((${ERR}+1));

ln -sf /etc/portage/make.conf.upgrade /etc/portage/make.conf;
if [ $? -ne 0 ];
then
  echo "<<< Could not link make.conf to make.conf.upgrade";
  exit ${ERR};
fi


