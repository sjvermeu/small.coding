psql_full() {
  [ -n "${MGL_DEBUG}" ] && echo "### DEBUG: SQL statement = $*";
  if [ -z "${PGUSER}" ];
  then
    psql -U postgres -c "$*";
  else
    psql -c "$*";
  fi
}

psql_statement() {
  [ -n "${MGL_DEBUG}" ] && echo "### DEBUG: SQL statement = $*" >&3;
  if [ -z "${PGUSER}" ];
  then
    psql -t -A -U postgres -c "$*";
  else
    psql -t -A -c "$*";
  fi
}
