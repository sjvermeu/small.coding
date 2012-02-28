#!/bin/sh

if ([ $# -eq 1 ] && [ ! -f $1 ]) || ([ $# -eq 2 ] && [ ! -f $2 ]);
then
  echo "Usage: $0 <image>";
  echo "Usage: $0 -E <image>";
  echo "";
  echo "Supported <images> values:";
  grep -v 'base$' /srv/virt/IMAGES | awk -F',' '{print $1" with MAC "$2}';
  echo "";
  echo "Base images are:";
  grep 'base$' /srv/virt/IMAGES | awk -F',' '{print $1" with MAC "$2}';
  exit 1;
fi

typeset IMAGE="";
typeset DOMAX=0;
typeset RESTCMDLINE="";
if [ $# -eq 1 ];
then
  IMAGE=$1;
  shift;
else
  IMAGE=$2;
  DOMAX=1;
  shift; shift;
fi
typeset MAC=$(grep /${IMAGE##*/} /srv/virt/IMAGES | awk -F',' '{print $2}');
typeset PRT=$(grep /${IMAGE##*/} /srv/virt/IMAGES | awk -F',' '{print $3}');
typeset DEV=$(grep /${IMAGE##*/} /srv/virt/IMAGES | awk -F',' '{print $4}');
typeset MEM=$(grep /${IMAGE##*/} /srv/virt/IMAGES | awk -F',' '{print $5}');
typeset EOP=$(grep /${IMAGE##*/} /srv/virt/IMAGES | awk -F',' '{print $6}');
typeset VNC=$((${PRT}-1234));

typeset RESTCMDLINE=$*;

if [ ${DOMAX} -eq 1 ];
then
  MEM=1536;
  EOP=$(echo ${EOP} | sed -e 's:-smp [0-9]:-smp 4:g');
fi

PORT=${PRT};

if [[ "${DEV}" == "virtio" ]];
then
  echo "Running: qemu-system-x86_64 --enable-kvm -gdb tcp::${PORT} -vnc 127.0.0.1:${VNC} -net nic,model=virtio,macaddr=${MAC},vlan=0 -net vde,vlan=0 -drive file=${IMAGE},if=virtio,boot=on ${EOP} -k nl-be -m ${MEM} ${RESTCMDLINE}";
  qemu-system-x86_64 --enable-kvm -gdb tcp::${PORT} -vnc 127.0.0.1:${VNC} -net nic,model=virtio,macaddr=${MAC},vlan=0 -net vde,vlan=0 -drive file=${IMAGE},if=virtio,boot=on ${EOP} -cpu kvm64 -k nl-be -m ${MEM} ${RESTCMDLINE};
else
  echo "Running: qemu-system-x86_64 --enable-kvm -gdb tcp::${PORT} -vnc 127.0.0.1:${VNC} -net nic,model=rtl8139,macaddr=${MAC},vlan=0 -net vde,vlan=0 -drive file=${IMAGE},boot=on ${EOP} -k nl-be -m ${MEM} ${RESTCMDLINE}";
  qemu-system-x86_64 --enable-kvm -gdb tcp::${PORT} -vnc 127.0.0.1:${VNC} -net nic,model=rtl8139,macaddr=${MAC},vlan=0 -net vde,vlan=0 -drive file=${IMAGE},boot=on ${EOP} -cpu kvm64 -k nl-be -m ${MEM} ${RESTCMDLINE};
fi
