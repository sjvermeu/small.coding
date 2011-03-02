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
  logTestMessage inittest 001 "Create admin role";
  su postgres -c "createuser admin -S -R -D" 2>&1 | grep ERROR && logNOK || logOK;

  logTestMessage inittest 002 "Create guest role";
  su postgres -c "createuser guest -S -R -D" 2>&1 | grep ERROR && logNOK || logOK;

  logTestMessage inittest 003 "Load SQL file (restore database dump)";
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
  su postgres -c "psql --file ${TMPSQLFILE}" 2>&1 | grep FATAL && logNOK || logOK;
  rm ${TMPSQLFILE};
}

userok() {
  logTestMessage userok 001 "Create table (as admin) through psql command";
  su postgres -c "psql -U admin gentoo -c \"create table test (id integer);\"" 2>&1 | grep FATAL && logNOK || logOK;

  logTestMessage userok 002 "Describe test table (as admin) through psql command";
  su postgres -c "psql -U admin gentoo -c \"\\d test\"" 2>&1 | grep FATAL && logNOK || logOK;

  logTestMessage userok 003 "Drop test table (as admin) through psql command";
  su postgres -c "psql -U admin gentoo -c \"drop table test;\"" 2>&1 | grep FATAL && logNOK || logOK;

  logTestMessage userok 004 "Describe table (as guest) through psql command";
  su postgres -c "psql -U guest gentoo -c \"\\d developers\"" | grep -q 'name' && logOK || logNOK;

  logTestMessage userok 005 "Query test data (as guest) through psql command";
  su postgres -c "psql -U guest gentoo -c \"select name from developers;\"" | grep 'Sven Vermeulen' && logOK || logNOK;

  logTestMessage userok 006 "Testing invalid user access";
  su postgres -c "psql -U test gentoo -c \"select * from developers;\"" 2>&1 | grep FATAL || logNOK && logOK;
}

exittest() {
  logTestMessage exittest 001 "Drop test database";
  su postgres -c "psql -c \"drop database gentoo;\"" 2>&1 | grep FATAL && logNOK || logOK;

  logTestMessage exittest 002 "Drop admin user";
  su postgres -c "dropuser admin" 2>&1 | grep FATAL && logNOK || logOK;

  logTestMessage exittest 003 "Drop guest user";
  su postgres -c "dropuser guest" 2>&1 | grep FATAL && logNOK || logOK;
}

stepOK "inittest" && (
logTestMessage inittest "- -" "Create temporary working database";
logMessage "\n";
runStep inittest;
);
nextStep;

stepOK "userok" && (
logTestMessage userok "- -" "Performing psql command activities";
logMessage "\n";
runStep userok;
);
nextStep;

stepOK "exittest" && (
logTestMessage exittest "- -" "Cleanup temporary working database";
logMessage "\n";
runStep exittest;
);
nextStep;

cleanupTools;
rm ${FAILED};
