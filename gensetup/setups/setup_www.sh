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

typeset STEPS="configsystem installapache";
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
[ -f common.lib.sh ] && source ./common.lib.sh;

initTools;


##
## Functions
##

configsystem() {
  _configsystem;
  die "Please restart the network and continue with step installapache.";
}

installapache() {
  logMessage "  > Installing 'apache'... ";
  installSoftware -u apache || die "Failed to install Apache (emerge failed)";
  logMessage "done\n";

  logMessage "  > Adding apache to default runlevel... ";
  rc-update add apache2 default
  logMessage "done\n";

  logMessage "  > Updating /etc/conf.d/apache... ";
  typeset FILE=/etc/conf.d/apache2;
  typeset META=$(initChangeFile ${FILE});
  setOrUpdateQuotedVariable APACHE2_OPTS "=" "-D DEFAULT_VHOST -D INFO -D SSL -D SSL_DEFAULT_VHOST -D LANGUAGE -D PHP5" ${FILE};
  applyMetaOnFile ${FILE} ${META};
  commitChangeFile ${FILE} ${META};
  logMessage "done\n";
}

installsquirrel() {
  logMessage "  > Installing squirrelmail... "
  installSoftware -u squirrelmail || die "Failed to install Squirrelmail";
  logMessage "done\n";

  logMessage "  > Configuring squirrelmail... ";
  typeset ATOM=$(qlist -IC squirrelmail);
  typeset SVERS=$(qlist -ICv squirrelmail | sed -e "s:${ATOM}-::g");
  webapp-config -I -h localhost -d /mail squirrelmail ${SVERS} || die "Failed to install squirrelmail";
  logMessage "done\n";

  logMessage "  > Setting httpd_can_network_connect* to on... ";
  setsebool -P httpd_can_network_connect on;
  setsebool -P httpd_can_sendmail on;
  #setsebool -P httpd_can_network_connect_db on; 
  #^^ looks like this isn't needed for phpmyadmin to work?
  logMessage "done\n";

  logMessage "  > Mark writeable files as such... ";
  mkdir -p /var/spool/squirrelmail/attach;
  chown apache:apache /var/spool/squirrelmail/attach;
  restorecon -R -r /var/www/localhost;
  chcon -R -t httpd_squirrelmail_t /var/spool/squirrelmail;
  chcon -R -t httpd_squirrelmail_t /var/www/localhost/htdocs/squirrelmail/data;
  logMessage "done\n";

  logMessage "  > Edit php.ini... ";
  typeset FILE=/etc/php/apache2-php5*/php.ini;
  typeset META=$(initChangeFile ${FILE});
  setOrUpdateQuotedVariable date.timezone "=" "$(getValue php.date_timezone)" ${FILE};
  applyMetaOnFile ${FILE} ${META};
  commitChangeFile ${FILE} ${META};
  logMessage "done\n";

  logMessage "  > Symlinking libphp5.so... ";
  pushd /usr/lib64/apache2/modules;
  ln -s /usr/lib64/php*/apache2/libphp5.so . || die "Failed to set symlink"
  logMessage "done\n";


}

stepOK "configsystem" && (
logMessage ">>> Step \"configsystem\" starting...\n";
runStep configsystem;
);
nextStep;

stepOK "installapache" && (
logMessage ">>> Step \"installapache\" starting...\n";
runStep installapache;
);
nextStep;

stepOK "installsquirrel" && (
logMessage ">>> Step \"installsquirrel\" starting...\n";
runStep installsquirrel;
);
nextStep;

cleanupTools;
rm ${FAILED};
