all:
	oscap xccdf generate guide scap-gentoo-xccdf.xml > ~swift/Downloads/scap.html
	oscap xccdf eval --oval-results --profile Gentoo-Default --results xccdf-results.xml --report ~swift/Downloads/report.html scap-gentoo-xccdf.xml
