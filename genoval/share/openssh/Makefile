guide:
	oscap xccdf generate guide scap-openssh-xccdf.xml > openssh.html
	oscap xccdf generate --format docbook guide scap-openssh-xccdf.xml > openssh.xml
	xsltproc --stringparam paper.type A4 --stringparam ulink.show 0 /usr/share/sgml/docbook/xsl-stylesheets/fo/docbook.xsl openssh.xml > openssh.fop
	fop openssh.fop openssh.pdf

validate:
	oscap xccdf eval --oval-results --profile Default --results xccdf-results.xml --report report.html scap-openssh-xccdf.xml

