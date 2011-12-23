##
## Library for genoval fixes
##

hasFix() {
  sysctlMatches && return 0;
  gentooProfileMatches && return 0;
  return 1;
}

genFix() {
  sysctlMatches && echo "  <fix>$(sysctlFix)</fix>";
  gentooProfileMatches && echo "  <fix>$(gentooProfileFix)</fix>";
}
