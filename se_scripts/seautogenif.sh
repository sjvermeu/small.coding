#!/bin/sh

if [ "$1" != "-r" ] || [ $# -ne 2 ];
then
  echo "Usage: $0 -r <conffile>"
  exit 1;
fi

CONFFILE=$2;

MODULE=$(awk -F'=' '/MODULE=/ {print $2}' ${CONFFILE});

##
## genDomtrans <module>
## 
## Generate the <module>_domtrans interface
genDomtrans() {
  typeset MODULE=$1;
  typeset WORKNAME=${MODULE}/${MODULE}_domtrans
  typeset WORKNAMEFILE=${WORKNAME}.autogen.iface
  typeset TYPE=$(awk -F'=' "/${MODULE}.DOMAIN=/ {print \$2}" ${CONFFILE});
  typeset ETYPE=$(awk -F'=' "/${MODULE}.EXEC=/ {print \$2}" ${CONFFILE});

  if [ -f ${WORKNAME}.part ];
  then
    echo "Skipping generation of ${WORKNAME}, .part exists.";
    return;
  fi

  echo "Generating ${WORKNAME}"

  cat > ${WORKNAMEFILE} << EOF
#######################################
## <summary>
## 	Execute a domain transition to the ${MODULE} domain (${TYPE})
## </summary>
## <param name="domain">
## 	<summary>
##	Domain allowed access
##	</summary>
## </param>
#
interface(\`${MODULE}_domtrans',\`
	gen_require(\`
		type ${TYPE};
		type ${ETYPE};
	')

	corecmd_search_bin(\$1)
	domtrans_pattern(\$1, ${ETYPE}, ${TYPE})
')
EOF
}

##
## genRun <module>
## 
## Generate the <module>_run interface
genRun() {
  typeset MODULE=$1;
  typeset WORKNAME=${MODULE}/${MODULE}_run
  typeset WORKNAMEFILE=${WORKNAME}.autogen.iface
  typeset TYPE=$(awk -F'=' "/${MODULE}.DOMAIN=/ {print \$2}" ${CONFFILE});

  if [ -f ${WORKNAME}.part ];
  then
    echo "Skipping generation of ${WORKNAME}, .part exists.";
    return;
  fi

  echo "Generating ${WORKNAME}"

  cat > ${WORKNAMEFILE} << EOF
#######################################
## <summary>
## 	Execute ${MODULE} in the ${MODULE} domain and allow the specified role to access the ${MODULE} domain
## </summary>
## <param name="domain">
## 	<summary>
##	Domain allowed access
##	</summary>
## </param>
## <param name="role">
##	<summary>
##	Role allowed access
##	</summary>
## </param>
#
interface(\`${MODULE}_run',\`
	gen_require(\`
		type ${TYPE};
	')

	${MODULE}_domtrans(\$1)
	role \$2 types ${TYPE};
')
EOF
}

##
## genRole <module>
## 
## Generate the <module>_role interface
genRole() {
  typeset MODULE=$1;
  typeset WORKNAME=${MODULE}/${MODULE}_role
  typeset WORKNAMEFILE=${WORKNAME}.autogen.iface
  typeset TYPE=$(awk -F'=' "/${MODULE}.DOMAIN=/ {print \$2}" ${CONFFILE});
  typeset ETYPE=$(awk -F'=' "/${MODULE}.EXEC=/ {print \$2}" ${CONFFILE});

  if [ -f ${WORKNAME}.part ];
  then
    echo "Skipping generation of ${WORKNAME}, .part exists.";
    return;
  fi

  echo "Generating ${WORKNAME}"

  cat > ${WORKNAMEFILE} << EOF
#######################################
## <summary>
## 	Role access for ${MODULE}
## </summary>
## <param name="role">
##	<summary>
##	Role allowed access
##	</summary>
## </param>
## <param name="domain">
## 	<summary>
##	User domain for the role
##	</summary>
## </param>
#
interface(\`${MODULE}_role',\`
	gen_require(\`
		type ${TYPE};
		type ${ETYPE};
	')

	role \$1 types ${TYPE};

	# Transition from the user domain to the derived domain
	${MODULE}_domtrans(\$2)

	# Allow ps to show ${MODULE} processes and allow the user to signal it
	ps_process_pattern(\$2, ${TYPE})
	allow \$2 ${TYPE}:process signal_perms;
')
EOF
}

##
## genReadConfig <module>
## 
## Generate the <module>_read_config interface
genReadConfig() {
  typeset MODULE=$1;
  typeset WORKNAME=${MODULE}/${MODULE}_read_config
  typeset WORKNAMEFILE=${WORKNAME}.autogen.iface
  typeset TYPE=$(awk -F'=' "/${MODULE}.${UGENTYPE}.TYPE=/ {print \$2}" ${CONFFILE});
  typeset SCOPE=$(awk -F'=' "/${MODULE}.${UGENTYPE}.SCOPE=/ {print \$2}" ${CONFFILE});

  if [ -f ${WORKNAME}.part ];
  then
    echo "Skipping generation of ${WORKNAME}, .part exists.";
    return;
  fi

  echo "Generating ${WORKNAME}"

  cat > ${WORKNAMEFILE} << EOF
#######################################
## <summary>
## 	Read the ${MODULE} configuration
## </summary>
## <param name="domain">
## 	<summary>
##	Domain allowed access
##	</summary>
## </param>
#
interface(\`${MODULE}_read_config',\`
	gen_require(\`
		type ${TYPE};
	')

	files_search_etc(\$1)
EOF
  
  if [ "${SCOPE}" = "file" ];
  then
    echo "	read_files_pattern(\$1, ${TYPE}, ${TYPE})" >> ${WORKNAMEFILE};
  elif [ "${SCOPE}" = "file dir" ];
  then
    echo "	list_dirs_pattern(\$1, ${TYPE}, ${TYPE})" >> ${WORKNAMEFILE};
    echo "	read_files_pattern(\$1, ${TYPE}, ${TYPE})" >> ${WORKNAMEFILE};
  fi
 
  echo "')" >> ${WORKNAMEFILE};
}

##
## genRWConfig <module>
## 
## Generate the <module>_rw_config interface
genRWConfig() {
  typeset MODULE=$1;
  typeset WORKNAME=${MODULE}/${MODULE}_rw_config
  typeset WORKNAMEFILE=${WORKNAME}.autogen.iface
  typeset TYPE=$(awk -F'=' "/${MODULE}.${UGENTYPE}.TYPE=/ {print \$2}" ${CONFFILE});
  typeset SCOPE=$(awk -F'=' "/${MODULE}.${UGENTYPE}.SCOPE=/ {print \$2}" ${CONFFILE});

  if [ -f ${WORKNAME}.part ];
  then
    echo "Skipping generation of ${WORKNAME}, .part exists.";
    return;
  fi

  echo "Generating ${WORKNAME}"

  cat > ${WORKNAMEFILE} << EOF
#######################################
## <summary>
## 	Read from and write to the ${MODULE} configuration
## </summary>
## <param name="domain">
## 	<summary>
##	Domain allowed access
##	</summary>
## </param>
#
interface(\`${MODULE}_rw_config',\`
	gen_require(\`
		type ${TYPE};
	')

	files_search_etc(\$1)
EOF
  
  if [ "${SCOPE}" = "file" ];
  then
    echo "	rw_files_pattern(\$1, ${TYPE}, ${TYPE})" >> ${WORKNAMEFILE};
  elif [ "${SCOPE}" = "file dir" ];
  then
    echo "	rw_dirs_pattern(\$1, ${TYPE}, ${TYPE})" >> ${WORKNAMEFILE};
    echo "	rw_files_pattern(\$1, ${TYPE}, ${TYPE})" >> ${WORKNAMEFILE};
  fi
 
  echo "')" >> ${WORKNAMEFILE};
}

##
## genManageConfig <module>
## 
## Generate the <module>_manage_config interface
genManageConfig() {
  typeset MODULE=$1;
  typeset WORKNAME=${MODULE}/${MODULE}_manage_config
  typeset WORKNAMEFILE=${WORKNAME}.autogen.iface
  typeset TYPE=$(awk -F'=' "/${MODULE}.${UGENTYPE}.TYPE=/ {print \$2}" ${CONFFILE});
  typeset SCOPE=$(awk -F'=' "/${MODULE}.${UGENTYPE}.SCOPE=/ {print \$2}" ${CONFFILE});

  if [ -f ${WORKNAME}.part ];
  then
    echo "Skipping generation of ${WORKNAME}, .part exists.";
    return;
  fi

  echo "Generating ${WORKNAME}"

  cat > ${WORKNAMEFILE} << EOF
#######################################
## <summary>
## 	Manage the ${MODULE} configuration
## </summary>
## <param name="domain">
## 	<summary>
##	Domain allowed access
##	</summary>
## </param>
#
interface(\`${MODULE}_manage_config',\`
	gen_require(\`
		type ${TYPE};
	')

	files_search_etc(\$1)
EOF
  
  if [ "${SCOPE}" = "file" ];
  then
    echo "	manage_files_pattern(\$1, ${TYPE}, ${TYPE})" >> ${WORKNAMEFILE};
  elif [ "${SCOPE}" = "file dir" ];
  then
    echo "	manage_dirs_pattern(\$1, ${TYPE}, ${TYPE})" >> ${WORKNAMEFILE};
    echo "	manage_files_pattern(\$1, ${TYPE}, ${TYPE})" >> ${WORKNAMEFILE};
  fi
 
  echo "')" >> ${WORKNAMEFILE};
}

##
## genReadLogs <module>
## 
## Generate the <module>_read_logs interface
genReadLogs() {
  typeset MODULE=$1;
  typeset WORKNAME=${MODULE}/${MODULE}_read_logs
  typeset WORKNAMEFILE=${WORKNAME}.autogen.iface
  typeset TYPE=$(awk -F'=' "/${MODULE}.${UGENTYPE}.TYPE=/ {print \$2}" ${CONFFILE});
  typeset SCOPE=$(awk -F'=' "/${MODULE}.${UGENTYPE}.SCOPE=/ {print \$2}" ${CONFFILE});

  if [ -f ${WORKNAME}.part ];
  then
    echo "Skipping generation of ${WORKNAME}, .part exists.";
    return;
  fi

  echo "Generating ${WORKNAME}"

  cat > ${WORKNAMEFILE} << EOF
#######################################
## <summary>
## 	Read the ${MODULE} logs
## </summary>
## <param name="domain">
## 	<summary>
##	Domain allowed access
##	</summary>
## </param>
#
interface(\`${MODULE}_read_logs',\`
	gen_require(\`
		type ${TYPE};
	')

	logging_search_logs(\$1)
EOF
  
  if [ "${SCOPE}" = "file" ];
  then
    echo "	read_files_pattern(\$1, ${TYPE}, ${TYPE})" >> ${WORKNAMEFILE};
  elif [ "${SCOPE}" = "file dir" ];
  then
    echo "	list_dirs_pattern(\$1, ${TYPE}, ${TYPE})" >> ${WORKNAMEFILE};
    echo "	read_files_pattern(\$1, ${TYPE}, ${TYPE})" >> ${WORKNAMEFILE};
  fi
 
  echo "')" >> ${WORKNAMEFILE};
}

##
## genManageLogs <module>
## 
## Generate the <module>_manage_logs interface
genManageLogs() {
  typeset MODULE=$1;
  typeset WORKNAME=${MODULE}/${MODULE}_manage_logs
  typeset WORKNAMEFILE=${WORKNAME}.autogen.iface
  typeset TYPE=$(awk -F'=' "/${MODULE}.${UGENTYPE}.TYPE=/ {print \$2}" ${CONFFILE});
  typeset SCOPE=$(awk -F'=' "/${MODULE}.${UGENTYPE}.SCOPE=/ {print \$2}" ${CONFFILE});

  if [ -f ${WORKNAME}.part ];
  then
    echo "Skipping generation of ${WORKNAME}, .part exists.";
    return;
  fi

  echo "Generating ${WORKNAME}"

  cat > ${WORKNAMEFILE} << EOF
#######################################
## <summary>
## 	Manage the ${MODULE} logs
## </summary>
## <param name="domain">
## 	<summary>
##	Domain allowed access
##	</summary>
## </param>
#
interface(\`${MODULE}_manage_logs',\`
	gen_require(\`
		type ${TYPE};
	')

	logging_search_logs(\$1)
EOF
  
  if [ "${SCOPE}" = "file" ];
  then
    echo "	manage_files_pattern(\$1, ${TYPE}, ${TYPE})" >> ${WORKNAMEFILE};
  elif [ "${SCOPE}" = "file dir" ];
  then
    echo "	manage_dirs_pattern(\$1, ${TYPE}, ${TYPE})" >> ${WORKNAMEFILE};
    echo "	manage_files_pattern(\$1, ${TYPE}, ${TYPE})" >> ${WORKNAMEFILE};
  fi
 
  echo "')" >> ${WORKNAMEFILE};
}

##
## genSearchVar <module>
## 
## Generate the <module>_search_var_* interfaces
genSearchVar() {
  typeset MODULE=$1;
  typeset WORKNAME=${MODULE}/${MODULE}_search_var
  typeset WORKNAMEFILE=${WORKNAME}.autogen.iface
  typeset TYPE=$(awk -F'=' "/${MODULE}.${UGENTYPE}.TYPE=/ {print \$2}" ${CONFFILE});
  typeset SCOPE=$(awk -F'=' "/${MODULE}.${UGENTYPE}.SCOPE=/ {print \$2}" ${CONFFILE});

  if [ -f ${WORKNAME}.part ];
  then
    echo "Skipping generation of ${WORKNAME}, .part exists.";
    return;
  fi

  echo "Generating ${WORKNAME}"

  cat > ${WORKNAMEFILE} << EOF
#######################################
## <summary>
## 	Search through the ${MODULE} var data directories
## </summary>
## <param name="domain">
## 	<summary>
##	Domain allowed access
##	</summary>
## </param>
#
interface(\`${MODULE}_search_var',\`
	gen_require(\`
		type ${TYPE};
	')

	files_search_var(\$1)
	search_dirs_pattern(\$1, ${TYPE}, ${TYPE})
')
EOF
}

##
## genReadVar <module>
## 
## Generate the <module>_read_var_* interfaces
genReadVar() {
  typeset MODULE=$1;
  typeset WORKNAME=${MODULE}/${MODULE}_read_var
  typeset WORKNAMEFILE=${WORKNAME}.autogen.iface
  typeset TYPE=$(awk -F'=' "/${MODULE}.${UGENTYPE}.TYPE=/ {print \$2}" ${CONFFILE});
  typeset SCOPE=$(awk -F'=' "/${MODULE}.${UGENTYPE}.SCOPE=/ {print \$2}" ${CONFFILE});

  if [ -f ${WORKNAME}.part ];
  then
    echo "Skipping generation of ${WORKNAME}, .part exists.";
    return;
  fi

  echo "Generating ${WORKNAME}"

  cat > ${WORKNAMEFILE} << EOF
#######################################
## <summary>
## 	Read the ${MODULE} variable data (any type)
## </summary>
## <param name="domain">
## 	<summary>
##	Domain allowed access
##	</summary>
## </param>
#
interface(\`${MODULE}_read_var',\`
	gen_require(\`
		type ${TYPE};
	')

	files_search_var(\$1)
EOF
  
  if [ "${SCOPE}" = "file" ];
  then
    echo "	read_files_pattern(\$1, ${TYPE}, ${TYPE})" >> ${WORKNAMEFILE};
  elif [ "${SCOPE}" = "file dir" ];
  then
    echo "	list_dirs_pattern(\$1, ${TYPE}, ${TYPE})" >> ${WORKNAMEFILE};
    echo "	read_files_pattern(\$1, ${TYPE}, ${TYPE})" >> ${WORKNAMEFILE};
  fi
 
  echo "')" >> ${WORKNAMEFILE};

  ##
  ## files class
  ##
  echo "${SCOPE[@]}" | grep -E -q '(^| )file';
  if [ $? -eq 0 ];
  then

    echo "Generating ${WORKNAME}_files";

    WORKNAMEFILE=${WORKNAME}_files.autogen.iface;

    cat > ${WORKNAMEFILE} << EOF
#######################################
## <summary>
## 	Read the ${MODULE} variable data files
## </summary>
## <param name="domain">
## 	<summary>
##	Domain allowed access
##	</summary>
## </param>
#
interface(\`${MODULE}_read_var_files',\`
	gen_require(\`
		type ${TYPE};
	')

	files_search_var(\$1)
    	read_files_pattern(\$1, ${TYPE}, ${TYPE})" >> ${WORKNAMEFILE};
')
EOF
  fi
}

##
## genRWVar <module>
## 
## Generate the <module>_rw_var_* interfaces
genRWVar() {
  typeset MODULE=$1;
  typeset WORKNAME=${MODULE}/${MODULE}_rw_var
  typeset WORKNAMEFILE=${WORKNAME}.autogen.iface
  typeset TYPE=$(awk -F'=' "/${MODULE}.${UGENTYPE}.TYPE=/ {print \$2}" ${CONFFILE});
  typeset SCOPE=$(awk -F'=' "/${MODULE}.${UGENTYPE}.SCOPE=/ {print \$2}" ${CONFFILE});

  if [ -f ${WORKNAME}.part ];
  then
    echo "Skipping generation of ${WORKNAME}, .part exists.";
    return;
  fi

  echo "Generating ${WORKNAME}"

  cat > ${WORKNAMEFILE} << EOF
#######################################
## <summary>
## 	Read from and write to the ${MODULE} variable data (any type)
## </summary>
## <param name="domain">
## 	<summary>
##	Domain allowed access
##	</summary>
## </param>
#
interface(\`${MODULE}_rw_var',\`
	gen_require(\`
		type ${TYPE};
	')

	files_search_var(\$1)
EOF
  
  if [ "${SCOPE}" = "file" ];
  then
    echo "	rw_files_pattern(\$1, ${TYPE}, ${TYPE})" >> ${WORKNAMEFILE};
  elif [ "${SCOPE}" = "file dir" ];
  then
    echo "	rw_dirs_pattern(\$1, ${TYPE}, ${TYPE})" >> ${WORKNAMEFILE};
    echo "	rw_files_pattern(\$1, ${TYPE}, ${TYPE})" >> ${WORKNAMEFILE};
  fi
 
  echo "')" >> ${WORKNAMEFILE};

  ##
  ## files class
  ##
  echo "${SCOPE[@]}" | grep -E -q '(^| )file';
  if [ $? -eq 0 ];
  then

    echo "Generating ${WORKNAME}_files";

    WORKNAMEFILE=${WORKNAME}_files.autogen.iface;

    cat > ${WORKNAMEFILE} << EOF
#######################################
## <summary>
## 	Read from and write to the ${MODULE} variable data files
## </summary>
## <param name="domain">
## 	<summary>
##	Domain allowed access
##	</summary>
## </param>
#
interface(\`${MODULE}_rw_var_files',\`
	gen_require(\`
		type ${TYPE};
	')

	files_search_var(\$1)
    	rw_files_pattern(\$1, ${TYPE}, ${TYPE})
')
EOF
  fi
}

##
## genManageVar <module>
## 
## Generate the <module>_manage_var_* interfaces
genManageVar() {
  typeset MODULE=$1;
  typeset WORKNAME=${MODULE}/${MODULE}_manage_var
  typeset WORKNAMEFILE=${WORKNAME}.autogen.iface
  typeset TYPE=$(awk -F'=' "/${MODULE}.${UGENTYPE}.TYPE=/ {print \$2}" ${CONFFILE});
  typeset SCOPE=$(awk -F'=' "/${MODULE}.${UGENTYPE}.SCOPE=/ {print \$2}" ${CONFFILE});

  if [ -f ${WORKNAME}.part ];
  then
    echo "Skipping generation of ${WORKNAME}, .part exists.";
    return;
  fi

  echo "Generating ${WORKNAME}"

  cat > ${WORKNAMEFILE} << EOF
#######################################
## <summary>
## 	Manage the ${MODULE} variable data (any type)
## </summary>
## <param name="domain">
## 	<summary>
##	Domain allowed access
##	</summary>
## </param>
#
interface(\`${MODULE}_manage_var',\`
	gen_require(\`
		type ${TYPE};
	')

	files_search_var(\$1)
EOF
  
  if [ "${SCOPE}" = "file" ];
  then
    echo "	manage_files_pattern(\$1, ${TYPE}, ${TYPE})" >> ${WORKNAMEFILE};
  elif [ "${SCOPE}" = "file dir" ];
  then
    echo "	manage_dirs_pattern(\$1, ${TYPE}, ${TYPE})" >> ${WORKNAMEFILE};
    echo "	manage_files_pattern(\$1, ${TYPE}, ${TYPE})" >> ${WORKNAMEFILE};
  fi
 
  echo "')" >> ${WORKNAMEFILE};

  ##
  ## files class
  ##
  echo "${SCOPE[@]}" | grep -E -q '(^| )file';
  if [ $? -eq 0 ];
  then

    echo "Generating ${WORKNAME}_files";

    WORKNAMEFILE=${WORKNAME}_files.autogen.iface;

    cat > ${WORKNAMEFILE} << EOF
#######################################
## <summary>
## 	Manage the ${MODULE} variable data files
## </summary>
## <param name="domain">
## 	<summary>
##	Domain allowed access
##	</summary>
## </param>
#
interface(\`${MODULE}_manage_var_files',\`
	gen_require(\`
		type ${TYPE};
	')

	files_search_var(\$1)
    	manage_files_pattern(\$1, ${TYPE}, ${TYPE})" >> ${WORKNAMEFILE};
')
EOF
  fi
}

##
## genRWTmp <module>
## 
## Generate the <module>_rw_tmp_* interfaces
genRWTmp() {
  typeset MODULE=$1;
  typeset WORKNAME=${MODULE}/${MODULE}_rw_tmp
  typeset WORKNAMEFILE=${WORKNAME}.autogen.iface
  typeset TYPE=$(awk -F'=' "/${MODULE}.${UGENTYPE}.TYPE=/ {print \$2}" ${CONFFILE});
  typeset SCOPE=$(awk -F'=' "/${MODULE}.${UGENTYPE}.SCOPE=/ {print \$2}" ${CONFFILE});

  if [ -f ${WORKNAME}.part ];
  then
    echo "Skipping generation of ${WORKNAME}, .part exists.";
    return;
  fi

  echo "Generating ${WORKNAME}"

  cat > ${WORKNAMEFILE} << EOF
#######################################
## <summary>
## 	Read from and write to the ${MODULE} temporary data (any type)
## </summary>
## <param name="domain">
## 	<summary>
##	Domain allowed access
##	</summary>
## </param>
#
interface(\`${MODULE}_rw_tmp',\`
	gen_require(\`
		type ${TYPE};
	')

	files_search_tmp(\$1)
EOF
  
  if [ "${SCOPE}" = "file" ];
  then
    echo "	rw_files_pattern(\$1, ${TYPE}, ${TYPE})" >> ${WORKNAMEFILE};
  elif [ "${SCOPE}" = "file dir" ];
  then
    echo "	rw_dirs_pattern(\$1, ${TYPE}, ${TYPE})" >> ${WORKNAMEFILE};
    echo "	rw_files_pattern(\$1, ${TYPE}, ${TYPE})" >> ${WORKNAMEFILE};
  fi
 
  echo "')" >> ${WORKNAMEFILE};

  ##
  ## files class
  ##
  echo "${SCOPE[@]}" | grep -E -q '(^| )file';
  if [ $? -eq 0 ];
  then

    echo "Generating ${WORKNAME}_files";

    WORKNAMEFILE=${WORKNAME}_files.autogen.iface;

    cat > ${WORKNAMEFILE} << EOF
#######################################
## <summary>
## 	Read from and write to the ${MODULE} temporary files
## </summary>
## <param name="domain">
## 	<summary>
##	Domain allowed access
##	</summary>
## </param>
#
interface(\`${MODULE}_rw_tmp_files',\`
	gen_require(\`
		type ${TYPE};
	')

	files_search_tmp(\$1)
    	manage_files_pattern(\$1, ${TYPE}, ${TYPE})
')
EOF
  fi
}

##
## Part 1 - Main module METHODS
##
METHODS=$(awk -F'=' "/${MODULE}.METHODS=/ {print \$2}" ${CONFFILE});
for METHOD in ${METHODS};
do
  if [ "${METHOD}" = "domtrans" ];
  then
    genDomtrans ${MODULE};
  elif [ "${METHOD}" = "run" ];
  then
    genRun ${MODULE};
  elif [ "${METHOD}" = "role" ];
  then
    genRole ${MODULE};
  fi
done

## 
## Part 2 - Main module GENTYPES
##
GENTYPES=$(awk -F'=' "/${MODULE}.GENTYPES=/ {print \$2}" ${CONFFILE});
for GENTYPE in ${GENTYPES};
do
  typeset -u UGENTYPE=${GENTYPE}
  if [ "${GENTYPE}" = "config" ];
  then
    genReadConfig ${MODULE}
    genRWConfig ${MODULE}
    genManageConfig ${MODULE}
  elif [ "${GENTYPE}" = "log" ];
  then
    genReadLogs ${MODULE}
    genManageLogs ${MODULE}
  elif [ "${GENTYPE}" = "var" ];
  then
    genSearchVar ${MODULE}
    genReadVar ${MODULE}
    genRWVar ${MODULE}
    genManageVar ${MODULE}
  elif [ "${GENTYPE}" = "tmp" ];
  then
    genRWTmp ${MODULE} 
  fi
done

##
## Part 3 - Combine them all
##
if [ -f ${MODULE}.if ]; 
then
  echo "Skipping generation of ${MODULE}.if: file already exists.";
else
  SUMMARY=$(awk -F'=' '/DESCRIPTION=/ {print $2}' ${CONFFILE});
  echo "## <summary>" > ${MODULE}.if;
  echo "##	${SUMMARY}" >> ${MODULE}.if;
  echo "## </summary>" >> ${MODULE}.if;
  echo "" >> ${MODULE}.if;
  # Templates first
  for FILE in $(grep -H '^template' ${MODULE}/*.part ${MODULE}/*.autogen.iface 2>/dev/null | awk -F':' '{print $1}' | sort | uniq);
  do
    [ ! -f ${FILE} ] && continue;
    cat ${FILE} >> ${MODULE}.if;
  done
  # Next are the transformation types, we use typeattribute for that, but skip the templates...
  # FILE: look for typeattribute, then print "<attribute> <filename>", sort on attribute and then print only filenames
  for FILE in $(grep -H '[ 	]*typeattribute ' ${MODULE}/*.part ${MODULE}/*.autogen.iface 2>/dev/null | sed -e 's|\([^:]*\):.*typeattribute.* \([^ ]*\);|\2 \1|g' | sort | awk '{print $2}' | uniq);
  do
    [ ! -f ${FILE} ] && continue;
    grep -q '^template' ${FILE} && continue;
    cat ${FILE} >> ${MODULE}.if;
  done
  # Then we have the majority of things, being the access interfaces.
  ACCESSES="role domtrans run exec getattr search read append setattr write rw filetrans create rename delete manage relabelto relabelfrom relabel"
  SPECIFIERS="__NONE__ generic all"
  MODIFIERS="__NONE__ dontaudit"

  # First gather list of types
  TYPES=$(grep '^[ 	]*\(type\|attribute\) ' ${MODULE}/*.part ${MODULE}/*.autogen.iface 2>/dev/null | awk '{print $3}' | sed -e 's|;||g' | sort | uniq);
  for TYPE in ${TYPES};
  do
    SHORTTYPE=$(echo ${TYPE} | sed -e "s|${MODULE}_||g" -e "s|_t||g" -e "s|_type||g");
    for ACCESS in ${ACCESSES};
    do
      for SPECIFIER in ${SPECIFIERS};
      do
        if [ "${SPECIFIER}" = "__NONE__" ];
	then
	  SPECIFIER="";
	else
	  SPECIFIER="${SPECIFIER}_";
	fi
        for MODIFIER in ${MODIFIERS};
	do
	  if [ "${MODIFIER}" = "__NONE__" ];
	  then
	    MODIFIER=""
	  else
	    MODIFIER="${MODIFIER}_"
	  fi
          FILE=$(ls ${MODULE}/${MODULE}*${MODIFIER}${ACCESS}_${SPECIFIER}${SHORTTYPE}*.part \
	            ${MODULE}/${MODULE}*${MODIFIER}${ACCESS}_${SPECIFIER}${SHORTTYPE}*.autogen.iface \
		    ${MODULE}/${MODULE}_${SPECIFIER}${SHORTTYPE}_${ACCESS}*.part \
		    ${MODULE}/${MODULE}_${SPECIFIER}${SHORTTYPE}_${ACCESS}*.autogen.iface 2>/dev/null);
          [ "${FILE}" = "" ] && continue;
          if [ ! -f "${FILE}" ];
	  then
	    echo "Couldn't properly address ${MODIFIER}${SPECIFIER}${ACCESS}_*${SHORTTYPE}.";
	    echo " -> returned ${FILE}";
	    continue;
	  fi
	  IFNAME=$(grep '^\(interface\|template\)' ${FILE} | sed -e 's|[^`]*`||' | awk -F"'" '{print $1}');
	  grep -q "^interface(\`${IFNAME}'" ${MODULE}.if && continue;
	  grep -q "^template(\`${IFNAME}'" ${MODULE}.if && continue;
          cat ${FILE} >> ${MODULE}.if;
	done
      done
    done
  done
  # Admin interfaces
  for FILE in $(ls ${MODULE}/*_admin_*.part ${MODULE}/*_admin_*.autogen.iface 2>/dev/null | sort);
  do
    [ ! -f "${FILE}" ] && continue;
    IFNAME=$(grep '^\(interface\|template\)' ${FILE} | sed -e 's|[^`]*`||' | awk -F"'" '{print $1}');
    grep -q "^interface(\`${IFNAME}'" ${MODULE}.if && continue;
    grep -q "^template(\`${IFNAME}'" ${MODULE}.if && continue;
    cat ${FILE} >> ${MODULE}.if;
  done
  for FILE in $(ls ${MODULE}/*_admin.part ${MODULE}/*_admin.autogen.iface 2>/dev/null | sort);
  do
    [ ! -f "${FILE}" ] && continue;
    IFNAME=$(grep '^\(interface\|template\)' ${FILE} | sed -e 's|[^`]*`||' | awk -F"'" '{print $1}');
    grep -q "^interface(\`${IFNAME}'" ${MODULE}.if && continue;
    grep -q "^template(\`${IFNAME}'" ${MODULE}.if && continue;
    cat ${FILE} >> ${MODULE}.if;
  done

  # Final validation
  NUMFILES=$(ls ${MODULE}/*.part ${MODULE}/*.autogen.if 2>/dev/null | wc -l);
  NUMIF=$(grep -c '^\(template\|interface\)' ${MODULE}.if);
  if [ ${NUMFILES} -ne ${NUMIF} ];
  then
    echo "Discrepancy found in number of generated interfaces:";
    echo "  ${NUMFILES} interfaces are in the ${MODULE} directory, but";
    echo "  ${NUMIF} interfaces are finally in the ${MODULE}.if file.";
  fi
fi
