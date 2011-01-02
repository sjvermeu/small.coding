#!/bin/sh

checkmodule -m -o fixlocal.mod fixlocal.te
semodule_package -o fixlocal.pp -m fixlocal.mod
