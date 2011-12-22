##
## Library for genoval fixes
##

hasFix() {
  sysctlMatches && return 0;
  return 1;
}

genFix() {
  sysctlMatches && echo "  <fix>$(sysctlFix)</fix>";
}
