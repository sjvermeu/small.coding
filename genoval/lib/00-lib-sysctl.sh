##
## Sysctl related functions
##

sysctlMatches() {
  echo ${LINE} | grep -q '^sysctl ' && return 0;
  return 1;
}

sysctlFile() {
  echo "${LINE}" | sed -e 's:sysctl \([^ ]*\) .*:/proc/sys/\1:g' | sed -e 's:\.:/:g';
}

sysctlRegexp() {
  echo "${LINE}" | sed -e 's:.* must be ::g';
}

sysctlFix() {
  local FILE=$(sysctlFile);
  local VALUE=$(sysctlRegexp);

  echo "echo ${VALUE} &gt; ${FILE}";
}
