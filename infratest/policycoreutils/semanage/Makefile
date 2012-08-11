all: fcontext seuser

##
## semanage fcontext 
##
# Rules to validate if file contexts can be manipulated
fcontext: fcontext_list fcontext_add fcontext_del

fcontext_list:
	@echo "[semanage] testing for base policy defined contexts" && \
	semanage fcontext -l | grep  '^/var/lib/selinux' > /dev/null && \
	@echo "[semanage] testing for substitutions (/lib32 = /lib)" && \
	semanage fcontext -l | grep  '^/lib32.*=.*/lib' > /dev/null

fcontext_add:
	@echo "[semanage] creating additional file context rule" && \
	semanage fcontext -a -t swapfile_t "/swapfile"

fcontext_del: fcontext_add
	@echo "[semanage] removing additional file context rule" && \
	semanage fcontext -d -t swapfile_t "/swapfile"

##
## semanage user
##
# Rules to validate if SELinux users can be manipulated
seuser: seuser_list

seuser_list:
	@echo "[semanage] listing SELinux users" && \
	semanage user -l
