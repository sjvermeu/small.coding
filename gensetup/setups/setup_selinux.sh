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

typeset STEPS="overlay arch tmpfs profile headers selinux reboot_1 label reboot_2 booleans";
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

  grep -q 'gentoo.overlay/raw/master/overlay.xml' /etc/layman/layman.cfg;
  if [ $? -ne 0 ];
  then
    typeset FILE=/etc/layman/layman.cfg;
    typeset META=$(initChangeFile ${FILE});
    awk '{print} /^overlays/ {print " http://github.com/sjvermeu/gentoo.overlay/raw/master/overlay.xml"}' ${FILE} > ${FILE}.new;
    mv ${FILE}.new ${FILE};
    applyMetaOnFile ${FILE} ${META};
    commitChangeFile ${FILE} ${META};

    logMessage "done\n";
  else
    logMessage "skipped\n";
  fi

  logMessage "   > Updating overlay data... ";
  typeset SKIP=$(getValue skip.layman);
  if [ "${SKIP}" = "y" ] || [ "${SKIP}" = "yes" ];
  then
    logMessage "skipped\n";
  else
    layman -S || die "Failed to update layman";
    logMessage "done\n";
  fi

  logMessage "   > Add overlay 'hardened-development' to system... ";
  layman -l | grep -q 'hardened-development';
  if [ $? -ne 0 ];
  then
    layman -a hardened-development || die "Failed to add hardened-development";
    logMessage "done\n";
  else
    logMessage "skipped\n";
  fi

  logMessage "   > Add overlay 'sjvermeu' to system... ";
  layman -l | grep -q 'sjvermeu';
  if [ $? -ne 0 ];
  then
    layman -a sjvermeu || die "Failed to add sjvermeu";
    logMessage "done\n";
  else
    logMessage "skipped\n";
  fi

  logMessage "   > Update make.conf to use layman... ";
  grep -q '^source /var/lib/layman/make.conf' /etc/make.conf;
  if [ $? -ne 0 ];
  then
    typeset FILE=/etc/make.conf;
    typeset META=$(initChangeFile ${FILE});
    awk 'BEGIN {print "source /var/lib/layman/make.conf"} {print}' ${FILE} > ${FILE}.new;
    mv ${FILE}.new ${FILE};
    applyMetaOnFile ${FILE} ${META};
    commitChangeFile ${FILE} ${META};
    logMessage "done\n";
  else
    logMessage "skipped\n";
  fi
}

set_tmp_context() {
  logMessage "   > Setting tmp_t context for /tmp... ";
  grep -q '^tmpfs.*object_r:tmp_t' /etc/fstab;
  if [ $? -ne 0 ];
  then
    typeset FILE=/etc/fstab;
    typeset META=$(initChangeFile ${FILE});
    grep -v '[ 	]/tmp' ${FILE} > ${FILE}.new;
    echo "tmpfs   /tmp   tmpfs       defaults,noexec,nosuid,rootcontext=system_u:object_r:tmp_t   0 0" >> ${FILE}.new;
    mv ${FILE}.new ${FILE};
    applyMetaOnFile ${FILE} ${META};
    commitChangeFile ${FILE} ${META};
    logMessage "done\n";
  else
    logMessage "skipped\n";
  fi
}

set_arch_packages() {
  logMessage "   > Setting ~arch packages... ";
  mkdir -p /etc/portage/package.accept_keywords > /dev/null 2>&1;
  cat > /etc/portage/package.accept_keywords/selinux-auto << EOF
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
=net-misc/openssh-5.8_p1-r1
EOF
  logMessage "done\n";
}

set_profile() {
  logMessage "   > Switching profile to 'selinux/v2refpolicy/amd64/hardened'... ";
  eselect profile list | grep -q 'selinux/v2refpolicy/amd64/hardened \*$';
  if [ $? -ne 0 ];
  then
    eselect profile set selinux/v2refpolicy/amd64/hardened || die "Failed to switch profiles";
    logMessage "done\n";
  else
    logMessage "skipped\n";
  fi

  logMessage "   > Setting FEATURES=\"-loadpolicy\"... ";
  grep -q '^FEATURES=.*-loadpolicy' /etc/make.conf;
  if [ $? -ne 0 ];
  then
    typeset FILE=/etc/make.conf;
    typeset META=$(initChangeFile ${FILE});
    typeset CFEAT=$(awk '/^FEATURES=/' ${FILE} | sed -e 's:FEATURES="::g' -e 's:#.*::g' -e 's:"::g');
    sed -i -e '/FEATURES=/d' ${FILE};
    echo "FEATURES=\"${CFEAT} -loadpolicy\"" >> ${FILE};
    commitChangeFile ${FILE} ${META};
    logMessage "done\n";
  else
    logMessage "skipped\n";
  fi
}

