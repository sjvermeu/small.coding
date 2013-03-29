all: fcontext seuser permissive

##
## semanage fcontext 
##
# Rules to validate if file contexts can be manipulated
fcontext: fcontext_list fcontext_add fcontext_del

fcontext_list:
	echo "[semanage] testing for base policy defined contexts" && \
	semanage fcontext -l | grep  '^/var/lib/selinux' > /dev/null && \
	echo "[semanage] testing for substitutions (/lib32 = /lib)" && \
	semanage fcontext -l | grep  '^/lib32.*=.*/lib' > /dev/null

fcontext_add:
	echo "[semanage] creating additional file context rule" && \
	semanage fcontext -a -t swapfile_t "/swapfile2"

fcontext_del: fcontext_add
	echo "[semanage] removing additional file context rule" && \
	semanage fcontext -d -t swapfile_t "/swapfile2"

##
## semanage user
##
# Rules to validate if SELinux users can be manipulated
seuser: seuser_list

seuser_list:
	echo "[semanage] listing SELinux users" && \
	semanage user -l | grep user_u | grep user_r > /dev/null

##
## semanage permissive
##
# Rules to validate if permissive domains can be enabled
permissive: permissive_portage_on permissive_portage_off

permissive_portage_on:
	echo "[semanage] marking portage_t as a permissive domain" && \
	semanage permissive -a portage_t > /dev/null

permissive_portage_off:
	echo "[semanage] marking portage_t as an enforced domain again" && \
	semanage permissive -d portage_t > /dev/null
