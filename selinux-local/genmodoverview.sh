#!/bin/sh

typeset USECACHE=$1;
typeset BDIR=$2;
typeset MCONF=$3;
typeset LISTING="";

if [ "${USECACHE}" = "-d" ] || [ "${USECACHE}" = "-D" ];
then
  if [ ! -d ${BDIR} ] || [ ! -f ${MCONF} ];
  then
    echo "Usage: $0 -d <policydir> <modules.conf>"
    echo "Usage: $0 -D <policydir> <modules.conf>";
    echo "Usage: $0 -c <listing>"
    echo "";
    echo "-D does not clean the listing file at the end.";
    exit 1;
  fi
  LISTING=$(mktemp);
elif [ "${USECACHE}" = "-c" ];
then
  if [ ! -f ${BDIR} ];
  then
    echo "Usage: $0 -d <policydir> <modules.conf>"
    echo "Usage: $0 -D <policydir> <modules.conf>";
    echo "Usage: $0 -c <listing>";
    echo "";
    echo "-D does not clean the listing file at the end.";
    exit 1;
  fi
  LISTING=${BDIR};
else
  echo "Usage: $0 -d <policydir> <modules.conf>";
  echo "Usage: $0 -D <policydir> <modules.conf>";
  echo "Usage: $0 -c <listing>";
  echo "";
  echo "-D does not clean the listing file at the end.";
  exit 1;
fi

if [ "${USECACHE}" = "-d" ] || [ "${USECACHE}" = "-D" ];
then

# Generate overview of all "checkable" files
cd ${BDIR};
grep -H gen_context */*.fc | grep -v '\(\*\|\?\|\+\|#\)' | sed -e 's:\\.:.:g' | sed -e 's:^[^/]*/::g' | sed -e 's:\.fc\:: :g' | awk '{print $1" "$2}' > ${LISTING};

# Strip out the base modules
typeset BASEMODS=$(grep '=.*base' ${MCONF} | sed -e 's:[ ]=.*::g');
for BASEMOD in ${BASEMODS};
do
  sed -i -e "/${BASEMOD} /d" ${LISTING}
done

fi ########### End of listing generation

# Test out all files
typeset BULISTING=$(mktemp);
typeset FILES=$(awk '{print $2}' ${LISTING});
for FILE in ${FILES};
do
  if [ -f ${FILE} ] || [ -d ${FILE} ];
  then
    grep "${FILE}" ${LISTING} | awk '{print $1}' >> ${BULISTING};
  fi
done

# Sort / Uniq
cat ${BULISTING} | sort | uniq > ${BULISTING}.new;
mv ${BULISTING}.new ${BULISTING};

# Check against installed modules
for MOD in $(cat ${BULISTING});
do
  if [ ! -f /usr/share/selinux/strict/${MOD}.pp ];
  then
    echo ${MOD}; 
  fi
done

rm ${BULISTING};
if [ "${USECACHE}" = "-d" ];
then
  rm ${LISTING};
elif [ "${USECACHE}" = "-D" ];
then
  echo "Listing file is ${LISTING}";
fi
