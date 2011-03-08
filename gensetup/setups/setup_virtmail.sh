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

typeset STEPS="";
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

installpostfix() {
  logMessage "  > Installing 'postfix'... ";
  installSoftware -u postfix || die "Failed to install Postfix (emerge failed)";
  logMessage "done\n";

  logMessage "  > Updating main.cf... ";
  updateConfFile postfix.1.main /etc/postfix/main.cf;
  logMessage "done\n";

  logMessage "  > Updating master.cf... ";
  typeset FILE=/etc/postfix/master.cf;
  typeset META=$(initChangeFile ${FILE});
  sed -i -e 's:smtpd$:smtpd -v:g' ${FILE};
  applyMetaOnFile ${FILE} ${META};
  commitChangeFile ${FILE} ${META};
  logMessage "done\n";
}

startpostfix() {
  logMessage "  > Need to start postfix!\n";
  die "Start postfix init script (/etc/init.d/postfix start) and continue with step \"courier\"";
}

installcourier() {
  logMessage "  > Installing 'courier-imap' and 'courier-authlib'... ";
  installSoftware -u courier-imap courier-authlib || die "Failed to install Courier software (emerge failed)";
  logMessage "done\n";

  logMessage "  > Updating pop3.cnf... ";
  typeset FILE=/etc/courier-imap/pop3d.cnf;
  typeset META=$(initChangeFile ${FILE});
  sed -i -e "s:^C ?=.*:C=$(getValue courier.ssl.C):g" ${FILE};
  sed -i -e "s:^ST ?=.*:ST=$(getValue courier.ssl.ST):g" ${FILE};
  sed -i -e "s:^L ?=.*:L=$(getValue courier.ssl.L):g" ${FILE};
  sed -i -e "s:^O ?=.*:O=$(getValue courier.ssl.O):g" ${FILE};
  sed -i -e "s:^OU ?=.*:OU=$(getValue courier.ssl.OU):g" ${FILE};
  sed -i -e "s:^CN ?=.*:CN=$(getValue courier.ssl.CN):g" ${FILE};
  sed -i -e "s:^emailAddress ?=.*:emailAddress=$(getValue courier.ssl.emailAddress):g" ${FILE};
  applyMetaOnFile ${FILE} ${META};
  commitChangeFile ${FILE} ${META};
  logMessage "done\n";

  logMessage "  > Updating imapd.cnf... ";
  typeset FILE=/etc/courier-imap/imapd.cnf;
  typeset META=$(initChangeFile ${FILE});
  sed -i -e "s:^C ?=.*:C=$(getValue courier.ssl.C):g" ${FILE};
  sed -i -e "s:^ST ?=.*:ST=$(getValue courier.ssl.ST):g" ${FILE};
  sed -i -e "s:^L ?=.*:L=$(getValue courier.ssl.L):g" ${FILE};
  sed -i -e "s:^O ?=.*:O=$(getValue courier.ssl.O):g" ${FILE};
  sed -i -e "s:^OU ?=.*:OU=$(getValue courier.ssl.OU):g" ${FILE};
  sed -i -e "s:^CN ?=.*:CN=$(getValue courier.ssl.CN):g" ${FILE};
  sed -i -e "s:^emailAddress ?=.*:emailAddress=$(getValue courier.ssl.emailAddress):g" ${FILE};
  applyMetaOnFile ${FILE} ${META};
  commitChangeFile ${FILE} ${META};
  logMessage "done\n";

  logMessage "  > Running mkpop3dcert... ";
  mkpop3dcert || die "Failed to run mkpop3dcert";
  logMessage "done\n";

  logMessage "  > Running mkimapdcert... ";
  mkimapdcert || die "Failed to run mkipapcert";
  logMessage "done\n";
}

startcourier() {
  logMessage "  > Need to start courier!\n";
  logMessage "  > Run /etc/init.d/courier-imapd start\n";
  logMessage "  > Run /etc/init.d/courier-imapd-ssl start\n";
  logMessage "  > Run /etc/init.d/courier-pop3d start\n";
  logMessage "  > Run /etc/init.d/courier-pop3d-ssl start\n";
  die "Please continue with step 'sasl' when done.";
}

