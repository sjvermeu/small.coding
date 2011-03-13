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

typeset STEPS="configsystem installldap setupldap setuppam";
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
  logMessage "done\n";

  logMessage "  > Updating /etc/openldap/slapd.conf... ";
  typeset FILE=/etc/openldap/slapd.conf;
  typeset META=$(initChangeFile ${FILE});
  ##### --> Add includes for schemas
  typeset NUMS=$(getValue openldap.slapd.include.seq);
  grep -B 999 core.schema ${FILE} > ${FILE}.new;
  for NUM in $(seq ${NUMS});
  do
    echo "include $(getValue openldap.slapd.include.${NUM})" >> ${FILE}.new;
  done
  grep -A 999 "core.schema" ${FILE} | grep -v ".schema" >> ${FILE}.new;
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

  logMessage "  > Updating /etc/openldap/ldap.conf... ";
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

setupldap() {
  logMessage "  > Downloading MigrationTools... ";
  wget $(getValue migrationtools.url);
  logMessage "done\n";

  logMessage "  > Downloading make_master.sh... ";
  wget $(getValue make_master.url);
  logMessage "done\n";

  logMessage "  > Extracting MigrationTools... ";
  typeset TMPDIR=$(getValue migration.workdir);
  typeset TOOLS=$(getValue migration.tools);
  if [ ! -d ${TMPDIR} ];
  then
    mkdir -p ${TMPDIR};
  fi
  typeset CDIR=$(pwd);
  cp make_master.sh ${TMPDIR};
  pushd ${TMPDIR};
  tar xvzf ${CDIR}/MigrationTools.tgz 
  mv make_master.sh ${TOOLS};
  cd ${TOOLS};
  logMessage "done\n";

  logMessage "  > Updating make_master.sh with location... ";
  sed -i -e "s:^LDAP_MIGRATION=.*:LDAP_MIGRATION=${TMPDIR}/${TOOLS}:g" make_master.sh;
  chmod +x make_master.sh;
  popd;
  logMessage "done\n";

  logMessage "  ! Please run make_master.sh in ${TMPDIR}/${TOOLS}\n";
  logMessage "  ! remember, basedn is the dc=..,dc=.. part.\n";
  logMessage "  !           rootdn is the cn=..,dc=..,dc=.. part.\n";
  die "When finished, continue with step TODO."
}

setuppam() {
  logMessage "  > Installing PAM software... ";
  installSoftware -u pam_ldap || die "Failed to install pam_ldap";
  installSoftware -u nss_ldap || die "Failed to install nss_ldap";
  logMessage "done\n";

  logMessage "  > Updating system-auth PAM configuration... ";
  typeset FILE=/etc/pam.d/system-auth;
  typeset META=$(initChangeFile ${FILE});

  sed -i -e "s|auth.*required.*pam_unix\(.*\)|auth	sufficient	pam_unix\1|g" ${FILE};
  grep -q 'auth.*pam_ldap' ${FILE};
  if [ $? -ne 0 ];
  then
    awk "{print} /auth.*pam_unix/ {print \"auth	sufficient	 pam_ldap.so use_first_pass\"}" ${FILE} > ${FILE}.new;
    mv ${FILE}.new ${FILE};
  fi

  grep -q 'account.*pam_ldap' ${FILE};
  if [ $? -ne 0 ];
  then
    awk "{print} /account.*pam_unix/ {print \"account	sufficient	pam_ldap.so\"}" ${FILE} > ${FILE}.new;
    mv ${FILE}.new ${FILE};
  fi

  sed -i -e "s|password.*required.*pam_unix\(.*\)|password	sufficient	pam_unix\1|g" ${FILE};
  grep -q 'password.*pam_ldap' ${FILE};
  if [ $? -ne 0 ];
  then
    awk "{print} /password.*pam_unix/ {print \"password	sufficient	pam_ldap.so use_authtok use_first_pass\"}" ${FILE} > ${FILE}.new;
    mv ${FILE}.new ${FILE};
  fi

  grep -q 'session.*pam_ldap' ${FILE};
  if [ $? -ne 0 ];
  then
    awk "{print} /session.*pam_unix/ {print \"session	optional	pam_ldap.so\"}" ${FILE} > ${FILE}.new;
    mv ${FILE}.new ${FILE};
  fi

  applyMetaOnFile ${FILE} ${META};
  commitChangeFile ${FILE} ${META};
  logMessage "done\n";

  logMessage "  > Updating /etc/ldap.conf... ";
  FILE=/etc/ldap.conf;
  META=$(initChangeFile ${FILE});
  grep -q '^host' ${FILE};
  if [ $? -eq 0 ];
  then
    sed -i -e "s|^host|# host|g" ${FILE};
  fi

  grep -q '^base' ${FILE};
  if [ $? -eq 0 ];
  then
    sed -i -e "s|^base|# base|g" ${FILE};
  fi

  setOrUpdateQuotedVariable suffix " " "$(getValue openldap.slapd.db.suffix)" ${FILE};
  updateWhitespaceNoQuotConfFile etc.ldap ${FILE};

  applyMetaOnFile ${FILE} ${META};
  commitChangeFile ${FILE} ${META};
  logMessage "done\n";

  logMessage "  > Update nsswitch.conf... ";
  FILE=/etc/nsswitch.conf
  META=$(initChangeFile ${FILE});
  sed -i -e "s|passwd:.*|passwd:	files ldap|g" ${FILE};
  sed -i -e "s|group:.*|group:	files ldap|g" ${FILE};
  sed -i -e "s|shadow:.*|shadow:	files ldap|g" ${FILE};
  applyMetaOnFile ${FILE} ${META};
  commitChangeFile ${FILE} ${META};
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

stepOK "setupldap" && (
logMessage ">>> Step \"setupldap\" starting...\n";
runStep setupldap;
);
nextStep;

stepOK "setuppam" && (
logMessage ">>> Step \"setuppam\" starting...\n";
runStep setuppam;
);
nextStep;

cleanupTools;
rm ${FAILED};
