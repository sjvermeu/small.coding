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

# certificates was between installsasl and updatepostfix
typeset STEPS="configsystem installpostfix installcourier installsasl updatepostfix vmail installmysql startmysql loadsql installapache phpmyadmin mysqlauth mysqlpostfix setuppam";
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
  die "Please restart networking and continue with installpostfix."
}

installpostfix() {
  logMessage "  > Installing 'postfix'... ";
  installSoftware -u postfix || die "Failed to install Postfix (emerge failed)";
  logMessage "done\n";

  logMessage "  > Updating main.cf... ";
  updateEqualNoQuotConfFile postfix.1.main /etc/postfix/main.cf;
  logMessage "done\n";

  logMessage "  > Updating master.cf... ";
  typeset FILE=/etc/postfix/master.cf;
  typeset META=$(initChangeFile ${FILE});
  sed -i -e 's:smtpd$:smtpd -v:g' ${FILE};
  applyMetaOnFile ${FILE} ${META};
  commitChangeFile ${FILE} ${META};
  logMessage "done\n";

  logMessage "  > Relabelling /var/spool/postfix... ";
  restorecon -R -r /var/spool/postfix;
  logMessage "done\n";

  logMessage "  > Adding postfix to default runlevel... ";
  rc-update add postfix default;
  logMessage "done\n";
}

installcourier() {
  logMessage "  > Installing 'courier-imap' and 'courier-authlib'... ";
  installSoftware -u courier-imap courier-authlib || die "Failed to install Courier software (emerge failed)";
  logMessage "done\n";

#  logMessage "  > Updating pop3.cnf... ";
#  typeset FILE=/etc/courier-imap/pop3d.cnf;
#  typeset META=$(initChangeFile ${FILE});
#  sed -i -e "s:^C ?=.*:C=$(getValue courier.ssl.C):g" ${FILE};
#  sed -i -e "s:^ST ?=.*:ST=$(getValue courier.ssl.ST):g" ${FILE};
#  sed -i -e "s:^L ?=.*:L=$(getValue courier.ssl.L):g" ${FILE};
#  sed -i -e "s:^O ?=.*:O=$(getValue courier.ssl.O):g" ${FILE};
#  sed -i -e "s:^OU ?=.*:OU=$(getValue courier.ssl.OU):g" ${FILE};
#  sed -i -e "s:^CN ?=.*:CN=$(getValue courier.ssl.CN):g" ${FILE};
#  sed -i -e "s:^emailAddress ?=.*:emailAddress=$(getValue courier.ssl.emailAddress):g" ${FILE};
#  applyMetaOnFile ${FILE} ${META};
#  commitChangeFile ${FILE} ${META};
#  logMessage "done\n";

#  logMessage "  > Updating imapd.cnf... ";
#  typeset FILE=/etc/courier-imap/imapd.cnf;
#  typeset META=$(initChangeFile ${FILE});
#  sed -i -e "s:^C ?=.*:C=$(getValue courier.ssl.C):g" ${FILE};
#  sed -i -e "s:^ST ?=.*:ST=$(getValue courier.ssl.ST):g" ${FILE};
#  sed -i -e "s:^L ?=.*:L=$(getValue courier.ssl.L):g" ${FILE};
#  sed -i -e "s:^O ?=.*:O=$(getValue courier.ssl.O):g" ${FILE};
#  sed -i -e "s:^OU ?=.*:OU=$(getValue courier.ssl.OU):g" ${FILE};
#  sed -i -e "s:^CN ?=.*:CN=$(getValue courier.ssl.CN):g" ${FILE};
#  sed -i -e "s:^emailAddress ?=.*:emailAddress=$(getValue courier.ssl.emailAddress):g" ${FILE};
#  applyMetaOnFile ${FILE} ${META};
#  commitChangeFile ${FILE} ${META};
#  logMessage "done\n";
#
#  logMessage "  > Running mkpop3dcert... ";
#  mkpop3dcert;
#  if [ $? -ne 0 ] && [ ! -f /etc/courier-imap/pop3d.pem ]; # file exists
#  then
#    die "Failed to run mkpop3dcert";
#  fi
#  logMessage "done\n";
#
#  logMessage "  > Running mkimapdcert... ";
#  mkimapdcert;
#  if [ $? -ne 0 ] && [ ! -f /etc/courier-imap/imapd.pem ];
#  then
#    die "Failed to run mkipapcert";
#  fi
#  logMessage "done\n";
#
  for FILENM in imapd pop3d;
  do
    logMessage "  > Updating /etc/courier-imap/${FILENM} file... ";
    FILE=/etc/courier-imap/${FILENM}
    META=$(initChangeFile ${FILE});
    setOrUpdateUnquotedVariable PIDFILE "=" /var/run/courier/${FILENM}.pid ${FILE}
    applyMetaOnFile ${FILE} ${META};
    commitChangeFile ${FILE} ${META};
    logMessage "done\n";

#    logMessage "  > Updating /etc/courier-imap/${FILENM}-ssl file... ";
#    FILE=/etc/courier-imap/${FILENM}-ssl
#    META=$(initChangeFile ${FILE});
#    setOrUpdateUnquotedVariable SSLPIDFILE "=" /var/run/courier/${FILENM}-ssl.pid ${FILE}
#    setOrUpdateUnquotedVariable TLS_CACHEFILE "=" /var/run/courier-imap/couriersslcache ${FILE}
#    applyMetaOnFile ${FILE} ${META};
#    commitChangeFile ${FILE} ${META};
#    logMessage "done\n";
  done

  logMessage "  > Creating /var/run/courier location... ";
  mkdir -p /var/run/courier/authdaemon;
  restorecon -R /var/run/courier;
  logMessage "done\n";

  logMessage "  > Setting privileges on /var/lib/courier... ";
  restorecon -R /var/lib/courier;
  logMessage "done\n";

  logMessage "  > Creating link from lib to run (authdaemon)... ";
  pushd /var/lib/courier;
  rm -rf authdaemon;
  ln -s /var/run/courier/authdaemon;
  popd;
  logMessage "done\n";

  logMessage "  > Relabelling courier-authlib... ";
  rlpkg courier-authlib;
  logMessage "done\n";

  logMessage "  > Adding courier-imapd to default runlevel... ";
  rc-update add courier-imapd default;
  logMessage "done\n";
}

