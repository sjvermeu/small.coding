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

typeset STEPS="configsystem installzabbix configzabbix setuppam";
export STEPS;

typeset STEPFROM=$2;
export STEPFROM;

typeset STEPTO=$3;
export STEPTO;

typeset LOG=/tmp/build.log;
export LOG;

typeset FAILED=$(mktemp);
export FAILED;

[ -f master.lib.sh ] && source ./master.lib.sh || exit 1;
[ -f common.lib.sh ] && source ./common.lib.sh || exit 1;

initTools;


##
## Functions
##

configsystem() {
  _configsystem;
}

installzabbix() {
  logMessage "  - Preparing zabbix installation... ";
  echo "net-analyzer/zabbix server" >> /etc/portage/package.use/zabbix;
  logMessage "done\n";

  logMessage "  - Installing zabbix SELinux module... ";
  installSoftware -u selinux-zabbix || die "Failed to install zabbix selinux module";
  logMessage "done\n";

  logMessage "  - Installing zabbix (non-binary package)... ";
  # The installation will not trigger the binary package as the binary package only contains the agent.
  installSoftware -u zabbix || die "Failed to install zabbix application (server)";
  logMessage "done\n";
}

configzabbix() {
  logMessage "  - Setting up zabbix database (schema)... ";
  mysql -u zabbix --password=$(getValue mysql.zabbix.password) -h mail1 zabbix < /usr/share/zabbix/database/create/schema/mysql.sql || die "Failed to load zabbix schema";
  logMessage "done\n";

  logMessage "  - Setting up zabbix database (data)... ";
  mysql -u zabbix --password=$(getValue mysql.zabbix.password) -h mail1 zabbix < /usr/share/zabbix/database/create/data/data.sql || die "Failed to load zabbix data";
  logMessage "done\n";

  logMessage "  - Setting up zabbix database (images)... ";
  mysql -u zabbix --password=$(getValue mysql.zabbix.password) -h mail1 zabbix < /usr/share/zabbix/database/create/data/images_mysql.sql || die "Failed to load zabbix images";
  logMessage "done\n";

  logMessage "  - Configuring /etc/zabbix/zabbix_server.conf... ";
  typeset FILE=/etc/zabbix/zabbix_server.conf
  typeset META=$(initChangeFile ${FILE});
  updateEqualNoQuotConfFile etc.zabbix.server ${FILE}
  applyMetaOnFile ${FILE} ${META};
  commitChangeFile ${FILE} ${META};
  logMessage "done\n";

  logMessage "  - Adding zabbix-server to default runlevel... ";
  rc-update add zabbix-server default && logMessage "done\n" || die "failed\nCould not add zabbix-server to default runlevel";
}

setuppam() {
  _setuppam;
}

stepOK "configsystem" && (
logMessage ">>> Step \"configsystem\" starting...\n";
runStep configsystem;
);
nextStep;

stepOK "installzabbix" && (
logMessage ">>> Step \"installzabbix\" starting...\n";
runStep installzabbix;
);
nextStep;

stepOK "configzabbix" && (
logMessage ">>> Step \"configzabbix\" starting...\n";
runStep configzabbix;
);
nextStep;

stepOK "setuppam" && (
logMessage ">>> Step \"setuppam\" starting...\n";
runStep setuppam;
);
nextStep;

cleanupTools;
rm ${FAILED};
