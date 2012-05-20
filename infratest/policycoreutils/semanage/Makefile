all: fcontext

##
## semanage fcontext 
##
# Rules to validate if file contexts can be manipulated
fcontext: fcontext_list fcontext_add fcontext_del

fcontext_list:
	semanage fcontext -l | grep  '^/var/lib/selinux' > /dev/null
	semanage fcontext -l | grep  '^/lib32.*=.*/lib' > /dev/null

fcontext_add:
	semanage fcontext -a -t swapfile_t "/swapfile"

fcontext_del:
	semanage fcontext -d -t swapfile_t "/swapfile"
	
