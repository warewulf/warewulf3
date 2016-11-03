#!/bin/bash
#
#########################################################
# This file created by Tim Copeland at
# Criterion Digital Copyright (c)
# with the hopes others will find this usefull
# and to help improve the project in general
#
# There is no warranty of any kind implied or otherwise
#########################################################


	# do basic complience tests
#___________________________________________ 
# this script must be run as root
INSTALATION_USER=$( /usr/bin/whoami )

if [[ "${INSTALATION_USER}" != "root" ]]
then
	echo
	echo
	echo "This script MUST be run as root"
	echo
	echo

	exit 1
fi

CHROOT=$(which chroot)

if [[ -z "${CHROOT}" ]]
then
   echo "Could not find the program 'chroot'"
   exit 1
fi

CONFPATH="/etc/warewulf /usr/etc/warewulf /usr/local/etc/warewulf"

WWVNFS=$(which wwvnfs)


	# setup our environment
#___________________________________________ 

MYNAME="Mint-Ubuntu-Debian chroot Package Manager"
VERSION="0.3.0"
REVISIONDATE="02-10-2012"
URL="http://warewulf.lbl.gov/trac"

DIRNAME=$(dirname $0)

ROOTEDSCRIPT=""
OPTIONSFILE=""
DONESHELL=""
MOREPACKS=""
OLDCONFIG=""
INSTALLS=""
VNFSROOT=""
CAPSULE=""
REMOVES=""
HYBRID=""
SAYYES=""

	# english message manager
#___________________________________________ 

warn_msg () {
	case "${1}" in

		abort)
			echo
			echo "Aborted .. fix errors and run this script again"
			echo
			;;

		duplicate)
			echo
			echo "########"
			echo "Warning: A ${CAPSULE}.conf file already exists"
			echo "If you choose to replace, it will be renamed to ${CAPSULE}.conf.BACK,"
			echo "and will replace any previous ${CAPSULE}.conf.BACK that may exist."
			echo
			echo "yes = Backup the existing ${CAPSULE}.conf, configure any excludes and/or"
			echo "      hybrid filesystems. Then replace it with the new values."
			echo
			echo " no = Do not replace, and use the existing ${CAPSULE}.conf file"
			echo "      Skip all exclude and hybrid configurations."
			echo
			;;

		excludes)
			echo
			echo "==============================================================================="
			echo "To help keep the imported vnfs small, it is highly recommended to exclude the"
			echo "package archives from when this vnfs was created. Along with any additional"
			echo "exclusions that may be included in config files. If hydridized, they will be"
			echo "available read only accessed in the chroot. Would you like to exclude these"
			echo "from the capsule?"
			echo
			echo "/var/cache/apt"
			echo "etc........"
			echo
			;;

		failedpath)
			echo
			echo "Unable to locate path to warewulf config files in any of the following paths"
			echo
			echo "${CONFPATH}"
			;;

		finalize)
			echo
			echo "============================================================================"
			echo "All tasks appear to have successfully completed. Exiting the chroot"
			echo "============================================================================"
			;;

		hybridprompt)
			echo
			echo "Do you want to hybridize this vnfs..?"
			;;

		import)
			echo
			echo "======================================================"
			echo "${CAPSULE} can now be imported into Warewulf"
			echo "This can take a while"
			echo
			echo "Compress and Import ..?"
			;;

		incomplete)
			echo
			echo "Incomplete Options"
			echo
			;;

		morepacks)
			echo
			echo "============================================================================"
			echo "All operations have been completed"
			echo "You had requested additional command line support"
			echo "Dropping into a shell for you to work in"
			echo
			;;

		nodir)
			echo
			echo "unable to locate chroot directory ${VNFSROOT}"
			echo
			;;

		nofile)
			echo
			echo "unable to locate options file ${OPTIONSFILE}"
			echo
			;;

		nomount)
			echo
			echo "unable to mount ${VNFSROOT}/proc"
			echo
			;;

		noscript)
			echo "============================================================================"
			echo '	ERROR: Failed to run scriptlet. Clues may be found in ^ previous error ^ .. '
			echo "	We may have been unable to locate or execute the packmgr-mud-scriptlet.sh that"
			echo "	should be in our chroot environment. Either way dropping into a shell"
			echo
			;;

		shell)
			echo "NEW SHELL"
			echo "============================================================================"
			echo "		This shell is from within the CHROOT environment"
			echo "				${VNFSROOT}"
			echo '		After finished with command line options, type the word "exit"'
			echo "		to exit command shell and continue with packmgr-mud automation."
			echo
			;;

		shellopt)
			echo
			echo "======================================================="
			echo "Leaving command shell."
			echo "  yes ) If succesfully completed your"
			echo "        tasks and would like to continue."
			echo
			echo "   no ) Exit without further actions."
			echo "        leaving chroot in its current state"
			echo
			;;

		promptuser)
			echo
			echo "Should we continue..?"
			;;

	esac
}


	# the command line options passed in
