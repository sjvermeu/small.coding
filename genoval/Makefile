all: openssh gentoo

validate_all: validate_openssh validate_gentoo

openssh:
	./genoval.sh share/openssh scap-openssh-xccdf.xml.template org.gentoo.dev.swift openssh-definitions.conf share/openssh
	(cd share/openssh && $(MAKE) guide)

validate_openssh: openssh
	(cd share/openssh && $(MAKE) validate)

gentoo:
	./genoval.sh share/gentoo scap-gentoo-xccdf.xml.template org.gentoo.dev.swift gentoo-definitions.conf share/gentoo
	(cd share/gentoo && $(MAKE) guide)

validate_gentoo: gentoo
	(cd share/gentoo && $(MAKE) guide)

clean:
	rm objects.conf
	rm states.conf
	rm variabels.conf
	rm definitions.conf
