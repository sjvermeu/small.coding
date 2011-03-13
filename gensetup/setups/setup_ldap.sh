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

typeset STEPS="configsystem installldap";
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
  die "Please restart the network and continue with step installldap.";
}

installldap() {
  logMessage "  > Installing 'openldap'... ";
  installSoftware -u openldap || die "Failed to install OpenLDAP (emerge failed)";
  logMessage "done\n";

  logMessage "  > Adding slapd to default runlevel... ";
  rc-update add slapd default
  logMessage "done\n";

  logMessage "  > Generating LDAP password... ";
  typeset LDAPPASS=$(slappasswd -s $(getValue openldap.password));
  logMesage "done\n";

  logMessage "  > Updating /etc/openldap/slapd.conf... ";
  typeset FILE=/etc/openldap/slapd.conf;
  typeset META=$(initChangeFile ${FILE});
  ##### --> Add includes for schemas
  typeset NUMS=$(getValue openldap.slapd.include.seq);
  grep -B 999 core.schema ${FILE} > ${FILE}.new;
  for NUM in $(seq ${NUMS});
  do
    echo "include $(getValue openldap.slapd.include.${NUM})";
  done
  grep -A 999 ${FILE} | grep -v \.schema >> ${FILE}.new;
  mv ${FILE}.new ${FILE};
  ##### --> Add access controls
  grep -B 9999 '^# rootdn' ${FILE} > ${FILE}.new;
  cat >> ${FILE}.new << EOF
access to dn.base="" by * read
access to dn.base="cn=Subschema" by * read
access to *
	by self write
	by users read
	by anonymous read
EOF
  grep -A 9999 '^# rootdn' ${FILE} | grep -v '^# rootdn' >> ${FILE}.new
  mv ${FILE}.new ${FILE};
  ##### --> Add database updates
  updateWhitespaceConfFile openldap.slapd.db ${FILE};
  ##### --> Set encrypted password
  setOrUpdateQuotedVariable rootpw " " "${LDAPPASS}" ${FILE};
  applyMetaOnFile ${FILE} ${META};
  commitChangeFile ${FILE} ${META};
  logMessage "done\n";

  logMessage "  > Updating ldap.conf... ";
  FILE=/etc/openldap/ldap.conf
  META=$(initChangeFile ${FILE});
  updateWhitespaceNoQuotConfFile openldap.ldap ${FILE};
  applyMetaOnFile ${FILE} ${META};
  commitChangeFile ${FILE} ${META};
  logMessage "done\n";

  logMessage "  > Updating /etc/conf.d/slapd... ";
  FILE=/etc/conf.d/slapd;
  META=$(initChangeFile ${FILE});
  updateEqualConfFile conf.slapd ${FILE};
  applyMetaOnFile ${FILE} ${META};
  commitChangeFile ${FILE} ${META};
  logMessage "done\n";

  logMessage "  > Creating /var/lib/openldap-ldbm... ";
  mkdir -p /var/lib/openldap-ldbm;
  restorecon -R /var/lib/openldap-ldbm;
  chown ldap:ldap /var/lib/openldap-ldbm;
  chmod 700 /var/lib/openldap-ldbm;
  logMessage "done\n";
}

stepOK "configsystem" && (
logMessage ">>> Step \"configsystem\" starting...\n";
runStep configsystem;
);
nextStep;

stepOK "installldap" && (
logMessage ">>> Step \"installldap\" starting...\n";
runStep installldap;
);
nextStep;

stepOK "installsquirrel" && (
logMessage ">>> Step \"installsquirrel\" starting...\n";
runStep installsquirrel;
);
nextStep;

cleanupTools;
rm ${FAILED};