#___________________________________________

arg_set () {
	case "${1}" in

		-c|--capsule)
			CAPSULE="${2}"
			;;

		--create-template)
			echo
			create_template ;
			echo "example-options.template created"
			exit 0
			;;

		-f|--file)
			OPTIONSFILE="${2}"
			;;

		-h|--help)
			echo
			print_help ;
			echo
			print_full_help ;
			exit 0
			;;

		-i|--install)
			shift
			while [[ ${1} ]] 
			do
				INSTALLS="${INSTALLS} ${1}"
				shift
			done
			;;

		-m|--more-packages)
			MOREPACKS="true"
			;;

		-o|--optionfile-help)
			echo
			print_options_help ;
			exit 0
			;;

		-p|--path)
			VNFSROOT="${2}"
			;;

		-r|--remove)
			shift
			while [[ ${1} ]] 
			do
				REMOVES="${REMOVES} ${1}"
				shift
			done
			;;

		-v|--version)
			echo
			print_help ;
			;;

		-y)
			SAYYES="--assume-yes"
			;;

		*)
			echo
			echo "***	---	***	---	***"
			echo 	"Error: ${1}is an invalid option."
			echo "***	---	***	---	***"
			print_help ;
			exit 1
			;;

	esac
}


###############################################################
###############################################################

abort_install () {
	warn_msg abort ;
	clean_up ;
	exit 1
}


chroot_script () {
	# create the script to run inside our chroot environment
	# script will do remove/install work for packages then be
	# deleted upon completion after returning back to here

	ROOTEDSCRIPT="${VNFSROOT}/packmgr-mud-scriptlet.sh"

		# export our script to our chroot environment
	#___________________________________________________________

	echo '#!/bin/bash' > ${ROOTEDSCRIPT} ;
	echo '#' >> ${ROOTEDSCRIPT} ;
	echo '# this script was auto-generated by the packmgr-mud.sh' >> ${ROOTEDSCRIPT} ;
	echo '# it should have deleted imediately after its use.' >> ${ROOTEDSCRIPT} ;
	echo '# the fact you are reading this means that it failed to' >> ${ROOTEDSCRIPT} ;
	echo '# clean up after itself, so you should just delete this file.' >> ${ROOTEDSCRIPT} ;
	echo '#' >> ${ROOTEDSCRIPT} ;
	echo "INSTALLS=\"${INSTALLS}\"" >> ${ROOTEDSCRIPT} ;
	echo "REMOVES=\"${REMOVES}\"" >> ${ROOTEDSCRIPT} ;
	echo "SAYYES=\"${SAYYES}\"" >> ${ROOTEDSCRIPT} ;
	echo "INSTALL=\"install\"" >> ${ROOTEDSCRIPT} ;
	###===###===###===###===###===###===###===###===###===###===
cat <<'EOF' >>${ROOTEDSCRIPT}
do_scriptlet () {
	if [[ -n ${REMOVES} ]]
	then
		echo
		echo "removing requested packages"
		echo
		if ! apt-get ${SAYYES} remove ${REMOVES}
		then
			echo
			echo "failed to remove packages. Dropping into shell"
			echo
			exit 1
		fi
	fi
	if [[ -n ${INSTALLS} ]]
	then
		echo
		echo "	running apt-get update"
		echo
		if ! apt-get ${SAYYES} update
		then
			echo
			echo "failed to update package lists. Dropping into shell"
			echo
			exit 1
		fi
		echo
		echo "	installing requested packages"
		echo
		if ! apt-get ${SAYYES} ${INSTALL} ${INSTALLS}
		then
			echo
			echo "failed to install requested packages. Dropping into shell"
			echo
			exit 1
		fi
	fi
}
# run scriptlet loop
do_scriptlet ;
exit 0
EOF
	###===###===###===###===###===###===###===###===###===###===
	# now make it executable
	chmod +x ${ROOTEDSCRIPT} ;
}


