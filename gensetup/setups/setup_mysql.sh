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

typeset STEPS="installdb configdb startdb filldb userok userfail dropall";
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
  logMessage "  > Installing 'mysql'... ";
  installSoftware -u mysql || die "Failed to install MySQL (emerge failed)";
  logMessage "done\n";
}

configdb() {
  typeset DBVERS=$(ls -d /var/db/pkg/dev-db/mysql-[0-9]*.* | sed -e 's:.*dev-db/::g');
  logMessage "  > Running \"emerge --config =dev-db/${DBVERS}... ";
  MYSQL_ROOT_PASSWORD=$(getValue mysql.rootpassword);
  if [ -f /root/.my.cnf ];
  then
    die "File /root/.my.cnf exists. Remove and retry please.";
  fi
  echo "password=${MYSQL_ROOT_PASSWORD}" >> /root/.my.cnf;
  installSoftware --config =dev-db/${DBVERS} || die "Failed to configure MySQL";
  rm /root/.my.cnf;
  logMessage "done\n";
}

startdb() {
  die "Please start MySQL (/etc/init.d/mysql start) and continue with 'filldb'";
}

filldb() {
  logMessage "  > Filling database 'gentoo'... ";
  typeset TMPSQLFILE=$(mktemp);
  cat > ${TMPSQLFILE} << EOF
CREATE DATABASE IF NOT EXISTS \`gentoo\`;
USE gentoo;
DROP TABLE IF EXISTS \`developers\`;
CREATE TABLE \`developers\` (
 name VARCHAR(120),
 email VARCHAR(120),
 job VARCHAR(120)
);
INSERT INTO developers VALUES ('Sven Vermeulen', 'sven.vermeulen@siphos.be', 'Contributor for SELinux');
INSERT INTO developers VALUES ('Test Subject', 'ts@gentoo.org', 'Testing Developer');
GRANT ALL ON gentoo.* TO 'admin'@'localhost' IDENTIFIED by 'adminpassword';
GRANT SELECT ON gentoo.* TO 'guest'@'localhost' IDENTIFIED by 'guestpassword';
EOF
  mysql -u root -h localhost -p$(getValue mysql.rootpassword) < ${TMPSQLFILE};
  if [ $? -eq 0 ];
  then
    logMessage "done\n";
  else
    logMessage "failed!\n";
    die "Failed to create database";
  fi
  rm ${TMPSQLFILE};
}

userok() {
  logMessage "  > Testing valid user access... ";
  mysql -u admin -padminpassword -h localhost gentoo -e "create table if not exists test (id integer);" || die "Failed to create test table in gentoo database";
  mysql -u admin -padminpassword -h localhost gentoo -e "show tables;" | grep -q test || die "Test table 'test' could not be found";
  mysql -u admin -padminpassword -h localhost gentoo -e "drop table test;" || die "Test table could not be dropped";
  mysql -u guest -pguestpassword -h localhost gentoo -e "describe developers;" | grep -q 'name' || die "Failed to describe developers table as guest user.";
  mysql -u guest -pguestpassword -h localhost gentoo -e "select name from developers;" | grep 'Sven Vermeulen' || die "Failed to see particular row in developers table.";
  logMessage "ok\n";
}

userfail() {
  logMessage "  > Testing invalid user access... ";
  mysql -u test -ptestpassword -h localhost gentoo -e "select * from developers;" && die "Did not receive an ACCESS DENIED for the test user.";
  mysql -u guest -pguestpassword -h localhost gentoo -e "create table test (id integer);" && die "Did not receive an ACCESS DENIED for the guest user.";
  logMessage "ok\n";
}

dropall() {
  logMessage "  > Revoking and dropping test grants and database... ";
  mysql -u root -p$(getValue mysql.rootpassword) -h localhost -e "drop database gentoo;" || die "Failed to drop test database";
  mysql -u root -p$(getValue mysql.rootpassword) -h localhost -e "revoke all on gentoo.* from 'guest'@'localhost';" || die "Failed to revoke grants for guest";
  mysql -u root -p$(getValue mysql.rootpassword) -h localhost -e "revoke all on gentoo.* from 'admin'@'localhost';" || die "Failed to revoke grants for admin";
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
