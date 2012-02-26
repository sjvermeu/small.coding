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

typeset STEPS="inittest portage selinux exittest";
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

inittest() {
  return
}

portage() {
  logTestMessage portage 001 "Run emerge --info";
  emerge --info | grep -q '^SYNC="' && logOK || logNOK;

  logTestMessage portage 002 "Run emerge -puDN world";
  emerge -puDN world && logOK || logNOK;

  logTestMessage portage 003 "Run emerge cowsay";
  rm /usr/portage/distfiles/cowsay* > /dev/null 2>&1;
  emerge cowsay && logOK || logNOK;

  logTestMessage portage 004 "Run emerge -C cowsay (remove)";
  emerge -C cowsay && logOK || logNOK;

  logTestMessage portage 005 "Run eselect profile list";
  eselect profile list && logOK || logNOK;

  logTestMessage portage 006 "Run gcc-config -l";
  gcc-config -l && logOK || logNOK;

  logTestMessage portage 007 "Running qlist";
  qlist portage | grep -q _selinux.py && logOK || logNOK;

  logTestMessage portage 008 "Running qfile";
  qfile /etc/selinux/config | grep -q selinux-base-policy && logOK || logNOK;
}

selinux() {
  logTestMessage selinux 001 "Run id -Z";
  id -Z | grep -q 'sysadm_r:sysadm_t' && logOK || logNOK;

  logTestMessage selinux 002 "SELinux module store should be semanage_store_t";
  ls -dZ /etc/selinux/strict/modules/active | grep -q 'object_r:semanage_store_t' && logOK || logNOK;

  logTestMessage selinux 003 "Adding fcontext using semanage";
  semanage fcontext -a -t swapfile_t "/testswapfile" && logOK || logNOK;

  logTestMessage selinux 004 "Verifying added fcontext";
  semanage fcontext -l | grep swapfile_t | grep -q testswapfile && logOK || logNOK;

  logTestMessage selinux 005 "Removing fcontext using semanage";
  semanage fcontext -d -t swapfile_t "/testswapfile" && logOK || logNOK;

  logTestMessage selinux 006 "Using chcon";
  chcon -t swapfile_t /etc/hosts && logOK || logNOK;

  logTestMessage selinux 007 "Checking chcon using getfilecon";
  getfilecon /etc/hosts | grep -q 'object_r:swapfile_t' && logOK || logNOK;

  logTestMessage selinux 008 "Restoring context using restorecon -F";
  restorecon -F /etc/hosts && logNOK || logOK; # restorecon <> 0 if changed

  logTestMessage selinux 009 "Verifying privilege using findcon";
  findcon -t net_conf_t /etc | grep -q '/etc/hosts' && logOK || logNOK;

  logTestMessage selinux 010 "Running rlpkg for the bash package";
  rlpkg bash > /dev/null 2>&1 && logOK || logNOK;

  logTestMessage selinux 011 "Querying selinux boolean 'global_ssp'";
  getsebool global_ssp | grep -q ' on' && logOK || logNOK;

  logTestMessage selinux 012 "Changing selinux boolean 'global_ssp'";
  setsebool global_ssp off && logOK || logNOK;

  logTestMessage selinux 013 "Getting selinux boolean 'global_ssp'";
  getsebool -a | grep global_ssp | grep -q off && logOK || logNOK;

  logTestMessage selinux 014 "Revering 'global_ssp' boolean";
  togglesebool global_ssp | grep -q active && logOK || logNOK;

  logTestMessage selinux 015 "Getting SELinux state";
  sestatus | grep -q 'enabled' && logOK || logNOK;

  logTestMessage selinux 016 "Getting information on crontab_t using seinfo";
  seinfo -tcrontab_t -x | grep -q ubac_constrained_type && logOK || logNOK;

  logTestMessage selinux 017 "Getting information on crontab_t using sesearch";
  sesearch -t crontab_t -c file -p write -A -d | grep -q 'allow crontab_t' && logOK || logNOK;

  logTestMessage selinux 018 "Getting process information (init process)";
  ps -Z $(pidof init) | grep -q 'system_u:system_r:init_t' && logOK || logNOK;

  logTestMessage selinux 019 "Getting boolean description using semanage";
  semanage boolean -l | grep global_ssp | grep -q ' on' && logOK || logNOK;

  logTestMessage selinux 020 "Setting login for user to staff_u";
  semanage login -a -s staff_u user && logOK || logNOK;

  logTestMessage selinux 021 "Getting login information using semanage";
  semanage login -l | grep user | grep -q staff_u && logOK || logNOK;

  logTestMessage selinux 022 "Removing login from user (staff_u)";
  semanage login -d -s staff_u user && logOK || logNOK;

  logTestMessage selinux 023 "Getting port information using semanage";
  semanage port -l | grep -q '22$' && logOK || logNOK;

  logTestMessage selinux 024 "Checking if AVC denials are being logged";
  tail -1 /var/log/avc.log | grep scontext | grep -qi denied && logOK || logNOK;

  logTestMessage selinux 025 "Checking if audit2allow works";
  echo "Jul  7 19:58:45 hpl kernel: [ 7536.178993] type=1400 audit(1310061525.302:645): avc:  denied  { unlink } for  pid=5483 comm=\"syslog-ng\" name=\"syslog-ng.persist\" dev=dm-3 ino=73 scontext=system_u:system_r:syslogd_t tcontext=system_u:object_r:var_lib_t tclass=file" | audit2allow -m test | grep -q 'allow syslogd_t var_lib_t:file unlink;' && logOK || logNOK;

  logTestMessage selinux 026 "Checking SELinux policy build (checkmodule)";
  F=$(mktemp);
  cat > ${F} << EOF
module test 1.0;

require {
  type syslogd_t;
  type var_lib_t;
  class file unlink;
}
allow syslogd_t var_lib_t:file unlink;
EOF
  checkmodule -m -o ${F}.mod ${F} && logOK || logNOK;

  logTestMessage selinux 027 "Checking SELinux policy build (semodule_package)";
  semodule_package -o ${F}.pp -m ${F}.mod && logOK || logNOK;

  restorecon -R /etc/selinux;

  logTestMessage selinux 028 "Checking if a SELinux policy can be loaded";
  semodule -i ${F}.pp && logOK || logNOK;

  logTestMessage selinux 029 "Checking if a SELinux policy can be unloaded";
  semodule -r test && logOK || logNOK;

  rm -f ${F} ${F}.pp ${F}.mod;

  logTestMessage selinux 030 "Listing installed modules";
  semodule -l | grep -q ldap && logOK || logNOK;

  logTestMessage selinux 031 "Checking enforcing state";
  getenforce | grep -q Enforcing && logOK || logNOK;

  logTestMessage selinux 032 "Switching enforcing state";
  setenforce 0 && setenforce 1 && logOK || logNOK;

  logTestMessage selinux 033 "Rebuilding base with dontaudit disabled";
  semodule -D -B && logOK || logNOK;

  logTestMessage selinux 034 "Switching back to base with dontaudits";
  semodule -B && logOK || logNOK;
}

exittest() {
  return
}

stepOK "inittest" && (
logTestMessage inittest "- -" "(No need to initialize tests)";
logMessage "\n";
runStep inittest;
);
nextStep;

stepOK "portage" && (
logTestMessage portage "- -" "Performing portage activities";
logMessage "\n";
runStep portage;
);
nextStep;

stepOK "selinux" && (
logTestMessage selinux "- -" "Performing SELinux activities";
logMessage "\n";
runStep selinux;
);
nextStep;

stepOK "exittest" && (
logTestMessage exittest "- -" "(No need to clean up tests)";
logMessage "\n";
runStep exittest;
);
nextStep;

cleanupTools;
rm ${FAILED};