clean_up () {

	rm -f ${ROOTEDSCRIPT} ;
	umount ${VNFSROOT}/proc 2>/dev/null

	if grep -q "${VNFSROOT} " /proc/mounts; then
	   echo "ERROR: there are mounted file systems in ${VNFSROOT}"
	   exit 1
	fi
}


close_shell () {

	warn_msg shellopt ;
	warn_msg promptuser ;

	if user_decide
	then
		DONESHELL="true"
	else
		abort_install ;
	fi
}


conf_check () {

	local temp=""

	# check for default path to vnfs.conf and for existing custom.conf file
	for i in ${CONFPATH}
	do
		if [[ -e ${i}/vnfs.conf ]]
		then
			temp=${i}
			break ;
		fi
	done

	if [[ -n ${temp} ]]
	then
		CONFPATH="${temp}/vnfs"
	else
		warn_msg failedpath ;
		abort_install ;
	fi				

	if [[ ! -d ${CONFPATH} ]]
	then
		mkdir -p ${CONFPATH} ;
	fi

	# now check for any existing custom vnfs.conf files and handle them
	if [[ -e ${CONFPATH}/${CAPSULE}.conf ]]
	then
		warn_msg duplicate ;

		if user_decide
		then
			# create new file
			mv -f ${CONFPATH}/${CAPSULE}.conf ${CONFPATH}/${CAPSULE}.conf.BACK
			> ${CONFPATH}/${CAPSULE}.conf ;
		else
			# use existing file
			OLDCONFIG="true"
		fi
	fi
}


create_template () {
cat <<EOF >example-options.template
# This file is an example file created
# by packmgr-mud.sh. The space deliniated
# lists should contain packages to be removed
# or installed into the specified vnfs capsule.
#
# sudo packmgr-mud.sh --help
#
# Lines starting with # are comments
#_______________________________________________

# REMOVE="package1 package-2 package_3"

# INSTALL="package1 package-2 package_3"

# A list of files and/or directories to exclude
# from being imported into Warewulf when using
# the import option.

# EXCLUSIONS="/path_to/file /path_to/directory"


EOF
}


do_shell () {
	warn_msg shell ;
	${CHROOT} ${VNFSROOT} ;
	close_shell ;
}


excludes () {

	warn_msg excludes ;

	if user_decide
	then
		# add to vnfs conf file
		echo "excludes += /var/cache/apt" >> ${CONFPATH}/${CAPSULE}.conf ;

		for n in ${EXCLUSIONS}
		do
			echo "excludes += ${n}" >> ${CONFPATH}/${CAPSULE}.conf ;
		done
	fi
}


hybridize () {

	# promp about hybrid
	warn_msg hybridprompt ;

	if user_decide
	then
		# add to vnfs conf file
		echo "hybrid path = /mnt/${CAPSULE}" >> ${CONFPATH}/${CAPSULE}.conf ;
	fi
}


print_help () {
cat <<EOF
		__________________________________________________

			$MYNAME : $VERSION
			Website : $URL			

			To view the help documentation type:

				sudo packmgr-mud.sh --help

				sudo packmgr-mud.sh --optionfile-help

    =============================================================================
EOF
}