upgrade_kernel_headers() {
  logMessage "   > Upgrading linux kernel headers... ";
  LASTVERS=$(versionsort 2.6.36.1 $(ls /var/db/pkg/sys-kernel | grep '^linux-headers-' | sed -e 's:.*linux-headers-::g') | tail -1);
  if [ "${LASTVERS}" = "2.6.36.1" ]
  then
    installSoftware -u '>sys-kernel/linux-headers-2.6.36' || die "Failed to upgrade kernel headers"; 
    logMessage "done\n";

    logMessage "   > Rebuilding glibc (will reinit)\n";
    installSoftware -1 glibc || die "Failed to upgrade glibc";
    logMessage "done\n";
  else
    logMessage "skipped\n";
  fi
}

configure_selinux() {
  logMessage "   > Installing SELinux utilities.\n";
  logMessage "     - Installing checkpolicy... ";
  installSoftware -1 checkpolicy || die "Failed to install checkpolicy";
  logMessage "done\n";
  logMessage "     - Installing policycoreutils... ";
  installSoftware -1 policycoreutils || die "Failed to install policycoreutils";
  logMessage "done\n";
  logMessage "     - Installing selinux-base-policy... ";
  FEATURES="-selinux" installSoftware selinux-base-policy || die "Failed to install SELinux base policy";
  logMessage "done\n";
  logMessage "   > Upgrading system (-uDN world) (might reinit)\n";
  installSoftware -uDN world || die "Failed to upgrade system (upgrade world)";
  logMessage "   > Installing additional SELinux utilities.\n";
  logMessage "     - Installing setools... ";
  installSoftware setools || die "Failed to install setools";
  logMessage "done\n";
  logMessage "     - Installing sepolgen... ";
  installSoftware sepolgen || die "Failed to install sepolgen";
  logMessage "done\n";
  logMessage "     - Installing checkpolicy again... ";
  installSoftware checkpolicy || die "Failed to install checkpolicy";
  logMessage "done\n";

  logMessage "   > Storing POLICY_TYPES value in make.conf... ";
  grep -q "POLICY_TYPES=\"$(getValue POLICY_TYPES)\"" /etc/make.conf;
  if [ $? -ne 0 ];
  then
    typeset FILE=/etc/make.conf
    typeset META=$(initChangeFile ${FILE});
    
    grep -v POLICY_TYPES ${FILE} > ${FILE}.new;
    echo "POLICY_TYPES=\"$(getValue POLICY_TYPES)\"" >> ${FILE}.new;
    mv ${FILE}.new ${FILE};
    applyMetaOnFile ${FILE} ${META};
    commitChangeFile ${FILE} ${META};
    logMessage "done\n";
  else
    logMessage "skipped\n";
  fi
}

label_system() {
  logMessage "   > Labelling the dev system... ";
  mkdir -p /mnt/gentoo > /dev/null 2>&1;
  mount -o bind / /mnt/gentoo;
  TYPE=$(awk -F'=' '/^SELINUXTYPE/ {print $2}' /etc/selinux/config);
  setfiles -r /mnt/gentoo /etc/selinux/${TYPE}/contexts/files/file_contexts /mnt/gentoo/dev || die "Failed to run setfiles";
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
  typeset NEXT_STEP=$(echo ${STEPS} | awk '{print $2}');
  logMessage "   ** PLEASE REBOOT THE ENVIRONMENT AND CONTINUE WITH THE NEXT STEP (${NEXT_STEP})**\n";
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

stepOK "tmpfs" && (
logMessage ">>> Step \"tmpfs\" starting...\n";
runStep set_tmp_context;
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
