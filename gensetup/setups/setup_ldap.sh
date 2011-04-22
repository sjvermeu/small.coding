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

typeset STEPS="configsystem users installldap setupldap setuppam";
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
  die "Please restart the network and continue with step users.";
}

users() {
  logMessage "  > Creating test users (user, staff, test)... ";
  typeset TU=$(getValue testusers.enable);
  if [ "${TU}" = "true" ];
  then
    useradd -m user;
    useradd -m staff;
    useradd -m test;
    # Create a SELinux user called test
    semanage user -a -R 'staff_r sysadm_r' -P test test_u
    # Map Linux users to SELinux users
    semanage login -a -s staff_u staff;
    semanage login -a -s test_u test;
    # Clear and reset
    restorecon -R -r -F /home/test /home/user /home/staff;
    # Set passwords
    printf "$(getValue testusers.user.password)\n$(getValue testusers.user.password)\n" | passwd user;
    logMessage "done\n";
  else
    logMessage "skipped\n";
  fi
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
  cat > ${FILE} << EOF
include /etc/openldap/schema/core.schema
include /etc/openldap/schema/cosine.schema
include /etc/openldap/schema/inetorgperson.schema
include /etc/openldap/schema/nis.schema
include /etc/openldap/schema/misc.schema

pidfile /var/run/openldap/slapd.pid
argsfile /var/run/openldap/slapd.args

serverID SERVERID
loglevel 0

## Access Controls
access to dn.base="" by * read
access to dn.base="cn=Subschema" by * read
access to *
  by self write
  by users read
  by anonymous read

## Database definition
database hdb
suffix "dc=virtdomain,dc=com"
checkpoint 32 30
rootdn "cn=Manager,dc=virtdomain,dc=com"
rootpw "{SSHA}BLABLABLA"
directory "/var/lib/openldap-ldbm"
index objectClass eq

## Synchronisation (pull from other)
syncrepl rid=000
  provider=ldap://PROVIDER.virtdomain.com
  type=refreshAndPersist
  retry="5 5 300 +"
  searchbase="dc=virtdomain,dc=com"
  attrs="*,+"
  bindmethod="simple"
  binddn="cn=ldapreader.virtdomain.com,dc=virtdomain,dc=com"
  credentials="ldapsyncpass"

index entryCSN eq
index entryUUID eq

mirrormode TRUE

overlay syncprov
syncprov-checkpoint 100 10
EOF
  updateWhitespaceConfFile openldap.slapd.db ${FILE};
  updateEqualConfFile openldap.slapd.syncrepl ${FILE};
  setOrUpdateQuotedVariable rootpw " " "${LDAPPASS}" ${FILE};
  setOrUpdateUnquotedVariable serverID " " $(getValue openldap.slapd.serverID) ${FILE};
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
  typeset TOOLS=$(getValue migration.toolkit);
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

  logMessage "  ! Please start ldap.\n";
  logMessage "  ! Please run make_master.sh in ${TMPDIR}/${TOOLS}\n";
  logMessage "  ! remember, basedn is the dc=..,dc=.. part.\n";
  logMessage "  !           rootdn is the cn=..,dc=..,dc=.. part.\n";
  logMessage "  !\n";
  logMessage "  ! Create ldif for ldapreader.\n";
  logMessage "  ! Run ldapadd -x -D \"cn=...\" -W -f ./passwd.ldif\n";
  die "When finished, continue with step setuppam."
}

setuppam() {
  _setuppam;
}

stepOK "configsystem" && (
logMessage ">>> Step \"configsystem\" starting...\n";
runStep configsystem;
);
nextStep;

stepOK "users" && (
logMessage ">>> Step \"users\" starting...\n";
runStep users;
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
