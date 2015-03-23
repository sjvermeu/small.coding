#!/bin/sh

rlpkg -a -r

setsebool -P global_ssp on

semanage login -a -s staff_u oper

semanage login -a -s sysadm_u admin

restorecon -RvF /home

semanage user -m -R "object_r sysadm_r system_r" root
semanage user -m -R "object_r staff_r sysadm_r system_r" staff_u
semanage user -m -R "object_r sysadm_r system_r" sysadm_u

cat > /etc/portage/make.conf << EOF
CFLAGS="-O2 -pipe"
CXXFLAGS=""
CHOST="x86_64-pc-linux-gnu"
USE="bindist mmx sse sse2 -unconfined ubac xattr"
PORTDIR="/usr/portage"
PORT_LOGDIR="/var/log/portage"
DISTDIR="/var/portage/distfiles"
PKGDIR="/var/portage/packages"
MAKEOPTS="-j2"
POLICY_TYPES="mcs"
FEATURES="buildpkg"
EOF

semanage fcontext -a -t portage_ebuild_t "/var/portage/distfiles(/.*)?"
restorecon -RvF /var/portage/distfiles

semanage fcontext -a -t portage_srcrepo_t "/var/portage/distfiles/egit-src(/.*)?"
restorecon -RvF /var/portage/distfiles

cat > /etc/pam.d/run_init << EOF
#%PAM-1.0
# Uncomment the next line if you do not want to enter your passwd everytime
auth       sufficient   pam_rootok.so
auth       include	system-auth
account    include	system-auth
password   include	system-auth
session    include	system-auth
session    optional	pam_xauth.so
EOF

rc-update add auditd default
run_init rc-service auditd start

rc-update add sshd default

rc-update add rsyslog default

cat > /etc/dhcpcd.conf << EOF
hostname
duid
persistent
option rapid_commit
option domain_name_servers, domain_name, domain_search, host_name
option classless_static_routes
option ntp_servers
require dhcp_server_identifier
slaac private
#nohook lookup-hostname
env force_hostname=YES
EOF

cat > /etc/selinux/mcs/contexts/users/root << EOF
system_r:crond_t:s0		sysadm_r:cronjob_t:s0 staff_r:cronjob_t:s0 user_r:cronjob_t:s0
system_r:local_login_t:s0	sysadm_r:sysadm_t:s0 staff_r:staff_t:s0 user_r:user_t:s0

staff_r:staff_su_t:s0		sysadm_r:sysadm_t:s0 staff_r:staff_t:s0 user_r:user_t:s0
sysadm_r:sysadm_su_t:s0		sysadm_r:sysadm_t:s0 staff_r:staff_t:s0 user_r:user_t:s0
user_r:user_su_t:s0		sysadm_r:sysadm_t:s0 staff_r:staff_t:s0 user_r:user_t:s0

#
# Uncomment if you want to automatically login as sysadm_r
#
system_r:sshd_t:s0		sysadm_r:sysadm_t:s0 staff_r:staff_t:s0 user_r:user_t:s0
EOF

setsebool -P ssh_sysadm_login on

mkdir -p /etc/portage/package.accept_keywords

cat > /etc/portage/package.accept_keywords/salt << EOF
app-admin/salt
=dev-python/msgpack-0.4.2
EOF

emerge -k selinux-salt

emerge -k salt

rc-update add salt-minion default

run_init rc-service salt-minion start