print_options_help () {
cat <<EOF

	The option file is used to pass in multiple packages for removal and/or installation.
	It's recommended to name this file to correspond with the name of the vnfs it is related
	to. This will allow you to create templates for specific vnfs replication.

	Each option can contain a space delinitated list of package names to process. These packages
	will be in addition to any packages that were passed in with the command line. Package removal
	precedes package installation.

	REMOVE="package1 package-2 package_3"

	INSTALL="package1 package-2 package_3"

	EXCLUSIONS="/path_to/file /path_to/directory"
	___________________________________________________________

	The following command will create an example template file
	in the same directory as this script and will be named
			example-options.template

		sudo packmgr-mud.sh --create-template	

	___________________________________________________________

EOF
}


# Prints to screen complete help
print_full_help () {
cat <<EOF

	This is designed to simplify adding and removing packages inside chroot, and can automatically import
	the capsules into Warewulf when done. A lists of package requests can be passed in as arguments. An
	additional options file with a list of packages can be used, or simply use the --more-packages option
	to install additional packages from the command line before finalizing. When using "--capsule" option,
    the vnfs will be compressed and imported into warewulf. If the "--capsule" is not used, the vnfs will
	not be imported.

	TROUBLESHOOTING:

		When using both the install and remove options, all package removal occurs before installing packages.

	Examples:

		Install a package into the chroot found at "/var/chroots/debian-6.0.i386"

			sudo packmgr-mud.sh -p /var/chroots/debian-6.0.i386 -i <package>

		Install a package into the chroot found at "/var/chroots/debian-6.0.i386"
		then import into warewulf over writing the vnfs of the same name that may already exist.

			sudo packmgr-mud.sh -p /var/chroots/debian-6.0.i386 -c debian-6.0.i386 -i <package1>

		Install and remove various packages into the chroot found at "/var/chroots/debian-6.0.i386"
		then import into warewulf as new vnfs. Not over writing the previous "debian-6.0.i386" vnfs that may already exist.
		note - Capsule name can be any thing.

			sudo packmgr-mud.sh -p /var/chroots/debian-6.0.i386 -c debian-6.0.i386-2 -i <package1> <package2> -r <package3>

		Install a package into the chroot found at "/var/chroots/debian-6.0.i386" then be dropped into a shell
		for any additional work that may need to be done inside the chroot before exiting and over writing existing vnfs.

			sudo packmgr-mud.sh -p /var/chroots/debian-6.0.i386 -c debian-6.0.i386 -i <package1> -m


		Remove a package and install packages found in an options file into the chroot found at "/var/chroots/debian-6.0.i386"
		Then dropped into a shell for any additional work that may need to be done inside the chroot before exiting.

			sudo packmgr-mud.sh -p /var/chroots/debian-6.0.i386 -r <package> -f /path/to/file -m

	___________________________________________________________________________________________
	___________________________________________________________________________________________

        -c|--capsule)             The vnfs name this capsule will have when imported into Warewulf.
                                  This name can be unique or will prompt if vnfs exists of the same name 
                                  The vnfs capsule will automatically be imported as this name,
                                  after all other operations have been completed. Nothing will
                                  be imported, if this option is not used. Only package management
                                  will occur.

        --create-template)        This will create an example options file in the same directory as
                                  this script. 

        -f|--file)                The full path to the options file containing package name to be
                                  removed/installed. This is optional, but can be usefull for managing
                                  long lists of packages or for future vnfs creation without the need
                                  to retype the desired packages.

        -h|--help)                Displays this help info

        -i|--install)             Space separated list of all packages to install. These will be in addition
                                  to any packages found in the optional options file. All package installation
                                  will occure after all requested package removal.

        -m|--more-packages)       This will drop you into a shell inside the chrooted vnfs to allow manual
                                  command line management before finalizing.

        -o|--optionfile-help)     Displays the detailed help pertaining to the option file format

        -p|--path)                Path to the chroot directory

        -r|--remove)              Space separated list of all package to remove. These will be in addition
                                  to any packages found in the optional options file. All package removal
                                  will occure before any requested package are installs.

        -v  --version             Display basic information with version number

        -y|--assume-yes)          Automatic yes to "apt-get" prompts. Assume "yes" as answer to all prompts
                                  and run non-interactively.


	___________________________________________________________________________________________
