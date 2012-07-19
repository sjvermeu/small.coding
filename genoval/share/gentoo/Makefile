guide:
	oscap xccdf generate guide scap-gentoo-xccdf.xml > gentoo.html
	oscap xccdf generate --format docbook guide scap-gentoo-xccdf.xml > gentoo.xml
	xsltproc --stringparam paper.type A4 --stringparam ulink.show 0 /usr/share/sgml/docbook/xsl-stylesheets/fo/docbook.xsl gentoo.xml > gentoo.fop
	fop gentoo.fop gentoo.pdf

validate:
	emerge --info --verbose > emerge-info-verbose
	zcat /proc/config.gz > kernel-config || cp /usr/src/linux/.config kernel-config
	export GENOVAL_SCRIPTOUTPUTDIR=`pwd`
	oscap xccdf eval --oval-results --profile Gentoo-Default --results xccdf-results.xml --report report.html scap-gentoo-xccdf.xml

