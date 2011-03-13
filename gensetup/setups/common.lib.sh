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
  updateEqualNoQuotConfFile conf.hostname ${FILE};
  applyMetaOnFile ${FILE} ${META};
  commitChangeFile ${FILE} ${META};
  logMessage "done\n";

  logMessage "  > Setting hostname... ";
  hostname $(getValue conf.hostname.HOSTNAME);
  logMessage "done\n";

  logMessage "  > Updating /etc/resolv.conf... ";
  FILE=/etc/resolv.conf;
  META=$(initChangeFile ${FILE});
  echo "$(getValue sys.resolv)" > ${FILE};
  applyMetaOnFile ${FILE} ${META};
  commitChangeFile ${FILE} ${META};
  logMessage "done\n";

  logMessage "  > Updating 70-persistent-net.rules... ";
  FILE=/etc/udev/rules.d/70-persistent-net.rules;
  META=$(initChangeFile ${FILE});
  typeset MACA=$(ifconfig -a | awk '/eth/ {print $5}');
  sed -i -e "s|\(SUBSYSTEM.*ATTR{address}==\"\).*\(\", ATTR{dev_id}.*NAME=\"eth0\"\)|\1${MACA}\2|g" ${FILE};
  applyMetaOnFile ${FILE} ${META};
  commitChangeFile ${FILE} ${META};
  logMessage "done\n";

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
}


