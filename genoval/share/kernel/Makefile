guide:
	oscap xccdf generate guide scap-kernel-xccdf.xml > kernel.html
	oscap xccdf generate --format docbook guide scap-kernel-xccdf.xml > kernel.xml
	xsltproc --stringparam paper.type A4 --stringparam ulink.show 0 /usr/share/sgml/docbook/xsl-stylesheets/fo/docbook.xsl kernel.xml > kernel.fop
	fop kernel.fop kernel.pdf

validate:
	oscap xccdf eval --oval-results --profile Full --results xccdf-results.xml --report report.html scap-kernel-xccdf.xml

