#!/bin/sh

# Licensed under GPL-3
#

##
## This script performs a semi-automatic conversion of a system to Gentoo
## Hardened SELinux.
##
## NOT FOR PRODUCTION USE
##
## Usage: update2selinux.sh <1 | 2 | 3>

export GLOBALEXIT=0;

die() {
  echo "ERROR - Previous step failed! Error message was: "
  echo "ERROR - $*";
  GLOBALEXIT=1;
  exit 1;
}

enable_overlay() {
  [ ${GLOBALEXIT} -ne 0 ] && return 1;
  # Add sjvermeu overlay to known list of overlays
  cd /etc/layman;
  grep -B 9999 '^overlays' layman.cfg > layman.cfg.new;
  echo "          http://github.com/sjvermeu/gentoo.overlay/raw/master/overlay.xml" >> layman.cfg.new;
  grep -A 9999 '^# Proxy support' layman.cfg >> layman.cfg.new;
  mv layman.cfg.new layman.cfg;

  # Add hardened-development and sjvermeu overlays
  layman -a hardened-development || die "Failed to add hardened-development";
  layman -a sjvermeu || die "Failed to add sjvermeu";

  # Add layman's make.conf to make.conf
  echo "source /var/lib/layman/make.conf" > /etc/make.conf.new;
  grep -v 'make.conf' /etc/make.conf >> /etc/make.conf.new;
  mv /etc/make.conf.new /etc/make.conf;
}

set_arch_packages() {
  [ ${GLOBALEXIT} -ne 0 ] && return 1;
  mkdir -p /etc/portage/package.accept_keywords;
  cat > /etc/portage/package.accept_keywords << EOF
sys-libs/libselinux
sys-apps/policycoreutils
sys-libs/libsemanage
sys-libs/libsepol
app-admin/setools
dev-python/sepolgen
sys-apps/checkpolicy
sec-policy/*
=sys-process/vixie-cron-4.1-r11
=sys-kernel/linux-headers-2.6.36.1
EOF
}

set_profile() {
  [ ${GLOBALEXIT} -ne 0 ] && return 1;
  eselect profile set selinux/v2refpolicy/amd64/hardened || die "Failed to switch profiles";
  sed -i -e '/FEATURES=/d' /etc/make.conf;
  echo "FEATURES=\"-loadpolicy\"" >> /etc/make.conf;
}

upgrade_kernel_headers() {
  [ ${GLOBALEXIT} -ne 0 ] && return 1;
  emerge -u sys-kernel/linux-headers || die "Failed to upgrade kernel headers";
  emerge -1 glibc || die "Failed to upgrade glibc";
}

configure_selinux() {
  [ ${GLOBALEXIT} -ne 0 ] && return 1;
  emerge -1 checkpolicy policycoreutils || die "Failed to install SELinux utilities";
  FEATURES="-selinux" emerge selinux-base-policy || die "Failed to install SELinux base policy";
  emerge -uDN world || die "Failed to upgrade system (update world)";
  emerge setools sepolgen checkpolicy || die "Failed to install optional SELinux utilities";
  echo "POLICY_TYPES=\"strict\"" >> /etc/make.conf;
}

label_system() {
  [ ${GLOBALEXIT} -ne 0 ] && return 1;
  mkdir -p /mnt/gentoo;
  mount -o bind / /mnt/gentoo;
  setfiles -r /mnt/gentoo /etc/selinux/strict/contexts/files/file_contexts /mnt/gentoo/dev || die "Failed to run setfiles";
  umount /mnt/gentoo;
  rlpkg -a -r;
}

set_booleans() {
  setsebool -P global_ssp on || die "Failed to set global boolean";
}

if [ "${1}" = "1" ];
then

# Enable the overlays
enable_overlay;
# Set the proper ~arch packages
set_arch_packages;
# Switch the Gentoo profile to selinux/v2refpolicy/amd64/server
set_profile;
# Upgrade the kernel headers
upgrade_kernel_headers;
# Configure SELinux
configure_selinux;
# Restart system
shutdown -r now;

elif [ "${1}" = "2" ];
then

# Label system
label_system;
# restart system
shutdown -r now;

elif [ "${1}" = "3" ];
then

# Set proper boolean
set_booleans;

fi
