all:
	emerge --info --verbose > emerge-info-verbose
	zcat /proc/config.gz > kernel-config || cp /usr/src/linux/.config kernel-config
	export GENOVAL_SCRIPTOUTPUTDIR=`pwd`
	oscap xccdf generate guide scap-gentoo-xccdf.xml > ~swift/Downloads/scap.html
	oscap xccdf generate --format docbook guide scap-gentoo-xccdf.xml > db-gentoo.xml
	oscap xccdf eval --oval-results --profile Gentoo-Default --results xccdf-results.xml --report ~swift/Downloads/report.html scap-gentoo-xccdf.xml