installsasl() {
  logMessage "  > Installing selinux-sasl... ";
  installSoftware -u selinux-sasl || die "Failed to install selinux-sasl"
  logMessage "done\n";

  logMessage "  > Installing cyrus-sasl... "
  installSoftware -u cyrus-sasl || die "Failed to install cyrus-sasl"
  logMessage "done\n";

  logMessage "  > Editing /etc/sasl2/smtpd.conf... ";
  typeset FILE=/etc/sasl2/smtpd.conf;
  typeset META=$(initChangeFile ${FILE});
  sed -i -e '/^mech_list/d' ${FILE};
  sed -i -e '/^pwcheck_method/d' ${FILE};
  echo "mech_list: $(getValue sasl.smtpd.mech_list)" >> ${FILE};
  echo "pwcheck_method: $(getValue sasl.smtpd.pwcheck_method)" >> ${FILE};
  applyMetaOnFile ${FILE} ${META};
  commitChangeFile ${FILE} ${META};
  logMessage "done\n";

  logMessage "  > Editing /etc/conf.d/saslauthd... ";
  FILE=/etc/conf.d/saslauthd
  META=$(initChangeFile ${FILE});
  sed -i -e '/^SASLAUTHD_OPTS=/d' ${FILE};
  echo "SASLAUTHD_OPTS=$(getValue sasl.saslauthd.SASLAUTHD_OPTS)" >> ${FILE};
  applyMetaOnFile ${FILE} ${META};
  commitChangeFile ${FILE} ${META};
  logMessage "done\n";

  logMessage "  > Adding saslauthd to default runlevel... ";
  rc-update add saslauthd default;
  logMessage "done\n";

  logMessage "  > Relabelling files for cyrus-sasl... ";
  rlpkg cyrus-sasl;
  logMessage "done\n";
}

