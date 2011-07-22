_configsystem() {
  logMessage "  > Updating /etc/conf.d/net... ";
  typeset FILE=/etc/conf.d/net;
  typeset META=$(initChangeFile ${FILE});
  updateEqualNoQuotConfFile conf.net ${FILE};
  applyMetaOnFile ${FILE} ${META};
  commitChangeFile ${FILE} ${META};
  logMessage "done\n";

  logMessage "  > Updating /etc/conf.d/hostname... ";
  typeset FILE=/etc/conf.d/hostname;
  typeset META=$(initChangeFile ${FILE});
  updateEqualConfFile conf.hostname ${FILE};
  applyMetaOnFile ${FILE} ${META};
  commitChangeFile ${FILE} ${META};
  logMessage "done\n";

  logMessage "  > Setting hostname... ";
  hostname $(getValue conf.hostname.HOSTNAME);
  logMessage "done\n";

  logMessage "  > Updating /etc/resolv.conf... ";
  FILE=/etc/resolv.conf;
  restorecon ${FILE};
  META=$(initChangeFile ${FILE});
  echo "search $(getValue sys.resolv.search)" > ${FILE};
  for NS in $(getValue sys.resolv.nameservers);
  do
    echo "nameserver ${NS}" >> ${FILE};
  done
  applyMetaOnFile ${FILE} ${META};
  commitChangeFile ${FILE} ${META};
  logMessage "done\n";

  logMessage "  > Updating 70-persistent-net.rules... ";
  FILE=/etc/udev/rules.d/70-persistent-net.rules;
  if [ ! -f ${FILE} ];
  then
    logMessage "skipped\n";
  else
    META=$(initChangeFile ${FILE});
    typeset MACA=$(ifconfig -a | awk '/eth/ {print $5}');
    sed -i -e "s|\(SUBSYSTEM.*ATTR{address}==\"\).*\(\", ATTR{dev_id}.*NAME=\"eth0\"\)|\1${MACA}\2|g" ${FILE};
    applyMetaOnFile ${FILE} ${META};
    commitChangeFile ${FILE} ${META};
    logMessage "done\n";
  fi

  logMessage "  > Updating /etc/hosts... ";
  FILE=/etc/hosts;
  META=$(initChangeFile ${FILE});
  echo "127.0.0.1     localhost" > ${FILE};
  echo "$(getValue sys.hosts)"  >> ${FILE};
  applyMetaOnFile ${FILE} ${META};
  commitChangeFile ${FILE} ${META};
  logMessage "done\n";

  logMessage "  > Updating /etc/make.conf... ";
  FILE=/etc/make.conf;
  META=$(initChangeFile ${FILE});
  updateEqualConfFile sys.makeconf ${FILE};
  applyMetaOnFile ${FILE} ${META};
  commitChangeFile ${FILE} ${META};
  logMessage "done\n";

  logMessage "  > Setting up swapspace (128M)... ";
  if [ ! -f /swapfile ];
  then
    dd if=/dev/zero of=/swapfile bs=1024k count=128;
    chcon -t swapfile_t /swapfile;
    semanage fcontext -a -t swapfile_t "/swapfile";
    mkswap /swapfile;
    swapon /swapfile;
    logMessage "done\n";
  else
    logMessage "skipped\n";
  fi

  logMessage "  > Configuring fstab... ";
  grep -q '/swapfile' /etc/fstab;
  if [ $? -ne 0 ];
  then
    typeset FILE=/etc/fstab;
    typeset META=$(initChangeFile ${FILE});
    echo "/swapfile	none	swap	sw	0 0" >> /etc/fstab
    applyMetaOnFile ${FILE} ${META};
    commitChangeFile ${FILE} ${META};
    logMessage "done\n";
  else
    logMessage "skipped\n";
  fi

  logMessage "  > Restoring /etc/selinux context... ";
  restorecon -R /etc/selinux;
  logMessage "done\n";
}

