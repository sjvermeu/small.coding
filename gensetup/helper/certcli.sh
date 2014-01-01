#!/bin/sh

export KEYLOC=${KEYLOC:=/etc/ssl};
export RANDFILE=${RANDFILE:=${KEYLOC}/.rnd};
export WORKSPACE=${WORKSPACE:=${KEYLOC}/workspace};

die() {
  echo "!! $*";
  exit 1;
}

toparg="";
createrootflag=0;
listrootflag=0;
createchildflag=0;
listchildflag=0;
parentflag=0;
signflag=0;
output="";
outputflag=0;
valid="";
validflag=0;
requestflag=0;
revokeflag=0;
parent="";

if [ $# -eq 0 ] || [ "$1" = "-h" ] || [ "$1" = "--help" ];
then
  echo "$(basename $0) <command> [<options>] <value>";
  echo "";
  echo "Command can be one of:";
  echo "  -r, --create-root		Create a root CA key named <value>";
  echo "  -l, --list-root               List root CAs (self-signed CAs)";
  echo "  -c, --create-child		Create a child CA key named <value> for parent";
  echo "  -L, --list-child              List child CAs for given parent";
  echo "  -s, --sign-request		Sign a certificate request (<value> is input)";
  echo "  -R, --create-request		Create a key and signing request named <value>.req";
  echo "  -x, --revoke                  Revoke the key matching <value>";
  echo "";
  echo "Options can be one of:";
  echo "  -p, --parent <parent>		Use <parent> as the parent key value";
  echo "  -o, --output <file>		Save resulting file as <file>";
  echo "  -v, --valid <days>		Number of days that the certificate is valid";
  echo "";
  echo "Environment variables used:";
  echo "  KEYLOC [/etc/ssl]             Base directory used by the script.";
  echo "  RANDFILE [KEYLOC/.rnd]        Random file used by OpenSSL.";
  echo "  WORKSPACE [KEYLOC/workspace]  Location where non-CA keys/certs are placed.";
  exit 1;
fi

eval set -- "$(getopt -n $(basename $0) -s sh -o rlRcLsxp:o:v: --long create-root,list-root,create-request,create-child,list-child,sign-request,revoke,parent:,output:,valid: -- "$@")"
while [ $# -gt 0 ];
do
  case "$1" in
    (-r) createrootflag=1;;
    (--create-root) createrootflag=1;;
    (-l) listrootflag=1;;
    (--list-root) listrootflag=1;;
    (-R) requestflag=1;;
    (--create-request) requestflag=1;;
    (-c) createchildflag=1;;
    (--create-child) createchildflag=1;;
    (-L) listchildflag=1;;
    (--list-child) listchildflag=1;;
    (-s) signflag=1;;
    (--sign-request) signflag=1;;
    (-x) revokeflag=1;;
    (--revoke) revokeflag=1;;
    (-p) parentflag=1; parent="$2"; shift;;
    (--parent) parentflag=1; parent="$2"; shift;;
    (-o) outputflag=1; output="$2"; shift;;
    (--output) outputflag=1; output="$2"; shift;;
    (-v) validflag=1; valid="$2"; shift;;
    (--valid) validflag=1; valid="$2"; shift;;
    (--) toparg="$2"; shift; break;;
    (-*) echo "$(basename $0): error: Unrecognized option $1" 1>&2; exit 1;;
    (*) break;;
  esac
  shift;
done

[ ! -d ${WORKSPACE} ] && (mkdir ${WORKSPACE} || die "Could not create workspace ${WORKSPACE}");

if [ ${createrootflag} -eq 1 ];
then
  if [ -z "${toparg}" ];
  then
    echo "The name of the root certificate must be passed.";
    echo "";
    echo "Example: $0 -r genfic";
    exit 1;
  fi
  if [ -d ${KEYLOC}/${toparg} ];
  then
    echo "Location ${KEYLOC}/${toparg} already exists!";
    exit 1;
  fi
  echo "##";
  echo "## Creating root key";
  echo "##";
  echo "# The result will be a file called root-${toparg}.key which is the private"
  echo "# key. Make sure that you keep the passphraze on a secure location.";
  echo "#";
  pushd ${KEYLOC};
  mkdir ${toparg} || die "Failed to make directory ${toparg}";
  mkdir ${toparg}/private || die "Failed to make directory ${toparg}";
  cd ${toparg} || die "Could not go to ${toparg}";
  echo "Running: openssl genrsa -des3 -out private/root-${toparg}.key 2048";
  openssl genrsa -des3 -out private/root-${toparg}.key 2048 || die "OpenSSL failed";
  echo "##";
  echo "## Creating root key certificate";
  echo "##";
  echo "# The result will be a file called root-${toparg}.crt which is the self-signed"
  echo "# certificate for the root key. This will need to be stored in all your"
  echo "# truststores across the environment. The certificate is valid for 20 years.";
  echo "#";
  echo "# The request will ask for certificate information.";
  echo "# - Keep the OU empty";
  echo "# - Fill CN with a generic description, like \"GenFic Root CA\"";
  echo "# - Keep the E-mail address empty";
  echo "#";
  echo "Running: openssl req -new -x509 -days 7205 -key private/root-${toparg}.key -out root-${toparg}.crt";
  openssl req -new -x509 -days 7205 -key private/root-${toparg}.key -out root-${toparg}.crt || die "OpenSSL failed";
  echo "##";
  echo "## Creating CA structure";
  echo "##";
  echo "# Creates the CA structure with an openssl.cnf file specific for this CA."
  echo "#";
  mkdir newcerts || die "Could not create newcerts directory";
  touch index.txt || die "Could not create index file";
  echo 01 > crlnumber || die "Could not initialize crlnumber";
  echo 01 > serial || die "Could not initialize serial";
  cat > openssl.cnf << EOF || die "Could not create openssl.cnf"
[ ca ]
default_ca	= CA_default

[ CA_default ]
dir		= ${KEYLOC}/${toparg}
database	= \$dir/index.txt
new_certs_dir	= \$dir/newcerts

certificate	= \$dir/root-${toparg}.crt
serial		= \$dir/serial
private_key	= \$dir/private/root-${toparg}.key
RANDFILE	= \$dir/private/.rand

default_md	= sha1

policy		= policy_any
email_in_dn	= no

[ v3_req ]

basicConstraints	= CA:FALSE
keyUsage	= nonRepudiation, digitalSignature, keyEncipherment

[ v3_ca ]
subjectKeyIdentifier	= hash
authorityKeyIdentifier	= keyid:always,issuer
basicConstraints	= CA:true

[ policy_any ]
countryName		= supplied
stateOrProvinceName	= optional
organizationName	= optional
organizationalUnitName	= optional
commonName		= supplied
emailAddress		= optional
EOF
  echo "##";
  echo "## Creating revocation list";
  echo "##";
  echo "#";
  echo "Running: openssl ca -config ./openssl.cnf -gencrl -crldays 365 -keyfile private/root-${toparg}.key -cert root-${toparg}.crt -out root-${toparg}.crl";
  openssl ca -config ./openssl.cnf -gencrl -crldays 365 -keyfile private/root-${toparg}.key -cert root-${toparg}.crt -out root-${toparg}.crl
  popd > /dev/null 2>&1;
fi

if [ ${listrootflag} -eq 1 ];
then
  for DIR in ${KEYLOC}/*;
  do
    for FILE in ${DIR}/*.crt;
    do
      [ ! -f "${FILE}" ] && continue;
      # See if the certificate is self-signed
      DIFF=$(openssl x509 -noout -text -in ${FILE} | grep -E '(Issuer|Subject):' | sed -e 's:^[^\:]*::g' | sort | uniq | wc -l);
      if [ "${DIFF}" = "1" ];
      then
        # Certificate is self-signed
	CERTNAME=$(basename ${DIR});
	CERTID=$(openssl x509 -noout -text -in ${FILE} | grep 'Subject:' | sed -e 's:^[^\:]*\:::g' | sed -e 's:^[ 	]*::g' -e 's:[ 	]*$::g');
	EXPIRE=$(openssl x509 -noout -text -in ${FILE} | grep 'Not After :' | sed -e 's:^.*Not After \:::g');
	echo "${CERTNAME}";
	echo "  ${CERTID}";
	echo "  expires ${EXPIRE}";
      fi
    done
  done
fi

if [ ${listchildflag} -eq 1 ];
then
  if [ ${parentflag} -ne 1 ];
  then
    echo "You need to pass a parent key identifier";
    echo "";
    echo "Example: $0 -p genfic -L";
    exit 1;
  fi
  # Get Subject from given parent
  PARENTSUBJECT=$(openssl x509 -noout -text -in ${KEYLOC}/${parent}/root-${parent}.crt | grep 'Subject:' | sed -e 's:.*Subject\:::g');
  # Now look for keys signed (Issuer:) by this subject

  for DIR in ${KEYLOC}/*;
  do
    for FILE in ${DIR}/*.crt;
    do
      [ ! -f "${FILE}" ] && continue;
      # See if the certificate is self-signed (if so, then no)
      DIFF=$(openssl x509 -noout -text -in ${FILE} | grep -E '(Issuer|Subject):' | sed -e 's:^[^\:]*::g' | sort | uniq | wc -l);
      if [ "${DIFF}" = "1" ];
      then
        continue;
      fi
      KEYISSUER=$(openssl x509 -noout -text -in ${FILE} | grep 'Issuer:' | sed -e 's:^.*Issuer\:::g');
      if [ "${PARENTSUBJECT}" = "${KEYISSUER}" ];
      then
        # Certificate is signed by given parent
	CERTNAME=$(basename ${DIR});
	CERTID=$(openssl x509 -noout -text -in ${FILE} | grep 'Subject:' | sed -e 's:^[^\:]*\:::g' | sed -e 's:^[ 	]*::g' -e 's:[ 	]*$::g');
	EXPIRE=$(openssl x509 -noout -text -in ${FILE} | grep 'Not After :' | sed -e 's:^.*Not After \:::g');
	echo "${CERTNAME}";
	echo "  ${CERTID}";
	echo "  expires ${EXPIRE}";
      fi
    done
  done
fi


if [ ${createchildflag} -eq 1 ];
then
  if [ -d ${KEYLOC}/${toparg} ];
  then
    echo "Location ${KEYLOC}/${toparg} already exists!";
    exit 1;
  fi
  if [ ${parentflag} -ne 1 ];
  then
    echo "You need to provide the parent key!";
    exit 1;
  fi
  echo "##";
  echo "## Creating child key";
  echo "##";
  echo "# The result will be a file called ${toparg}.key which is the private"
  echo "# key. Make sure that you keep the passphraze on a secure location.";
  echo "#";
  pushd ${KEYLOC} || die "Could not enter ${KEYLOC}";
  mkdir ${toparg} || die "Could not create ${toparg}";
  cd ${toparg} || die "Could not enter ${toparg}";
  mkdir private || die "Could not create private dir";
  echo "Running: openssl genrsa -des3 -out private/${toparg}.key 2048";
  openssl genrsa -des3 -out private/${toparg}.key 2048 || die "OpenSSL failed";
  echo "##";
  echo "## Creating key certificate";
  echo "##";
  echo "# The result will be a file called ${toparg}.csr which is the request"
  echo "# to be signed by the root key. This will need to be stored in all your"
  echo "# truststores across the environment. The certificate is valid for 3 years.";
  echo "# The system will ask for a challenge too. This is optional and can be left";
  echo "# empty (it is used to \"protect\" revocation).";
  echo "#";
  echo "Running: openssl req -new -days 1095 -key private/${toparg}.key -out ${toparg}.csr";
  openssl req -new -days 1095 -key private/${toparg}.key -out ${toparg}.csr || die "OpenSSL failed";
  echo "##";
  echo "## Signing certificate";
  echo "##";
  echo "#";
  echo "Running: openssl ca -config ../${parent}/openssl.cnf -name CA_default -days 1095 -extensions v3_ca -out ${toparg}.crt -infiles ${toparg}.csr";
  openssl ca -config ../${parent}/openssl.cnf -name CA_default -days 1095 -extensions v3_ca -out ${toparg}.crt -infiles ${toparg}.csr || die "OpenSSL failed"
  echo "##";
  echo "## Creating CA structure";
  echo "##";
  echo "# Creates the CA structure with an openssl.cnf file specific for this CA."
  echo "#";
  mkdir newcerts || die "Could not create newcerts directory";
  touch index.txt || die "Could not set index.txt";
  echo 01 > crlnumber || die "Could not initialize crlnumber";
  echo 01 > serial || die "Could not initialize serial";
  cat > openssl.cnf << EOF || die "Could not setup openssl.cnf"
[ ca ]
default_ca	= CA_default

[ CA_default ]
dir		= ${KEYLOC}/${toparg}
database	= \$dir/index.txt
new_certs_dir	= \$dir/newcerts

certificate	= \$dir/${toparg}.crt
serial		= \$dir/serial
private_key	= \$dir/private/${toparg}.key
RANDFILE	= \$dir/private/.rand

default_md	= sha1

policy		= policy_any
email_in_dn	= no

[ v3_req ]

basicConstraints	= CA:FALSE
keyUsage	= nonRepudiation, digitalSignature, keyEncipherment

[ v3_ca ]
subjectKeyIdentifier	= hash
authorityKeyIdentifier	= keyid:always,issuer
basicConstraints	= CA:true

[ policy_any ]
countryName		= supplied
stateOrProvinceName	= optional
organizationName	= optional
organizationalUnitName	= optional
commonName		= supplied
emailAddress		= optional
EOF
  echo "##";
  echo "## Creating revocation list";
  echo "##";
  echo "#";
  echo "Running: openssl ca -config ./openssl.cnf -gencrl -crldays 365 -keyfile private/${toparg}.key -cert ${toparg}.crt -out ${toparg}.crl";
  openssl ca -config ./openssl.cnf -gencrl -crldays 365 -keyfile private/${toparg}.key -cert ${toparg}.crt -out ${toparg}.crl || die "OpenSSL failed"
  popd > /dev/null 2>&1;
fi

if [ ${signflag} -eq 1 ];
then
  if [ ${outputflag} -eq 0 ];
  then
    echo "Signing request requires an output.";
    exit 1;
  fi
  if [ ${parentflag} -eq 0 ];
  then
    echo "Signing request requires a parent key.";
    exit 1;
  fi
  if [ ${validflag} -eq 0 ];
  then
    valid=396;
  fi
  echo "##";
  echo "## Signing request";
  echo "##";
  echo "Running: openssl ca -config ${KEYLOC}/${parent}/openssl.cnf -name CA_default -days ${valid} -out ${output} -infiles ${toparg}";
  openssl ca -config ${KEYLOC}/${parent}/openssl.cnf -name CA_default -days ${valid} -out ${output} -infiles ${toparg} || die "OpenSSL failed";
fi

if [ ${requestflag} -eq 1 ];
then
  echo "##";
  echo "## Creating request";
  echo "##";
  echo "Running: openssl req -newkey rsa:2048 -keyout ${toparg}.key -out ${toparg}.req";
  openssl req -newkey rsa:2048 -keyout ${toparg}.key -out ${toparg}.req || die "OpenSSL failed";
fi

if [ ${revokeflag} -eq 1 ];
then
  if [ ${parentflag} -eq 0 ];
  then
    echo "Revoking certificates requires a parent key.";
    exit 1;
  fi
  echo "##";
  echo "## Revoking certificates";
  echo "##";
  echo "## TODO";
fi
  