certificates() {
  logMessage "  > Editing openssl.cnf... ";
  typeset FILE=/etc/ssl/openssl.cnf;
  typeset META=$(initChangeFile ${FILE});
  sed -i -e "s:^countryName_default.*:countryName_default = $(getValue openssl.cnf.countryName_default):g" ${FILE};
  sed -i -e "s:^stateOrProvinceName_default.*:stateOrProvinceName_default = $(getValue openssl.cnf.stateOrProvinceName_default):g" ${FILE};
  sed -i -e "s:^localityName_default.*:localityName_default = $(getValue openssl.cnf.localityName_default):g" ${FILE};
  sed -i -e "s:^0.organizationName_default.*:0.organizationName_default = $(getValue openssl.cnf.0_organizationName_default):g" ${FILE};
  # commonName_default is not given by default
  awk '/^commonName_max/ {print "commonName_default = Foo";} {print}' ${FILE} > ${FILE}.new;
  mv ${FILE}.new ${FILE};
  sed -i -e "s:^commonName_default.*:commonName_default = $(getValue openssl.cnf.commonName_default):g" ${FILE};
  sed -i -e "s:^emailAddress_default.*:emailAddress_default = $(getValue openssl.cnf.emailAddress_default):g" ${FILE};
  applyMetaOnFile ${FILE} ${META};
  commitChangeFile ${FILE} ${META};
  logMessage "done\n";

  pushd /etc/ssl/misc;

  logMessage "  > Running CA.pl -newreq-nodes... ";
  printf "\n\n\n\n\n\n\n\n\n" | ./CA.pl -newreq-nodes || die "Failed to run CA.pl -newreq-nodes"
  logMessage "done\n";

  logMessage "  > Now running CA.pl -newca\n";
  logMessage "  > Use the following answers:\n";
  logMessage "  > <return>$(getValue openssl.CA.privkey_pass)<return>$(getValue openssl.CA.privkey_pass)<10 x return>$(getValue openssl.CA.privkey_pass)<return>\n";
  ./CA.pl -newca || die "Failed to run CA.pl -newca"

  logMessage "  > Now running CA.pl -sign\n";
  logMessage "  > Use the following answers:\n";
  logMessage "  > $(getValue openssl.CA.privkey_pass)<return>y<return>\n";
  ./CA.pl -sign || die "Failed to run CA.pl -sign";

  logMessage "  > Copying certificates to postfix location... ";
  cp newcert.pem /etc/postfix || die "Failed to copy certificate newcert.pem";
  cp newkey.pem /etc/postfix || die "Failed to copy key newkey.pem";
  cp demoCA/cacert.pem /etc/postfix || die "Failed to copy certificate store cacert.pem";
  logMessage "done\n";

  logMessage "  > Creating certificates for Apache... ";
  printf "$(getValue openssl.httpd.privkey_pass)\n\n\n\n\n\n\n\n\n\n" | openssl req -new > new.cert.csr || die "Failed to create new request certificate";
  printf "$(getValue openssl.httpd.privkey_pass)\n" | openssl rsa -in privkey.pem -out new.cert.key || die "Failed to create new certificate";
  openssl x509 -in new.cert.csr -out new.cert.cert -req -signkey new.cert.key -days 365 || die "Failed to sign certificates";
  logMessage "done\n";

  popd;
}

updatepostfix() {
  logMessage "  > Updating main.cf... ";
  updateEqualNoQuotConfFile postfix.1.main /etc/postfix/main.cf;
  logMessage "done\n";
}

vmail() {
  logMessage "  > Creating vmail user... ";
  getent passwd vmail;
  if [ $? -ne 0 ];
  then
    useradd -d /home/vmail -s /bin/false -m vmail;
    logMessage "done\n";
  else
    logMessage "skipped\n";
  fi

  logMessage "  > Creating mailbox infrastructure... ";
  mkdir -p /home/vmail/virt-domain.com/user1
  mkdir -p /home/vmail/virt-domain.com/user2
  maildirmake /home/vmail/virt-domain.com/user1/.maildir
  maildirmake /home/vmail/virt-domain.com/user2/.maildir
  chown -R vmail:vmail /home/vmail/virt-domain.com
  logMessage "done\n";
}

installmysql() {
  logMessage "  > Installing MySQL... ";
  installSoftware -u mysql || die "Failed to install MySQL"
  logMessage "done\n";

  logMessage "  > Downloading genericmailsql.sql file... ";
  if [ ! -f genericmailsql.sql ];
  then
    wget $(getValue mysql.genericmailsql.url);
    sed -i -e 's:^----:-- --:g' genericmailsql.sql;
    logMessage "done\n";
  else
    logMessage "skipped\n";
  fi

  logMessage "  > Adding mysql to default runlevel... ";
  rc-update add mysql default;
  logMessage "done\n";
}

