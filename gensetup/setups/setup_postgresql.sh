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

typeset STEPS="installdb configdb labelfiles startdb filldb userok userfail dropall";
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

installdb() {
  logMessage "  > Installing 'postgresql-server'... ";
  installSoftware -u postgresql-server || die "Failed to install PostgreSQL (emerge failed)";
  logMessage "done\n";
}

configdb() {
  typeset DBVERS=$(ls -d /var/db/pkg/dev-db/postgresql-server-[0-9]*.* | sed -e 's:.*dev-db/::g');
  logMessage "  > Temporary setting postgres password... ";
  typeset PGPW=$(echo ${RANDOM} | md5sum | cut -c1-12);
  printf "${PGPW}\n${PGPW}\n" | passwd postgres || die "Failed to set password";
  logMessage "done\n";

  logMessage "  > Running \"emerge --config =dev-db/${DBVERS}... ";
  printf "y\n${PGPW}\n" | installSoftware --config =dev-db/${DBVERS} || die "Failed to configure PostgreSQL";
  logMessage "done\n";

  logMessage "  > Locking postgres account... ";
  passwd -l postgres || die "Failed to lock postgres account";
  logMessage "done\n";
}

labelfiles() {
  logMessage "  > (Re)labelling database cluster files... ";
  restorecon -R /var/lib/postgresql || die "Failed to relabel files";
  logMessage "done\n";
}

startdb() {
  logMessage "** Run the following commands to initialize the database:\n";
  logMessage "**   /etc/init.d/postgresql-* start\n";
  logMessage "**   su postgres -\n";
  logMessage "**   createuser admin (answer 'n' to all questions)\n";
  logMessage "**   createuser guest (answer 'n' to all questions)\n";
  die "Please follow above manual commands and then continue with 'filldb'";
}

filldb() {
  logMessage "  > Filling database 'gentoo'... ";
  typeset TMPSQLFILE=$(mktemp);
  cat > ${TMPSQLFILE} << EOF
CREATE DATABASE gentoo;
\c gentoo;
DROP TABLE IF EXISTS developers;
CREATE TABLE developers (
 name VARCHAR(120),
 email VARCHAR(120),
 job VARCHAR(120)
);
INSERT INTO developers VALUES ('Sven Vermeulen', 'sven.vermeulen@siphos.be', 'Contributor for SELinux');
INSERT INTO developers VALUES ('Test Subject', 'ts@gentoo.org', 'Testing Developer');
GRANT ALL privileges ON database gentoo TO admin;
GRANT SELECT ON table developers TO guest;
EOF
  chmod 644 ${TMPSQLFILE};
  chcon -t postgresql_var_run_t ${TMPSQLFILE};
  su postgres -c "psql --file ${TMPSQLFILE}" 2>&1 | grep FATAL && die "Failed to fill test database gentoo";
  logMessage "done\n";
  rm ${TMPSQLFILE};
}

userok() {
  logMessage "  > Testing valid user access... ";
  su postgres -c "psql -U admin gentoo -c \"create table test (id integer);\"" 2>&1 | grep FATAL && die "Failed to create test table in gentoo database";
  su postgres -c "psql -U admin gentoo -c \"\\d test\"" 2>&1 | grep FATAL && die "Failed to describe test table";
  su postgres -c "psql -U admin gentoo -c \"drop table test;\"" 2>&1 | grep FATAL && die "Test table could not be dropped";
  su postgres -c "psql -U guest gentoo -c \"\\d developers\"" | grep -q 'name' || die "Failed to describe developers table as guest user.";
  su postgres -c "psql -U guest gentoo -c \"select name from developers;\"" | grep 'Sven Vermeulen' || die "Failed to see particular row in developers table.";
  logMessage "ok\n";
}

userfail() {
  logMessage "  > Testing invalid user access... ";
  su postgres -c "psql -U test gentoo -c \"select * from developers;\"" 2>&1 | grep FATAL || die "Did not receive a FATAL error on the test user.";
  logMessage "ok\n";
}

dropall() {
  logMessage "  > Revoking and dropping test grants and database... ";
  su postgres -c "psql -c \"drop database gentoo;\"" 2>&1 | grep FATAL && die "Failed to drop gentoo database";
  su postgres -c "dropuser admin" 2>&1 | grep FATAL && die "Failed to remove admin role";
  su postgres -c "dropuser guest" 2>&1 | grep FATAL && die "Failed to remove guest role";
  logMessage "ok\n";
}

stepOK "installdb" && (
logMessage ">>> Step \"installdb\" starting...\n";
runStep installdb;
);
nextStep;

stepOK "configdb" && (
logMessage ">>> Step \"configdb\" starting...\n";
runStep configdb;
);
nextStep;

stepOK "labelfiles" && (
logMessage ">>> Step \"labelfiles\" starting...\n";
runStep labelfiles;
);
nextStep;

stepOK "startdb" && (
logMessage ">>> Step \"startdb\" starting...\n";
runStep startdb;
);
nextStep;

stepOK "filldb" && (
logMessage ">>> Step \"filldb\" starting...\n";
runStep filldb;
);
nextStep;

stepOK "userok" && (
logMessage ">>> Step \"userok\" starting...\n";
runStep userok;
);
nextStep;

stepOK "userfail" && (
logMessage ">>> Step \"userfail\" starting...\n";
runStep userfail;
);
nextStep;

stepOK "dropall" && (
logMessage ">>> Step \"dropall\" starting...\n";
runStep dropall;
);
nextStep;

cleanupTools;
rm ${FAILED};
