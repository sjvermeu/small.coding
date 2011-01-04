#!/bin/sh

checkmodule -m -o gorg.mod gorg.te
semodule_package -o gorg.pp -m gorg.mod