startmysql() {
  logMessage "  > Running 'emerge --config myqsl'... ";
  export MYSQL_ROOT_PASSWORD=$(mysql.root.password);
  emerge --config mysql;
  logMessage "done\n";

  logMessage "  > Starting mysql service... ";
  run_init /etc/init.d/mysql start;
  logMessage "done\n";

  logMessage "  > Running mysql_secure_installation... ";
  printf "N\n\n\n\n\n\n\n\n\n\n\n\n\n\n" | mysql_secure_installation;
  logMessage "done\n";

  logMessage "  > Configuring mysql for network access... ";
  typeset FILE=/etc/mysql/my.cnf;
  typeset META=$(initChangeFile ${FILE});
  updateEqualNoQuotConfFile mysql.conf ${FILE};
  applyMetaOnFile ${FILE} ${META};
  commitChangeFile ${FILE} ${META};
  logMessage "done\n";
}

loadsql() {
  logMessage "  > Creating mailsql database... ";
  mysqladmin -u root --password=$(getValue mysql.root.password) create mailsql;
  if [ $? -eq 0 ];
  then
    logMessage "done\n";

    logMessage "  > Populating with genericmailsql.sql file... ";
    mysql -u root --password=$(getValue mysql.root.password) mailsql < genericmailsql.sql;
    echo "GRANT SELECT,INSERT,UPDATE,DELETE ON mailsql.* TO mailsql@localhost IDENTIFIED BY '$(getValue mysql.mailsql.password)'; FLUSH PRIVILEGES;" | mysql -u root --password=$(getValue mysql.root.password);
    logMessage "done\n";
  else
    logMessage "skipped\n";
  fi

  logMessage "  > Creating zabbix database... ";
  mysqladmin -u root --password=$(getValue mysql.root.password) create zabbix;
  if [ $? -eq 0 ];
  then
    logMessage "done\n";

    logMessage "  > Generating privileges for zabbix... ";
    echo "GRANT ALL ON zabbix.* TO 'zabbix'@'zabbix.virtdomain.com' IDENTIFIED BY '$(getValue mysql.zabbix.password)'; FLUSH PRIVILEGES;" | mysql -u root --password=$(getValue mysql.root.password);
    echo "GRANT ALL ON zabbix.* TO 'zabbix'@'www1.virtdomain.com' IDENTIFIED BY '$(getValue mysql.zabbix.password)'; FLUSH PRIVILEGES;" | mysql -u root --password=$(getValue mysql.root.password);
    echo "GRANT ALL ON zabbix.* TO 'zabbix'@'www2.virtdomain.com' IDENTIFIED BY '$(getValue mysql.zabbix.password)'; FLUSH PRIVILEGES;" | mysql -u root --password=$(getValue mysql.root.password);
    logMessage "done\n";
  else
    logMessage "skipped\n";
  fi
}

installapache() {
  logMessage "  > Installing apache... ";
  installSoftware -u apache;
  if [ $? -ne 0 ];
  then
    logMessage "failed\n";
    logMessage "    Trying to apply fix (mkdir.sh should be bin_t)... ";
    chcon -t bin_t /usr/share/build-1/mkdir.sh;
    logMessage "done\n";

    logMessage "  > Installing apache (again)... ";
    installSoftware -u apache || die "Failed to install apache";
  fi
  logMessage "done\n";

  logMessage "  > Installing phpmyadmin... ";
  installSoftware -u phpmyadmin || die "Failed to install phpmyadmin... ";
  logMessage "done\n";

#  logMessage "  > Setting up SSL keys... ";
#  cp /etc/ssl/misc/new.cert.cert /etc/apache2/ssl || die "Copy failed of new.cert.cert";
#  cp /etc/ssl/misc/new.cert.key /etc/apache2/ssl || die "Copy failed of new.cert.key";
#  logMessage "done\n";

  logMessage "  > Updating /etc/conf.d/apache... ";
  typeset FILE=/etc/conf.d/apache2;
  typeset META=$(initChangeFile ${FILE});
  setOrUpdateQuotedVariable APACHE2_OPTS "=" "-D DEFAULT_VHOST -D INFO -D LANGUAGE -D PHP5" ${FILE};
  applyMetaOnFile ${FILE} ${META};
  commitChangeFile ${FILE} ${META};
  logMessage "done\n";

  logMessage "  > Symlinking libphp5.so... ";
  pushd /usr/lib64/apache2/modules;
  ln -s /usr/lib64/php*/apache2/libphp5.so . || die "Failed to set symlink"
  logMessage "done\n";
}

