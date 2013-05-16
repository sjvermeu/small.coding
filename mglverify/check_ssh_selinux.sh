#!/bin/sh

fail() {
  echo "failed";
  awk "/^${1}/ {f=1; next} /^  [^#]/ {f=0} f { sub(\"  \", \"\"); print}" ${0};
  return 1;
}

check_selinuxfs() {
  # The /sys/fs/selinux mount point is not available or
  # the selinuxfs file system is not mounted on it.
  # Please follow the instructions at
  # http://www.gentoo.org/proj/en/hardened/selinux/selinux-handbook.xml
  # as this mount should occur automatically the moment SELinux is enabled.
  test -f /sys/fs/selinux/enforce || return 1
}

check_selinux_enabled() {
  # SELinux does not seem to be enabled or "sestatus" does not
  # properly work. Make sure that your kernel is built with 
  # CONFIG_SECURITY_SELINUX=y and CONFIG_DEFAULT_SECURITY_SELINUX=y and
  # that your Gentoo installation system is set up according to the online
  # instructions at http://www.gentoo.org/proj/en/hardened/selinux/selinux-handbook.xml
  local output=$(/usr/sbin/sestatus | awk '/^SELinux status/ {print $3}')
  [ "${output}" = "enabled" ] || return 1
}

check_sshd_context() {
  # The SELinux context of /usr/sbin/sshd does not match 
  # sshd_exec_t. Without this, the SSH daemon will not be
  # ran in the sshd_t context but instead remain in the context
  # of the calling process (most likely an init script).
  # 
  # Run "rlpkg openssh" to reset the context of the files provided
  # by the openssh package, or run "rlpkg -a -r" to reset the contexts
  # of all files on the file system.
  local context=$(ls -Z /usr/sbin/sshd | awk '{print $1}')
  [ "${context##*:}" = "sshd_exec_t" ] || return 1
}

check_init_context() {
  # The SELinux context of /sbin/init does not match
  # init_exec_t. Without this, the SSH daemon will not be
  # ran in the init_t context but instead remain in the
  # kernel_t context.
  #
  # Run "rlpkg -a -r" to reset the contexts of all files on the file system.
  local context=$(ls -Z /sbin/init | awk '{print $1}')
  [ "${context##*:}" = "init_exec_t" ] || return 1
}

check_init_sshd_context() {
  # The SELinux context of /etc/init.d/sshd does not match
  # initrc_exec_t. Without this, the SSH service script will
  # run in the context of init rather than the proper initrc_t
  # context.
  #
  # Run "rlpkg openssh" to reset the context of the files provided
  # by the openssh package, or run "rlpkg -a -r" to reset the contexts
  # of all files on the file system.
  local context=$(ls -Z /etc/init.d/sshd | awk '{print $1}')
  [ "${context##*:}" = "initrc_exec_t" ] || return 1;
}

check_init_t() {
  # The init process is not running in the init_t context. As a result,
  # services will not be ran in initrc_t and the daemons will have an
  # improper context. This usually occurs if init is not SELinux-aware
  # (built with USE=selinux which is forced through the SELinux Gentoo
  # profiles).
  local context=$(ps -p 1 -hZ | awk '{print $1}')
  [ "${context##*:}" = "init_t" ] || return 1;
}

check_user_context() {
  # Your current context is not sysadm_t. Make sure you have switched
  # to the sysadm_r role before launching SSH or doing any other system
  # administrative tasks.
  #
  # newrole -r sysadm_r
  #
  # You can check your current context using "id -Z". If it displays
  # user_t at the end (or user_u at the beginning) you are not in a 
  # privileged role. If it sais staff_t, then the "newrole" command
  # above is needed to get to sysadm_t. Once it sais "sysadm_t" at the
  # end, then you are in the right context.
  local context=$(id -Z)
  [ "${context##*:}" = "sysadm_t" ] || return 1;
}

check_sshd_t() {
  # The sshd process is not running in the sshd_t context. As a result,
  # users will not be able to log on as SELinux cannot deduce the proper
  # context for these users. 
  #
  # Make sure sshd is started through an init script, like with
  # ~# rc-service sshd start
  # This should only be ran when you, as admin, are in the sysadm_t context.
  local context=$(ps -p "`pidof sshd`" -hZ | grep '/sshd' | awk '{print $1}')
  [ "${context##*:}" = "sshd_t" ] || return 1;
}

check_default_contexts() {
  # When SSH processes a user login, the default context for the user
  # is attained. This default context is stored in the 
  # /etc/selinux/%policy%/contexts/default_contexts file.
  #
  # In this file, or in the user specific files in the users subdirectory,
  # the sshd_t originating context should be found.
  local seltype=$(awk -F'=' '/^SELINUXTYPE/ {print $2}' /etc/selinux/config)
  test -f /etc/selinux/${seltype}/contexts/default_contexts || return 1;
  grep -qHR sshd_t /etc/selinux/${seltype}/contexts/{default_contexts,users/*} || return 1;
}

echo -n "Checking selinuxfs... "
check_selinuxfs && echo "ok" || fail check_selinuxfs;

echo -n "Checking if SELinux is enabled... "
check_selinux_enabled && echo "ok" || fail check_selinux_enabled;

echo -n "Checking if init file context is correct... "
check_init_context && echo "ok" || fail check_init_context;

echo -n "Checking /etc/init.d/sshd file context... "
check_init_sshd_context && echo "ok" || fail check_init_sshd_context;

echo -n "Checking sshd file context... "
check_sshd_context && echo "ok" || fail check_sshd_context;

echo -n "Checking user context... "
check_user_context && echo "ok" || fail check_user_context;

echo -n "Checking if init runs in init_t... "
check_init_t && echo "ok" || fail check_init_t;

echo -n "Checking if sshd runs in sshd_t... "
check_sshd_t && echo "ok" || fail check_sshd_t;

echo -n "Checking if default_contexts is present... "
check_default_contexts && echo "ok" || fail check_default_contexts;
