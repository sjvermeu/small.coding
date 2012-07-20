all: openssh gentoo kernel

validate_all: validate_openssh validate_gentoo validate_kernel

openssh:
	./genoval.sh share/openssh scap-openssh-xccdf.xml.template org.gentoo.dev.swift openssh-definitions.conf share/openssh
	(cd share/openssh && $(MAKE) guide)

validate_openssh:
	(cd share/openssh && $(MAKE) validate)

gentoo:
	./genoval.sh share/gentoo scap-gentoo-xccdf.xml.template org.gentoo.dev.swift gentoo-definitions.conf share/gentoo
	(cd share/gentoo && $(MAKE) guide)

validate_gentoo: 
	(cd share/gentoo && $(MAKE) validate)

kernel:
	./genoval.sh share/kernel scap-kernel-xccdf.xml.template org.gentoo.dev.swift kernel-definitions.conf share/kernel
	(cd share/kernel && $(MAKE) guide)

validate_kernel:
	(cd share/kernel && $(MAKE) validate)

clean:
	rm objects.conf
	rm states.conf
	rm variabels.conf
	rm definitions.conf
