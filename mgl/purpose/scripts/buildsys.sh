#!/bin/sh

MGL_PURPOSE=${MGL_PURPOSE:-/mnt/puppet};

. ${MGL_PURPOSE}/scripts/functions.sh

echo ">>> Updating system";
emerge -uDN world --keep-going;
