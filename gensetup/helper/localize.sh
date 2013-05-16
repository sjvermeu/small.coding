#!/bin/sh

# Keymap management
echo "*** Fixing up keymap";
rc-update del askkeymap boot
rc-update add keymaps boot
sed -i -e 's:^keymap="us":#keymap="us":g' /etc/conf.d/keymaps
sed -i -e 's:^#keymap="be-latin1":keymap="be-latin1":g' /etc/conf.d/keymaps

# /var/portage
echo "*** Setting up portage locations";
mkdir /var/portage /var/portage/distfiles /var/portage/packages;
semanage fcontext -a -f -d -t tmp_t "/var/portage"
semanage fcontext -a -t portage_ebuild_t "/var/portage/distfiles(/.*)?"
semanage fcontext -a -t portage_ebuild_t "/var/portage/packages(/.*)?"
restorecon -RF /var/portage;
chmod 2775 /var/portage/distfiles;
chown portage:portage /var/portage/distfiles;
grep -v "^DISTDIR" /etc/portage/make.conf > /etc/portage/make.conf.temp;
echo "DISTDIR=\"/var/portage/distfiles\"" >> /etc/portage/make.conf.temp;
grep -v "^PKGDIR" /etc/portage/make.conf.temp > /etc/portage/make.conf;
echo "PKGDIR=\"/var/portage/packages\"" >> /etc/portage/make.conf;
grep -v "^GENTOO_MIRRORS" /etc/portage/make.conf > /etc/portage/make.conf.temp;
echo "GENTOO_MIRRORS=\"http://workstation:8080/gensetup/gentoo \${GENTOO_MIRRORS}\"" >> /etc/portage/make.conf.temp;
mv /etc/portage/make.conf.temp /etc/portage/make.conf
test -f /etc/portage/make.conf.temp && rm /etc/portage/make.conf.temp;
restorecon /etc/portage/make.conf;

# fstab
echo "*** Creating fstab updates";
mkdir /mnt/puppet;
grep -v '	nfs4	' /etc/fstab > /tmp/fstab.tmp;
echo "workstation:puppet /mnt/puppet	nfs4	ro,soft,timeo=30	0 0" >> /tmp/fstab.tmp;
echo "workstation:gentoo/portage	/usr/portage	nfs4	ro,soft,timeo=30	0 0" >> /tmp/fstab.tmp;
echo "workstation:gentoo/packages	/var/portage/packages	nfs4	rw,soft,timeo=30,context=system_u:object_r:portage_ebuild_t	0 0" >> /tmp/fstab.tmp;
mv /tmp/fstab.tmp /etc/fstab;
restorecon /etc/fstab;

# SELinux tweaks
echo "*** Enabling portage_use_nfs";
setsebool -P portage_use_nfs on;
selocal -a "allow dhcpc_t self:rawip_socket create_socket_perms;" -c "dhcpclient" -Lb;

# Networking
echo "*** Correct networking (use dhcp)";
rc-update add net.eth0 default;
rc-service dhcpcd stop;
echo "config_eth0=\"dhcp\"" > /etc/conf.d/net;
echo "dhcpcd_eth0=\"-t 5 -L --ipv6ra_own\"" >> /etc/conf.d/net;
sed -i -e 's:^nohook:#nohook:g' /etc/dhcpcd.conf;
grep -v "env force_hostname" /etc/dhcpcd.conf > /etc/dhcpcd.conf.new;
echo "env force_hostname=YES" >> /etc/dhcpcd.conf.new;
mv /etc/dhcpcd.conf.new /etc/dhcpcd.conf;
echo 'if $ifup; then export new_ip_address=${ra1_prefix%%/64}; fi' > /lib/dhcpcd/dhcpcd-hooks/28-set-ip6-address;
restorecon /etc/dhcpcd.conf;
rc-service net.eth0 start;

# NFS mounts
echo "*** Start nfs mounts";
mount -a;
echo "mount -a -t nfs4" > /etc/local.d/90-mount-nfs4.start;
echo "umount -a -t nfs4" > /etc/local.d/90-mount-nfs4.stop;
chmod +x /etc/local.d/90-mount-nfs4.st*;

# eix tweak for portage over nfs
echo "*** eix tweak for portage over nfs";
grep -v '^PORTDIR_CACHE_METHOD' /etc/eixrc > /etc/eixrc.new;
echo "PORTDIR_CACHE_METHOD=\"parse\"" >> /etc/eixrc.new;
mv /etc/eixrc.new /etc/eixrc;
restorecon /etc/eixrc;
