#!/bin/sh

if [ $# -ne 2 ] || [ "$1" != "-f" ];
then
  echo "Usage: $0 -f <file> > <file>.DIGESTS"
  exit 1;
fi

typeset FILENAME=$1;

echo "#sha1sum"
sha1sum ${FILENAME};
echo "#md5sum"
md5sum ${FILENAME};
echo "#sha256sum"
sha256sum ${FILENAME};