EOF
}


user_decide () {

	local answer=""

	read -p "(yes/no): " answer

	if [[ "${answer}" == "YES" ]] || [[ "${answer}" == "yes" ]]
	then
		return 0 ;

	elif [[ "${answer}" == "NO" ]] || [[ "${answer}" == "no" ]]
	then
		return 1 ;

	else
		echo "Invalid Option"
		user_decide ;
	fi
}


wwimport () {

	# check if we should import this into WW
	warn_msg import ;

	if user_decide
	then
		conf_check ;

		if [[ -z ${OLDCONFIG} ]]
		then
			excludes ;
			hybridize ;
		fi

		${WWVNFS} --chroot=${VNFSROOT} ${CAPSULE}
	fi
}


##========================================================================
##			--== * MAIN * ==--				##
##========================================================================

do_main () {
	local this_cmd=""
	local this_arg=""

	if [[ ! ${1} ]] 
	then
		print_help ;
		exit 1
	fi

	while [[ ${1} ]] 
	do
		this_cmd=${1}
		this_arg=""
		shift

		# make sure the next element has a value
		if [[ -n ${1} ]] 
		then
			# then if first char of ${1}is not "-"
			# then it is our arg and not the next
			# command so assign it to this_arg
			while [[ -n ${1} ]] && [[ ! ${1} =~ ^\- ]] 
			do
				this_arg="${this_arg} ${1}"
				shift
			done
		fi

		arg_set ${this_cmd} ${this_arg} ;
	done

		# make sure we have required options
	#______________________________________________

	if [[ -z ${VNFSROOT} ]]
	then
		print_help ;
		warn_msg incomplete ;
		warn_msg abort ;
		exit 1
	fi

	if [[ -n ${OPTIONSFILE} ]]
	then
		if [[ -e ${OPTIONSFILE} ]]
		then
			source ${OPTIONSFILE} ;

			REMOVES="${REMOVES} ${REMOVE}"
			INSTALLS="${INSTALLS} ${INSTALL}"
		else
			print_help ;
			warn_msg nofile	;
			exit 1		
		fi
	fi

	if [[ -z ${INSTALLS} ]] && [[ -z ${REMOVES} ]] && [[ -z ${MOREPACKS} ]]
	then
		print_help ;
		warn_msg incomplete ;
		warn_msg abort ;
		exit 1
	fi

		# now that we have all command line options
	#___________________________________________

	# check to see if the chroot directory exists
	if [[ -d ${VNFSROOT} ]]
	then
		# prepare to chroot
		if mount -t proc none ${VNFSROOT}/proc
		then
			# create our chrooted script
			chroot_script ;
		else
			warn_msg nomount ;
			warn_msg abort ;
			exit 1
		fi
	else
		warn_msg nodir ;
		warn_msg abort ;
		exit 1
	fi

		# now that we are in chroot do work
	#___________________________________________

	# make it so
	if ! ${CHROOT} ${VNFSROOT} ./packmgr-mud-scriptlet.sh
	then
		warn_msg noscript ;
		do_shell ;
	fi

	if [[ -z ${DONESHELL} ]] && [[ "${MOREPACKS}" == "true" ]]
	then
		warn_msg morepacks ;
		do_shell ;
	fi

	# unmount the vnfs capsule
	clean_up ;

			# now that all done install into WW
		#___________________________________________

	if [[ -n ${CAPSULE} ]]
	then
		wwimport ;
	fi

	# if we got this far all must have finished correctly
	warn_msg finalize ;
}



##---------

do_main $@ ;

##---------

exit 0
