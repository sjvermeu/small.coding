#!/bin/sh

# - CONFFILE (path to the configuration file)
# - STEPS (list of steps supported by the script)
# - STEPFROM (step to start from - can be empty)
# - STEPTO (step to go to - can be empty)
# - LOG (log file to use - will always be appended)
# - FAILED (temporary file; as long as it exists, the system did not fail)
# 
# Next, run the following functions:
# initTools;
#
# If you ever want to finish using the libraries, but want to keep the
# script alive, use cleanupTools;
##
## Helper commands
##

typeset CONFFILE=$1;
export CONFFILE;

typeset STEPS="overlay arch profile headers selinux reboot_1 label reboot_2 booleans";
export STEPS;

typeset STEPFROM=$2;
export STEPFROM;

typeset STEPTO=$3;
export STEPTO;

typeset LOG=/tmp/build.log;
export LOG;

typeset FAILED=$(mktemp);
export FAILED;

[ -f master.lib.sh ] && source ./master.lib.sh;

initTools;


##
## Functions
##

enable_overlay() {
  logMessage "   > Add sjvermeu overlay to config... ";
  cd /etc/layman;
  grep -B 9999 '^overlays' layman.cfg > layman.cfg.new;
  echo " http://github.com/sjvermeu/gentoo.overlay/raw/master/overlay.xml" >> layman.cfg.new;
  grep -A 999 '^# Proxy support' layman.cfg >> layman.cfg.new;
  mv layman.cfg.new layman.cfg;
  logMessage "done\n";

  logMessage "   > Add overlays to system... ";
  layman -S || die "Failed to update layman";
  layman -a hardened-development || die "Failed to add hardened-development";
  layman -a sjvermeu || die "Failed to add sjvermeu";
  logMessage "done\n";

  logMessage "   > Update make.conf to use layman... ";
  echo "source /var/lib/layman/make.conf" > /etc/make.conf.new;
  grep -v 'make.conf' /etc/make.conf >> /etc/make.conf.new;
  mv /etc/make.conf.new /etc/make.conf;
  logMessage "done\n";
}

set_arch_packages() {
  logMessage "   > Setting ~arch packages... ";
  mkdir -p /etc/portage/package.accept_keywords;
  cat > /etc/portage/package.accept_keywords/selinux << EOF
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
  logMessage "done\n";
}

set_profile() {
  logMessage "   > Switching profile to 'selinux/v2refpolicy/amd64/hardened'... ";
  eselect profile set selinux/v2refpolicy/amd64/hardened || die "Failed to switch profiles";
  sed -i -e '/FEATURES=/d' /etc/make.conf;
  echo "FEATURES=\"-loadpolicy\"" >> /etc/make.conf;
  logMessage "done\n";
}

upgrade_kernel_headers() {
  logMessage "   > Upgrading linux kernel headers... ";
  emerge -gu sys-kernel/linux-headers || die "Failed to upgrade kernel headers";
  logMessage "done\n";

  logMessage "   > Rebuilding glibc... ";
  emerge -g1 glibc || die "Failed to upgrade glibc";
  logMessage "done\n";
}

configure_selinux() {
  logMessage "   > Installing SELinux utilities.\n";
  logMessage "     - Installing checkpolicy... ";
  emerge -g1 checkpolicy || die "Failed to install checkpolicy";
  logMessage "done\n";
  logMessage "     - Installing policycoreutils... ";
  emerge -g1 policycoreutils || die "Failed to install policycoreutils";
  logMessage "done\n";
  logMessage "     - Installing selinux-base-policy... ";
  FEATURES="-selinux" emerge selinux-base-policy || die "Failed to install SELinux base policy";
  logMessage "done\n";
  logMessage "   > Upgrading system (-uDN world)... ";
  emerge -guDN world || die "Failed to upgrade system (upgrade world)";
  logMessage "done\n";
  logMessage "   > Installing additional SELinux utilities.\n";
  logMessage "     - Installing setools... ";
  emerge -g setools || die "Failed to install setools";
  logMessage "done\n";
  logMessage "     - Installing sepolgen... ";
  emerge -g sepolgen || die "Failed to install sepolgen";
  logMessage "done\n";
  logMessage "     - Installing checkpolicy again... ";
  emerge -g checkpolicy || die "Failed to install checkpolicy";
  logMessage "done\n";

  logMessage "   > Storing POLICY_TYPES=\"strict\" in make.conf... ";
  grep -v POLICY_TYPES /etc/make.conf > /etc/make.conf.new;
  echo "POLICY_TYPES=\"strict\"" >> /etc/make.conf.new;
  mv /etc/make.conf.new /etc/make.conf;
  logMessage "done\n";
}

label_system() {
  logMessage "   > Labelling the dev system... ";
  mkdir -p /mnt/gentoo;
  mount -o bind / /mnt/gentoo;
  setfiles -r /mnt/gentoo /etc/selinux/strict/contexts/files/file_contexts /mnt/gentoo/dev || die "Failed to run setfiles";
  umount /mnt/gentoo;
  logMessage "done\n";

  logMessage "   > Labelling the entire system... ";
  rlpkg -a -r || die "Failed to relabel the entire system";
  logMessage "done\n";
}

set_booleans() {
  logMessage "   > Setting global_ssp boolean... ";
  setsebool -P global_ssp on || die "Failed to set global boolean";
  logMessage "done\n";
}

fail_reboot() {
  logMessage "   ** PLEASE REBOOT THE ENVIRONMENT AND CONTINUE WITH THE NEXT STEP **\n";
  die "Please reboot.";
}

##
## Main
## 

stepOK "overlay" && (
logMessage ">>> Step \"overlay\" starting...\n";
runStep enable_overlay;
);
nextStep;

stepOK "arch" && (
logMessage ">>> Step \"arch\" starting...\n";
runStep set_arch_packages;
);
nextStep;

stepOK "profile" && (
logMessage ">>> Step \"profile\" starting...\n";
runStep set_profile;
);
nextStep;

stepOK "headers" && (
logMessage ">>> Step \"headers\" starting...\n";
runStep upgrade_kernel_headers;
);
nextStep;

stepOK "selinux" && (
logMessage ">>> Step \"selinux\" starting...\n";
runStep configure_selinux;
);
nextStep;

stepOK "reboot_1" && (
logMessage ">>> Step \"reboot_1\" starting...\n";
runStep fail_reboot;
);
nextStep;

stepOK "label" && (
logMessage ">>> Step \"label\" starting...\n";
runStep label_system;
);
nextStep;

stepOK "reboot_2" && (
logMessage ">>> Step \"reboot_2\" starting...\n";
runStep fail_reboot;
);
nextStep;

stepOK "booleans" && (
logMessage ">>> Step \"booleans\" starting...\n";
runStep set_booleans;
);
nextStep;

cleanupTools;
rm ${FAILED};