installsasl() {
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
}

startsasl() {
  logMessage "  > Please run /etc/init.d/saslauthd start\n";
  die "When finished, continue with step certificates.";
}

certificates() {
  logMessage "  > Editing openssl.cnf... ";
  typeset FILE=/etc/ssl/openssl.cnf;
  typeset META=$(initChangeFile ${FILE});
  sed -i -e "s:^countryName_default.*:countryName_default = $(getValue openssl.cnf.countryName_default)" ${FILE};
  sed -i -e "s:^stateOrProvinceName_default.*:stateOrProvinceName_default = $(getValue openssl.cnf.stateOrProvinceName_default)" ${FILE};
  sed -i -e "s:^localityName_default.*:localityName_default = $(getValue openssl.cnf.localityName_default)" ${FILE};
  sed -i -e "s:^0.organizationName_default.*:0.organizationName_default = $(getValue openssl.cnf.0_organizationName_default)" ${FILE};
  sed -i -e "s:^commonName_default.*:commonName_default = $(getValue openssl.cnf.commonName_default)" ${FILE};
  sed -i -e "s:^emailAddress_default.*:emailAddress_default = $(getValue openssl.cnf.emailAddress_default)" ${FILE};
  applyMetaOnFile ${FILE} ${META};
  commitChangeFile ${FILE} ${META};
  logMessage "done\n";

  logMessage "  > Running CA.pl -newreq-nodes... ";
  cd /etc/ssl/misc;
  printf "\n\n\n\n\n\n\n\n\n" | ./CA.pl -newreq-nodes || die "Failed to run CA.pl -newreq-nodes"
  logMessage "done\n";

  logMessage "  > Running CA.pl -newca... ";
  printf "\n$(getValue openssl.CA.privkey_pass)\n$(getValue openssl.CA.privkey_pass)\n\n\n\n\n\n\n\n\n\n$(getValue openssl.CA.privkey_pass)\n" ./CA.pl -newca || die "Failed to run CA.pl -newca"
  logMessage "done\n";

  logMessage "  > Running CA.pl -sign... ";
  printf "$(getValue openssl.CA.privkey_pass)\ny\n" | ./CA.pl -sign || die "Failed to run CA.pl -sign";
  logMessage "done\n";

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
}

updatepostfix() {
  logMessage "  > Updating main.cf... ";
  updateConfFile postfix.1.main /etc/postfix/main.cf;
  logMessage "done\n";
}

restartpostfix() {
  logMessage "  > Please reload postfix and continue with step 'vmail'\n"
  die "Execute /etc/init.d/postfix reload and continue with step vmail."
}


stepOK "postfix" && (
logMessage ">>> Step \"postfix\" starting...\n";
runStep installpostfix;
);
nextStep;

stepOK "startposfix" && (
logMessage ">>> Step \"startpostfix\" starting...\n";
runStep startpostfix;
);
nextStep;

stepOK "courier" && (
logMessage ">>> Step \"courier\" starting...\n";
runStep installcourier;
);
nextStep;

stepOK "startcourier" && (
logMessage ">>> Step \"startcourier\" starting...\n";
runStep startcourier;
);
nextStep;

stepOK "sasl" && (
logMessage ">>> Step \"sasl\" starting...\n";
runStep installsasl;
);
nextStep;

stepOK "startsasl" && (
logMessage ">>> Step \"startsasl\" starting...\n";
runStep startsasl;
);
nextStep;

stepOK "certificates" && (
logMessage ">>> Step \"certificates\" starting...\n";
runStep certificates;
);
nextStep;

stepOK "updatepostfix" && (
logMessage ">>> Step \"updatepostfix\" starting...\n";
runStep updatepostfix;
);
nextStep;

stepOK "restartpostfix" && (
logMessage ">>> Step \"restartpostfix\" starting...\n";
runStep restartpostfix;
);
nextStep;

cleanupTools;
rm ${FAILED};