phpmyadmin() {
  logMessage "  > Editing config.inc.php... ";
  typeset FILE=/var/www/localhost/htdocs/phpmyadmin;
  cp ${FILE}/config.sample.inc.php ${FILE}/config.inc.php;
  FILE=${FILE}/config.inc.php;
  typeset META=$(initChangeFile ${FILE});
  sed -i -e "s:\(\$cfg\['blowfish_secret'\]\).*:\1 = \'$(getValue phpmyadmin.config.blowfish_secret)\';" ${FILE};
  sed -i -e "s:\(\$cfg\['Servers'\]\[\$i\]\['host'\]\).*:\1 = \'$(getValue phpmyadmin.config.host)\';" ${FILE};
  sed -i -e "s:\(\$cfg\['Servers'\]\[\$i\]\['controluser'\]\).*:\1 = 'mailsql';" ${FILE};
  sed -i -e "s:\(\$cfg\['Servers'\]\[\$i\]\['controlpass'\]\).*:\1 = \'$(getValue mysql.mailsql.password)\';" ${FILE};
  sed -i -e "s:\(\$cfg\['Servers'\]\[\$i\]\['user'\]\).*:\1 = 'mailsql';" ${FILE};
  sed -i -e "s:\(\$cfg\['Servers'\]\[\$i\]\['password'\]\).*:\1 = \'$(getValue mysql.mailsql.password)\';" ${FILE};
  applyMetaOnFile ${FILE} ${META};
  commitChangeFile ${FILE} ${META};
  logMessage "done\n";
}

mysqlauth() {
  logMessage "  > Editing authdaemonrc... ";
  typeset FILE=/etc/courier/authlib/authdaemonrc;
  typeset META=$(initChangeFile ${FILE});
  sed -i -e "s:^\(authmodulelist=\).*:\1\"$(getValue authdaemonrc.authmodulelist)\":g" ${FILE};
  applyMetaOnFile ${FILE} ${META};
  commitChangeFile ${FILE} ${META};
  logMessage "done\n";

  logMessage "  > Editing authmysqlrc... ";
  FILE=/etc/courier/authlib/authmysqlrc;
  META=$(initChangeFile ${FILE});
  updateWhitespaceNoQuotConfFile authmysqlrc ${FILE};
  # Comment out MYSQL_CRYPT_PWFIELD
  sed -i -e "s:^MYSQL_CRYPT_PWFIELD\(.*\):#MYSQL_CRYPT_PWFIELD\1:g" ${FILE};
  applyMetaOnFile ${FILE} ${META};
  commitChangeFile ${FILE} ${META};
  logMessage "done\n";

  logMessage "  > Relabelling cyrus-sasl package... ";
  rlpkg cyrus-sasl;
  logMessage "done\n";
}

