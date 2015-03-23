#!/bin/sh

echo "Forcing default use of Python 2.7"
eselect python set 1

echo "Updating make.conf"
cat > /etc/portage/make.conf << EOF
CFLAGS="-O2 -pipe"
CXXFLAGS=""
CHOST="x86_64-pc-linux-gnu"
USE="bindist mmx sse sse2 -unconfined ubac"
PORTDIR="/usr/portage"
DISTDIR="/var/portage/distfiles"
PKGDIR="/var/portage/packages"
MAKEOPTS="-j2"
POLICY_TYPES="mcs"
EOF

echo "Updating portage configuration specifics"
mkdir -p /etc/portage/package.use
cat > /etc/portage/package.use/selinux << EOF
dev-libs/libpcre static-libs
sys-libs/libselinux static-libs
EOF

echo "Switching profile"
NUM=$(eselect --color=no profile list | grep hardened/linux/amd64/no-multilib/selinux | sed -e 's:.*\[::g' -e 's:\].*::g');
eselect profile set ${NUM}

echo "Installing policies and utilities"
emerge -1 checkpolicy policycoreutils

echo "Installing base policy"
FEATURES="-selinux" emerge -1 selinux-base

echo "Setting up SELinux configuration"
cat > /etc/selinux/config << EOF
SELINUX=permissive
SELINUXTYPE=mcs
EOF

echo "Reinstalling base policy"
FEATURES="-selinux" emerge -1 selinux-base
FEATURES="-selinux" emerge selinux-base-policy

echo "Updating world"
emerge -uDkN @world

echo "Updating /etc/fstab for SELinux"
cat > /etc/fstab << EOF
/dev/vda2	/boot	ext2	noauto,noatime	1 2
/dev/vda3	/	ext4	noatime		0 1
/dev/vdb1	none	swap	sw		0 0
# SELinux resources
tmpfs	/tmp	tmpfs	defaults,noexec,nosuid,nodev,rootcontext=system_u:object_r:tmp_t:s0	0 0
tmpfs	/run	tmpfs	mode=0755,nosuid,nodev,rootcontext=system_u:object_r:var_run_t:s0	0 0
# Additional resources
workstation4:/usr/portage	/usr/portage	nfs4	defaults	0 0
workstation4:/srv/virt/nfs/gentoo/packages	/var/portage/packages	nfs4	defaults	0 0
EOF

