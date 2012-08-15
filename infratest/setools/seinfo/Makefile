all:	type typeattrs attr attrtypes stats role roletypes user userroles

type:
	echo "[seinfo] checking existance of domain"
	seinfo -tsysadm_t | grep -q sysadm_t

typeattrs:
	echo "[seinfo] viewing attributes of domain"
	seinfo -tsysadm_t -x | grep -q admindomain

attr:
	echo "[seinfo] checking existance of attribute"
	seinfo -aadmindomain | grep -q admindomain

attrtypes:
	echo "[seinfo] looking for types matching attribute"
	seinfo -aadmindomain -x | grep -q sysadm_t

stats:
	echo "[seinfo] checking stats"
	seinfo | grep -q Permissives

role:
	echo "[seinfo] checking existance of role"
	seinfo -rsysadm_r | grep -q sysadm_r

roletypes:
	echo "[seinfo] looking for types matching role"
	seinfo -rsysadm_r -x | grep -q setfiles_t

user:
	echo "[seinfo] checking existance of user"
	seinfo -uroot | grep -q root

userroles:
	echo "[seinfo] checking roles matching user"
	seinfo -uroot -x | grep -q sysadm_r
