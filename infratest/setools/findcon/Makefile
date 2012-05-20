all: list

list:
	findcon /etc/selinux/$$(sestatus | awk '/policy name/ {print $$NF}')/contexts/files/file_contexts -p /lib/rc/init.d | grep -q initrc_state_t
