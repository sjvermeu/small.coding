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

typeset STEPS="inittest userok exittest";
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
  logTestMessage inittest 001 "Load SQL file (restore database dump)";
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
    logOK;
  else
    logNOK;
  fi
  rm ${TMPSQLFILE};
}

userok() {
  logTestMessage userok 001 "Create table (as admin) through mysql command";
  mysql -u admin -padminpassword -h localhost gentoo -e "create table if not exists test (id integer);" && logOK || logNOK;

  logTestMessage userok 002 "Show tables (as admin)";
  mysql -u admin -padminpassword -h localhost gentoo -e "show tables;" | grep -q test && logOK || logNOK;

  logTestMessage userok 003 "Drop table (as admin)";
  mysql -u admin -padminpassword -h localhost gentoo -e "drop table test;" && logOK || logNOK;

  logTestMessage userok 004 "Describe table (as guest)";
  mysql -u guest -pguestpassword -h localhost gentoo -e "describe developers;" | grep -q 'name' && logOK || logNOK;

  logTestMessage userok 005 "Select data from table (as guest)";
  mysql -u guest -pguestpassword -h localhost gentoo -e "select name from developers;" | grep 'Sven Vermeulen' && logOK || logNOK;

  logTestMessage userok 006 "Select data from table (as test)";
  mysql -u test -ptestpassword -h localhost gentoo -e "select * from developers;" && logNOK || logOK;

  logTestMessage userok 007 "Create table (as guest)";
  mysql -u guest -pguestpassword -h localhost gentoo -e "create table test (id integer);" && logNOK || logOK;
}

exittest() {
  logTestMessage exittest 001 "Drop database gentoo";
  mysql -u root -p$(getValue mysql.rootpassword) -h localhost -e "drop database gentoo;" && logOK || logNOK;

  logTestMessage exittest 002 "Revoke all (gentoo) privileges from guest account";
  mysql -u root -p$(getValue mysql.rootpassword) -h localhost -e "revoke all on gentoo.* from 'guest'@'localhost';" && logOK || logNOK;

  logTestMessage exittest 003 "Revoke all (gentoo) privileges from admin account";
  mysql -u root -p$(getValue mysql.rootpassword) -h localhost -e "revoke all on gentoo.* from 'admin'@'localhost';" && logOK || logNOK;
}

stepOK "inittest" && (
logTestMessage inittest "- -" "Create temporary working database (gentoo)";
logMessage "\n";
runStep inittest;
);
nextStep;

stepOK "userok" && (
logTestMessage userok "- -" "Performing mysql command activities";
logMessage "\n";
runStep userok;
);
nextStep;

stepOK "exittest" && (
logTestMessage exittest "- -" "Cleanup temporary working database (gentoo)";
logMessage "\n";
runStep exittest;
);
nextStep;

cleanupTools;
rm ${FAILED};
