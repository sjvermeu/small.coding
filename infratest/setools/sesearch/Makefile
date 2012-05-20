all: direct targetattr sourceattr bothattr boolean transition roleallow dontaudit

## 
## Rules to check sesearch options
##

direct:
	sesearch -s sysadm_t -t init_t -c fd -p use -A | grep -q allow
	sesearch -s sysadm_t -t initrc_t -c process -p signal -A | grep -q allow

targetattr:
	sesearch -s sysadm_t -t domain -c process -p signal -A -d | grep -q allow

sourceattr:
	sesearch -s userdomain -t sshd_t -c fd -p use -A -d | grep -q allow

bothattr:
	sesearch -s files_unconfined_type -t file_type -c file -p read -A -d | grep -q allow

boolean:
	# allow_execmem must be OFF for this test
	getsebool allow_execmem | grep -q off
	sesearch -s user_t -t user_t -c process -p execmem -A -d -C | grep -E -q '^DT.*allow_execmem'

transition:
	sesearch -s sysadm_t -t setfiles_exec_t -T | grep -q 'setfiles_t'

roleallow:
	sesearch --role_allow --role_source=sysadm_r --role_target=system_r | grep -q allow

dontaudit:
	sesearch --dontaudit -s sysadm_t -t kernel_t -c process -p getattr | grep -q dontaudit	