_setuppam() {
  logMessage "  > Installing PAM software... ";
  installSoftware -u pam_ldap || die "Failed to install pam_ldap";
  installSoftware -u nss_ldap || die "Failed to install nss_ldap";
  logMessage "done\n";

  logMessage "  > Updating system-auth PAM configuration... ";
  typeset FILE=/etc/pam.d/system-auth;
  typeset META=$(initChangeFile ${FILE});

  sed -i -e "s|auth.*required.*pam_unix\(.*\)|auth	sufficient	pam_unix\1|g" ${FILE};
  grep -q 'auth.*pam_ldap' ${FILE};
  if [ $? -ne 0 ];
  then
    awk "{print} /auth.*pam_unix/ {print \"auth	sufficient	 pam_ldap.so use_first_pass\"}" ${FILE} > ${FILE}.new;
    mv ${FILE}.new ${FILE};
  fi
  awk "{print} /auth.*pam_ldap/ {print \"auth	required	pam_deny.so\"}" ${FILE} > ${FILE}.new;
  mv ${FILE}.new ${FILE};

  grep -q 'account.*pam_ldap' ${FILE};
  if [ $? -ne 0 ];
  then
    awk "{print} /account.*pam_unix/ {print \"account	sufficient	pam_ldap.so\"}" ${FILE} > ${FILE}.new;
    mv ${FILE}.new ${FILE};
  fi

  sed -i -e "s|password.*required.*pam_unix\(.*\)|password	sufficient	pam_unix\1|g" ${FILE};
  grep -q 'password.*pam_ldap' ${FILE};
  if [ $? -ne 0 ];
  then
    awk "{print} /password.*pam_unix/ {print \"password	sufficient	pam_ldap.so use_authtok use_first_pass\"}" ${FILE} > ${FILE}.new;
    mv ${FILE}.new ${FILE};
  fi

  grep -q 'session.*pam_ldap' ${FILE};
  if [ $? -ne 0 ];
  then
    awk "{print} /session.*pam_unix/ {print \"session	optional	pam_ldap.so\"}" ${FILE} > ${FILE}.new;
    mv ${FILE}.new ${FILE};
  fi

  applyMetaOnFile ${FILE} ${META};
  commitChangeFile ${FILE} ${META};
  logMessage "done\n";

  logMessage "  > Updating /etc/ldap.conf... ";
  FILE=/etc/ldap.conf;
  META=$(initChangeFile ${FILE});
  grep -q '^host' ${FILE};
  if [ $? -eq 0 ];
  then
    sed -i -e "s|^host|# host|g" ${FILE};
  fi

  grep -q '^base' ${FILE};
  if [ $? -eq 0 ];
  then
    sed -i -e "s|^base|# base|g" ${FILE};
  fi
  
  cat >> ${FILE} << EOF
suffix "dc=virtdomain,dc=com"
bind_policy soft
bind_timelimit 2
ldap_version 3
nss_base_group ou=Group,dc=virtdomain,dc=com
nss_base_hosts ou=Hosts,dc=virtdomain,dc=com
nss_base_passwd ou=People,dc=virtdomain,dc=com
nss_base_shadow ou=People,dc=virtdomain,dc=com
pam_filter objectclass=posixAccount
pam_login_attribute uid
pam_member_attribute memberuid
pam_password exop
scope one
timelimit 2
uri ldap://ldap.virtdomain.com/ ldap://ldap1.virtdomain.com ldap://ldap2.virtdomain.com
EOF

  applyMetaOnFile ${FILE} ${META};
  commitChangeFile ${FILE} ${META};
  logMessage "done\n";

  logMessage "  > Update nsswitch.conf... ";
  FILE=/etc/nsswitch.conf
  META=$(initChangeFile ${FILE});
  sed -i -e "s|passwd:.*|passwd:	files ldap|g" ${FILE};
  sed -i -e "s|group:.*|group:	files ldap|g" ${FILE};
  sed -i -e "s|shadow:.*|shadow:	files ldap|g" ${FILE};
  applyMetaOnFile ${FILE} ${META};
  commitChangeFile ${FILE} ${META};
  logMessage "done\n";

  # At the end of installations.
  # I know this has impact on the zabbix server itself. Let's figure that out
  # when we get there...
  logMessage "  > Installing zabbix agent... ";
  installSoftware -u selinux-zabbix || die "Failed to install selinux-zabbix policy";
  installSoftware -u zabbix || die "Failed to install zabbix agent";
  logMessage "done\n";

  logMessage "  > Setting up zabbix agent... ";
  typeset FILE=/etc/zabbix/zabbix_agentd.conf;
  typeset META=$(initChangeFile ${FILE});
  updateEqualNoQuotConfFile etc.zabbix.agent ${FILE}
  applyMetaOnFile ${FILE} ${META};
  commitChangeFile ${FILE} ${META};
  logMessage "done\n";

  logMessage "  > Adding zabbix-agentd to default runlevel... ";
  rc-update add zabbix-agentd default;
  logMessage "done\n";
}
