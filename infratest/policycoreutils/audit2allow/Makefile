all: simple ifgen refpolicy dmesg

simple:
	echo "[audit2allow] generating simple test module based on AVC denial"
	echo "May 18 20:40:17 testsys kernel: [    2.171094] type=1400 audit(1337366413.170:4): avc:  denied  { read write open } for  pid=1005 comm="dmesg" name="console" dev="devtmpfs" ino=1035 scontext=system_u:system_r:dmesg_t tcontext=system_u:object_r:device_t tclass=chr_file" | audit2allow -m test | grep -q 'read write open';

ifgen:
	echo "[audit2allow] generating interface info (sepolgen-ifgen, needed for next test)"
	sepolgen-ifgen > /dev/null 2>&1;

refpolicy:
	echo "[audit2allow] generating refpolicy style test module based on AVC denial"
	echo "Jul  2 18:27:44 testsys kernel: [80550.070669] type=1400 audit(1341246464.078:62): avc:  denied  { write } for  pid=23875 comm="dhcpcd-run-hook" name="hostname" dev="proc" ino=3551 scontext=system_u:system_r:dhcpc_t tcontext=system_u:object_r:sysctl_kernel_t tclass=file" | audit2allow -m test -R | grep -q 'kernel_rw_kernel_sysctl';

dmesg:
	echo "[audit2allow] generating SELinux statements for dmesg output"
	audit2allow -d 2>&1 | grep -vq 'Traceback' 