mysqlpostfix() {
  logMessage "  > Editing mysql-aliases.cf... ";
  typeset FILE=/etc/postfix/mysql-aliases.cf;
  if [ ! -f ${FILE} ];
  then
    touch ${FILE};
  fi
  typeset META=$(initChangeFile ${FILE});
  updateEqualNoQuotConfFile postfix.mysql-aliases ${FILE};
  applyMetaOnFile ${FILE} ${META};
  commitChangeFile ${FILE} ${META};
  logMessage "done\n";

  logMessage "  > Editing mysql-relocated.cf... ";
  FILE=/etc/postfix/mysql-relocated.cf;
  if [ ! -f ${FILE} ];
  then
    touch ${FILE};
  fi
  META=$(initChangeFile ${FILE});
  updateEqualNoQuotConfFile postfix.mysql-relocated ${FILE};
  applyMetaOnFile ${FILE} ${META};
  commitChangeFile ${FILE} ${META};
  logMessage "done\n";

  logMessage "  > Editing mysql-transport.cf... ";
  FILE=/etc/postfix/mysql-transport.cf;
  if [ ! -f ${FILE} ];
  then
    touch ${FILE};
  fi
  META=$(initChangeFile ${FILE});
  updateEqualNoQuotConfFile postfix.mysql-transport ${FILE};
  applyMetaOnFile ${FILE} ${META};
  commitChangeFile ${FILE} ${META};
  logMessage "done\n";

  logMessage "  > Editing mysql-virtual-maps.cf... ";
  FILE=/etc/postfix/mysql-virtual-maps.cf
  if [ ! -f ${FILE} ];
  then
    touch ${FILE};
  fi
  META=$(initChangeFile ${FILE});
  updateEqualNoQuotConfFile postfix.mysql-virtual-maps ${FILE};
  applyMetaOnFile ${FILE} ${META};
  commitChangeFile ${FILE} ${META};
  logMessage "done\n";

  logMessage "  > Editing mysql-virtual-uid.cf... ";
  FILE=/etc/postfix/mysql-virtual-uid.cf
  if [ ! -f ${FILE} ];
  then
    touch ${FILE};
  fi
  META=$(initChangeFile ${FILE});
  updateEqualNoQuotConfFile postfix.mysql-virtual-uid ${FILE};
  applyMetaOnFile ${FILE} ${META};
  commitChangeFile ${FILE} ${META};
  logMessage "done\n";

  logMessage "  > Editing mysql-virtual-uid.cf... ";
  FILE=/etc/postfix/mysql-virtual-uid.cf
  if [ ! -f ${FILE} ];
  then
    touch ${FILE};
  fi
  META=$(initChangeFile ${FILE});
  updateEqualNoQuotConfFile postfix.mysql-virtual-uid ${FILE};
  applyMetaOnFile ${FILE} ${META};
  commitChangeFile ${FILE} ${META};
  logMessage "done\n";

  logMessage "  > Editing mysql-virtual.cf... ";
  FILE=/etc/postfix/mysql-virtual.cf
  if [ ! -f ${FILE} ];
  then
    touch ${FILE};
  fi
  META=$(initChangeFile ${FILE});
  updateEqualNoQuotConfFile postfix.mysql-virtual ${FILE};
  applyMetaOnFile ${FILE} ${META};
  commitChangeFile ${FILE} ${META};
  logMessage "done\n";

  logMessage "  > Editing main.cf... ";
  FILE=/etc/postfix/main.cf;
  META=$(initChangeFile ${FILE});
  updateEqualNoQuotConfFile postfix.3.main ${FILE};
  VMUID=$(id -u vmail);
  VMGID=$(id -g vmail);
  setOrUpdateUnquotedVariable virtual_gid_maps "=" static:${VMGID} ${FILE};
  setOrUpdateUnquotedVariable virtual_minimum_uid "=" ${VMUID} ${FILE};
  setOrUpdateUnquotedVariable virtual_uid_maps "=" static:${VMUID} ${FILE};
  applyMetaOnFile ${FILE} ${META};
  commitChangeFile ${FILE} ${META};
  logMessage "done\n";

  logMessage "  > Setting file permissions... ";
  chmod 640 /etc/postfix/mysql-*.cf;
  chgrp postfix /etc/postfix/mysql-*.cf;
  logMessage "done\n";
}

setuppam() {
  _setuppam;
}

stepOK "configsystem" && (
logMessage ">>> Step \"configsystem\" starting...\n";
runStep configsystem;
);
nextStep;

stepOK "installpostfix" && (
logMessage ">>> Step \"installpostfix\" starting...\n";
runStep installpostfix;
);
nextStep;

stepOK "installcourier" && (
logMessage ">>> Step \"installcourier\" starting...\n";
runStep installcourier;
);
nextStep;

stepOK "installsasl" && (
logMessage ">>> Step \"installsasl\" starting...\n";
runStep installsasl;
);
nextStep;

#stepOK "certificates" && (
#logMessage ">>> Step \"certificates\" starting...\n";
#runStep certificates;
#);
#nextStep;

stepOK "updatepostfix" && (
logMessage ">>> Step \"updatepostfix\" starting...\n";
runStep updatepostfix;
);
nextStep;

stepOK "vmail" && (
logMessage ">>> Step \"vmail\" starting...\n";
runStep vmail;
);
nextStep;

stepOK "installmysql" && (
logMessage ">>> Step \"installmysql\" starting...\n";
runStep installmysql;
);
nextStep;

stepOK "startmysql" && (
logMessage ">>> Step \"startmysql\" starting...\n";
runStep startmysql;
);
nextStep;

stepOK "loadsql" && (
logMessage ">>> Step \"loadsql\" starting...\n";
runStep loadsql;
);
nextStep;

stepOK "installapache" && (
logMessage ">>> Step \"installapache\" starting...\n";
runStep installapache;
);
nextStep;

stepOK "phpmyadmin" && (
logMessage ">>> Step \"phpmyadmin\" starting...\n";
runStep phpmyadmin;
);
nextStep;

stepOK "mysqlauth" && (
logMessage ">>> Step \"mysqlauth\" starting...\n";
runStep mysqlauth;
);
nextStep;

stepOK "mysqlpostfix" && (
logMessage ">>> Step \"mysqlpostfix\" starting...\n";
runStep mysqlpostfix;
);
nextStep;

stepOK "setuppam" && (
logMessage ">>> Step \"setuppam\" starting...\n";
runStep setuppam;
);
nextStep;

cleanupTools;
rm ${FAILED};

