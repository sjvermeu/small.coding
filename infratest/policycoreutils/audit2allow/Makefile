all: simple dmesg

simple:
	@echo "[audit2allow] generating simple test module based on AVC denial"
	echo "May 18 20:40:17 testsys kernel: [    2.171094] type=1400 audit(1337366413.170:4): avc:  denied  { read write open } for  pid=1005 comm="dmesg" name="console" dev="devtmpfs" ino=1035 scontext=system_u:system_r:dmesg_t tcontext=system_u:object_r:device_t tclass=chr_file" | audit2allow -m test | grep -q 'read write open';

dmesg:
	@echo "[audit2allow] generating SELinux statements for dmesg output"
	audit2allow -d 2>&1 | grep -vq 'Traceback' 
