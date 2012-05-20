all:	type typeattr attr attrtypes stats role roletypes user userroles

type:
	seinfo -tsysadm_t | grep -q sysadm_t

typeattr:
	seinfo -tsysadm_t -x | grep -q admindomain

attr:
	seinfo -aadmindomain | grep -q admindomain

attrtype:
	seinfo -aadmindomain -x | grep -q sysadm_t

stats:
	seinfo | grep -q Permissives

role:
	seinfo -rsysadm_r | grep -q sysadm_r

roletypes:
	seinfo -rsysadm_r -x | grep -q setfiles_t

user:
	seinfo -uroot | grep -q root

userroles:
	seinfo -uroot -x | grep -q sysadm_r

