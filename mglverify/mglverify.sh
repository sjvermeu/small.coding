#!/bin/sh

CONFDIR=~/.mglverify

if [ $# -lt 1 ] || [ "$1" = "-h" ] || [ "1" == "--help" ];
then
	echo "Usage: $(basename $0) <command> [<options>] <checkfile>"
	echo "";
	echo "Command can be one of:";
	echo "  check		Check if the system adheres to the provided checks"
	echo "  fix		If possible, fix the change on the system"
	echo "";
	echo "Options can be one of:";
	echo "  -r, --rule <id>		Rule id(s) to limit the check to";
	echo "  -s, --set <key>=<value>	Set a key/value pair to use";
	echo "  -N, --noask		Do not ask to provide a variable if it is not set";
	echo "  -R, --read <file>	File to read parameters from";
fi

