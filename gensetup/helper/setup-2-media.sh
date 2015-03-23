#!/bin/sh

echo "Preparing the disks"
PARTED="parted -a optimal --script -- "

echo "  Parted: partitioning /dev/vda"
$PARTED /dev/vda mklabel gpt
$PARTED /dev/vda mkpart primary 1MiB 3MiB
$PARTED /dev/vda name 1 grub
$PARTED /dev/vda set 1 bios_grub on
$PARTED /dev/vda mkpart primary 3MiB 131MiB
$PARTED /dev/vda name 2 boot
$PARTED /dev/vda mkpart primary 131MiB -1
$PARTED /dev/vda name 3 rootfs

echo "  Parted: partitioning /dev/vdb"
$PARTED /dev/vdb mklabel gpt
$PARTED /dev/vdb mkpart primary 1MiB -1
$PARTED /dev/vdb name 1 swap

echo "File system and mounting"

echo "  Formatting file systems"
mkfs.ext2 /dev/vda2 > /dev/null 2>&1
mkfs.ext4 /dev/vda3 > /dev/null 2>&1
mkswap /dev/vdb1 > /dev/null 2>&1
swapon /dev/vdb1

echo "  Mounting /mnt/gentoo"
mkdir /mnt/gentoo > /dev/null 2>&1
mount /dev/vda3 /mnt/gentoo > /dev/null 2>&1
mkdir /mnt/gentoo/boot > /dev/null 2>&1
mount /dev/vda2 /mnt/gentoo/boot > /dev/null 2>&1

echo "Downloading and extracting stage3"

echo "  Downloading stage3 (this can take a while)"
cd /mnt/gentoo
URL="http://distfiles.gentoo.org/releases/amd64/autobuilds/current-stage3-amd64-hardened+nomultilib/"
URLFILE=$(wget -O - "http://distfiles.gentoo.org/releases/amd64/autobuilds/current-stage3-amd64-hardened+nomultilib/" 2>/dev/null | grep 'stage3-amd64-hardened+nomultilib' | grep '.bz2"' | sed -e 's:.*href="stage:stage:g' -e 's:bz2">.*:bz2:g')

wget ${URL}/${URLFILE} > /dev/null 2>&1;

echo "  Extracting stage3"

tar xjpf ${URLFILE};

echo "  Removing stage3"

rm ${URLFILE};

echo "  Mounting /usr/portage"

mkdir -p /mnt/gentoo/usr/portage
mount -t nfs4 192.168.100.1:/usr/portage /mnt/gentoo/usr/portage

echo "Updating settings prior to chrooting"

mkdir -p /mnt/gentoo/var/portage/distfiles
mkdir -p /mnt/gentoo/var/portage/packages

echo "  Updating make.conf"

cat > /mnt/gentoo/etc/portage/make.conf << EOF
CFLAGS="-O2 -pipe"
CXXFLAGS="${CFLAGS}"
CHOST="x86_64-pc-linux-gnu"
USE="bindist mmx sse sse2"
PORTDIR="/usr/portage"
DISTDIR="/var/portage/distfiles"
PKGDIR="/var/portage/packages"
MAKEOPTS="-j2"
EOF

echo "  Network information"

echo "192.168.100.1	workstation4" > /mnt/gentoo/etc/hosts
echo 'config_eth0="dhcp"' > /mnt/gentoo/etc/conf.d/net
cp -L /etc/resolv.conf /mnt/gentoo/etc/

echo "  Filesystem information"

cat > /mnt/gentoo/etc/fstab << EOF
/dev/vda2	/boot	ext2	noauto,noatime	1 2
/dev/vda3	/	ext4	noatime		0 1
/dev/vdb1	none	swap	sw		0 0
# Additional resources
workstation4:/usr/portage	/usr/portage	nfs4	defaults	0 0
workstation4:/srv/virt/nfs/gentoo/packages	/var/portage/packages	nfs4	defaults	0 0
EOF

echo "  Mounting file systems"

mount -t proc proc /mnt/gentoo/proc
mount --make-rprivate --rbind /sys /mnt/gentoo/sys
mount --make-rprivate --rbind /dev /mnt/gentoo/dev

echo "  Profile"

cd /mnt/gentoo/etc/portage && rm make.profile && ln -s ../../usr/portage/profiles/hardened/linux/amd64/no-multilib make.profile

echo "  Time"

echo "Europe/Brussels" > /mnt/gentoo/etc/timezone

echo "  Locales"

cat > /mnt/gentoo/etc/locale.gen << EOF
en_US ISO-8859-1
en_US.UTF-8 UTF-*
EOF

echo "Preparing for kernel build"

echo "  Downloading current kernel configuration"

mkdir -p /mnt/gentoo/usr/src/config
wget http://dev.gentoo.org/~swift/kvm-kernel-config /mnt/gentoo/usr/src/config/kernelconfig > /dev/null 2>&1

echo "  Installing chroot setup script"

cat > /mnt/gentoo/setup.sh << EOF
#!/bin/sh

source /etc/profile
export LOCALE="C"
export LC_ALL="C"

emerge hardened-sources
cd /usr/src/linux
cp /usr/src/config/kernelconfig .config
make oldconfig
make && make modules_install
make install

emerge --noreplace netifrc

emerge dhcpcd

emerge rsyslog

emerge nfs-utils
rc-update add nfs default

emerge vim

emerge bind-tools

rc-update add sshd default

emerge sys-boot/grub

echo "root:rootpass" | chpasswd root

groupadd operators
groupadd administrators

useradd -m -g users user
echo "user:userpass" | chpasswd user

useradd -m -g operators oper
echo "oper:operpass" | chpasswd oper

useradd -m -g administrators admin
echo "admin:adminpass" | chpasswd admin

gpasswd -a portage wheel

emerge app-crypt/gnupg dev-vcs/git

grub2-install /dev/vda
grub2-mkconfig -o /boot/grub/grub.cfg
EOF

echo "Calling chroot setup"

chroot /mnt/gentoo /usr/sbin/env-update
chroot /mnt/gentoo /bin/sh /setup.sh
rm /mnt/gentoo/setup.sh

echo "Unmounting file systems"

umount -l /mnt/gentoo/dev{/shm,/pts,}
umount /mnt/gentoo{/boot,/sys,/proc,}

