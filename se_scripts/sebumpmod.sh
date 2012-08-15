#!/bin/bash

BASE=/home/swift/Development/Centralized
HRDDEV=${BASE}/hardened-dev/sec-policy;
GENX86=${BASE}/gentoo-x86/sec-policy;
GENOVL=${BASE}/gentoo.overlay/sec-policy;
#GENOVL=/home/swift/Development/build/tmp/sec-policy;
REFPOL=${BASE}/hardened-refpolicy/policy/modules;
MODLIST=${BASE}/small.coding/selinux-modules/patches/MODULELIST;


if [ $# -ne 2 ] || ( [ "$1" != "-l" ] );
then
  echo "$0 - Create modules into gentoo.overlay";
  echo "Usage: $0 -l <pkgversion>";
  exit 1;
fi

REVNUM=$2;
MODULES=$(awk -F';' '{print $1}' ${MODLIST});

cd ${GENOVL};

for MODULE in ${MODULES};
do
  [ ! -f ${REFPOL}/*/${MODULE}.te ] && echo "No module ${MODULE}, continuing...  " && continue;
  # Create dir
  [ ! -d ${GENOVL}/selinux-${MODULE} ] && mkdir ${GENOVL}/selinux-${MODULE};
  # Copy over ChangeLog, metadata, Manifest
  [ -f ${HRDDEV}/selinux-${MODULE}/ChangeLog ] && cp ${HRDDEV}/selinux-${MODULE}/ChangeLog ${GENOVL}/selinux-${MODULE};
  [ ! -f ${GENOVL}/selinux-${MODULE}/ChangeLog ] && cp ${GENX86}/selinux-${MODULE}/ChangeLog ${GENOVL}/selinux-${MODULE};
  [ ! -f ${GENOVL}/selinux-${MODULE}/ChangeLog ] && echo "Mooo... No ChangeLog for module ${MODULE}?";

  [ -f ${HRDDEV}/selinux-${MODULE}/metadata.xml ] && cp ${HRDDEV}/selinux-${MODULE}/metadata.xml ${GENOVL}/selinux-${MODULE};
  [ ! -f ${GENOVL}/selinux-${MODULE}/metadata.xml ] && cp ${GENX86}/selinux-${MODULE}/metadata.xml ${GENOVL}/selinux-${MODULE};
  [ ! -f ${GENOVL}/selinux-${MODULE}/metadata.xml ] && echo "Mooo... No metadata.xml for module ${MODULE}?";

  [ -f ${HRDDEV}/selinux-${MODULE}/Manifest ] && cp ${HRDDEV}/selinux-${MODULE}/Manifest ${GENOVL}/selinux-${MODULE};
  [ ! -f ${GENOVL}/selinux-${MODULE}/Manifest ] && cp ${GENX86}/selinux-${MODULE}/Manifest ${GENOVL}/selinux-${MODULE};
  [ ! -f ${GENOVL}/selinux-${MODULE}/Manifest ] && echo "Mooo... No Manifest for module ${MODULE}?";

  # Generate ebuild
  DEPLIST=$(grep "^${MODULE};" ${MODLIST} | awk -F';' '{print $2}');
  cat > ${GENOVL}/selinux-${MODULE}/selinux-${MODULE}-${REVNUM}.ebuild << EOF
# Copyright 1999-2012 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2
# \$Header: \$
EAPI="4"

IUSE=""
MODS="${MODULE}"
BASEPOL="${REVNUM}"

inherit selinux-policy-2

DESCRIPTION="SELinux policy for ${MODULE}"

KEYWORDS="~amd64 ~x86"
EOF
  if [ -n "${DEPLIST}" ];
  then
    echo "DEPEND=\"\${DEPEND}" >> ${GENOVL}/selinux-${MODULE}/selinux-${MODULE}-${REVNUM}.ebuild;
    for DEP in ${DEPLIST};
    do
      [ ! -f ${REFPOL}/*/${DEP}.te ] && echo "No module ${DEP} (as dependency for ${MODULE}), continuing...  " && continue;
      echo "	sec-policy/selinux-${DEP}" >> ${GENOVL}/selinux-${MODULE}/selinux-${MODULE}-${REVNUM}.ebuild;
    done
    echo "\"" >> ${GENOVL}/selinux-${MODULE}/selinux-${MODULE}-${REVNUM}.ebuild;
    echo "RDEPEND=\"\${DEPEND}\"" >> ${GENOVL}/selinux-${MODULE}/selinux-${MODULE}-${REVNUM}.ebuild;
  fi
done
