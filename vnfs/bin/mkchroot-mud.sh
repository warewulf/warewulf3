#!/bin/bash
#
#########################################################
# This file created by Tim Copeland at
# Criterion Digital Copyright (c)
# with the hopes others will find this usefull
# and to help improve the project in general
#
# some code snipits contained within came by referencing
# and copying the works of Greg M. Kurtzer
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
WWBOOT=$(which wwbootstrap)


	# setup our environment
#___________________________________________ 

MYNAME="Mint-Ubuntu-Debian mkchroot vnfs generator"
VERSION="0.7.1"
REVISIONDATE="02-15-2012"
URL="http://warewulf.lbl.gov/trac"

HOSTMATCH=$(uname -m)
DIRNAME=$(dirname $0)

##############################
# DISTRO BASE PACKS AND REPOS

DEBLINIMAGE="linux-image"
DEBIANCOMOPONENTS="main,contrib,non-free"
DEBIANINCLUDES="openssh-server,openssh-client,isc-dhcp-client,pciutils,strace,nfs-common,nfs-kernel-server,ethtool,iproute,iputils-ping,iputils-arping,net-tools,firmware-bnx2,ifupdown,rsync"

UBUNTUCOMOPONENTS="main,restricted,universe"
UBUNTUINCLUDES="ssh,isc-dhcp-client,pciutils,strace,nfs-common,nfs-kernel-server,ethtool,iproute,iputils-ping,iputils-arping,net-tools,linux-image-server,rsync"

FULLINSTALL="libpcre3,less,libpopt0,tcpd,update-inetd,libpam-cracklib,iputils-tracepath,rsh-client,wamerican,vim-tiny,cron,gawk,mingetty,psmisc,rdate,rsh-redone-server,rsyslog,dracut,ntp"

VARIANT="minbase"
VALIDDEBARCH='armel kfreebsd-i386 kfreebsd-amd64 ia64 mips mipsel powerpc sparc'

##############################

BOOTSTRAPINCLUDES=""
KERNELVERSION=""
QEMUFILENAME=""
NEWHOSTNAME=""
OPTIONSFILE=""
COMPONENTS=""
EXCLUSIONS=""
RELEASEVER=""
OLDCONFIG=""
CODENAME=""
FINDQEMU=""
NEWREPOS=""
VNFSROOT=""
FOREIGN=""
CHOICE=""
DISTRO=""
EXTRA=""
REPOS=""
ARCH=""


	# english message manager
#___________________________________________ 

warn_msg () {
	case "${1}" in

		abort)
			echo
			echo "vnfs creation has been aborted .. fix errors and run this script again"
			echo
			;;

		address)
			echo
			echo "What is the server IP address the nodes will look to for this hybrid file systems..?"
			echo
			;;

		bootstrap)
			echo
			echo "============================================================================"
			echo "A bootstrap image can be automatically generated from this chroot."
			echo "Generate bootstrap and imported into Warewulf at this time?"
			echo
			;;

		chosen)
			echo
			echo "You have entered : ${CHOICE}"
			echo "Is this correct..?"
			;;

		completed)
			echo
			echo "============================================================================"
			echo "The requested chroot environment has been created at"
			echo
			echo "${VNFSROOT}/${NAME}"
			;;

		duplicate)
			echo
			echo "########"
			echo "Warning: A ${NAME}.conf file already exists"
			echo "If you choose to replace, it will be renamed to ${NAME}.conf.BACK,"
			echo "and will replace any previous ${NAME}.conf.BACK that may exist."
			echo
			echo "yes = Backup the existing ${NAME}.conf, configure any excludes and/or"
			echo "      hybrid filesystems. Then replace it with the new values."
			echo
			echo " no = Do not replace, and use the existing ${NAME}.conf file"
			echo "      Skip all exclude, hybrid, fstab, and export configurations."
			echo
			;;

		excludes)
			echo
			echo "==============================================================================="
			echo "To help keep the imported vnfs small, it is highly recommended to exclude the"
			echo "package archives, from when this vnfs was created. Along with any additional"
			echo "exclusions that may be included in config files. If hydridized, they will be"
			echo "available read only accessed in the chroot. Would you like to exclude these"
			echo "from the capsule?"
			echo
			echo "/var/cache/apt"
			echo "etc........"
			echo
			;;

		exports)
			echo
			echo "============================================================================"
			echo "This hybrid share needs to be added to /etc/exports on the head server."
			echo "Exporting will make the files, in the local chroot, available to the networked nodes"
			echo "would you like to add this hybrid path to this servers /etc/exports..?"
			echo
			;;

		extras)
			echo
			echo "=============================================================================="
			echo "Extra configurations for things like excludes and hybridizing can now be done." 
			echo "Continue and assist with extra configurations?"
			echo
			;;

		failedpath)
			echo
			echo "Unable to locate path to warewulf config files in any of the following paths"
			echo
			echo "${CONFPATH}"
			;;

		finished)
			echo
			echo "============================================================================"
			echo "Be sure to check the output in case of possible errors"
			echo "otherwise all operations appear to have completed successfully"
			echo "============================================================================"
			;;

		foreign)
			echo
			echo "debootstrap's --foreign flag is now set making debootstrap a 2 stage install"
			echo
			;;

		fstab)
			echo
			echo "============================================================================"
			echo "The nodes /etc/fstab file needs to have the hybrid file system path set"
			echo "so the remote files will be available when they boot. Would you like to"
			echo "add this entry to this vnfs capsule's fstab at this time..?"
			echo
			;;			

		hw-missmatch)
			echo "Failed to determine local environment"
			echo "Make sure the requested architecture is correct"
			echo "or make sure uname is installed and in PATH"
			echo
			;;

		hybridprompt)
			echo
			echo "Do you want to hybridize this vnfs..?"
			;;

		import)
			echo
			echo "======================================================"
			echo "${NAME} can now be imported into Warewulf"
			echo "This can take a while"
			echo
			echo "Compress and Import ..?"
			;;

		incomplete)
			echo
			echo "Incomplete Options"
			echo
			;;

		install_qemu)
			echo 
			echo "Should We Auto-Install QEMU and Continue With vnfs Creation ? "
			;;

		missing_qemu)
			echo
			echo "The correct static qemu file required to finish stage 2 can not be found"
			echo "please install the correct ${FOREIGN}. If that is not the correct file"
			echo "name, and you know the correct qemu is installed, set the correct name"
			echo "in an options file and run this script again."
			;;

		need_qemu)
			echo
			echo "In order to create a vnfs for non-native architecture the correct version of static"
			echo 'QEMU, such as "qemu-user-static" need to be installed on this host machine'
			echo
			echo "This package can be automatically installed from your repository"
			echo
			;;

		network)
			echo
			echo "What network address will have access to this export..?"
			echo
			;;

		nofile)
			echo
			echo "unable to locate options file ${OPTIONSFILE}"
			echo
			;;

		noncomply)
			echo
			echo "Error: Failed Hardware Compliance"
			echo "You are trying to build a vnfs for an architecture that appears different from this machine"
			;;

		no_edit)
			echo "         ^^^     !..WARNING..!     ^^^"
			echo "There already appears to be an entry for this. We will assume"
			echo "the correct entry already exists. If the entry is incorrect,"
			echo "you will need to edit this file by hand."
			echo
			echo "This file will not be edited."
			echo
			;;

		noqemu_pack)
			echo
			echo 'Error: Failed to find the required package "qemu-user-static or qemu-kvm-extras-static"'
			echo "Install the correct static package of QEMU for your target architecture and run this again"
			echo
			;;

		qemu_mayfail)
			echo
			echo "You appear to be trying to create a 64 bit vnfs on a 32 bit OS."
			echo "Though this may be possible with QEMU, it is likely to fail."
			echo "It wont hurt any thing to try, but success is doubtful."
			echo
			;;

		stage2)
			echo " Stage 1 debootstrap"
			echo
			echo " Stage 2 debootstrap"
			echo
			;;

		subnet)
			echo
			echo "What is the subnet mask for this network..?"
			echo
			;;

		uncharted)
			echo
			echo "It apears the host machine's architecture or the architecture you are requesting to install"
			echo "has had little or no testing with this installer. We will try to meet this request, but if it"
			echo "fails, you can first try setting a custom package list in an options file. Look here for info."
			echo "	sudo mkchroot-mud.sh --optionfile-help"
			echo
			echo "If all else fails, you are welcome to edit the code to meet your needs. It should take very"
			echo "little work to make this compatible with all debian supported architectures"
			;;

		wrongarch)
			echo
			echo "The distro you have requested does not support ${ARCH} architecture"
			echo
			;;

	esac
}


	# the command line options passed in
#___________________________________________

arg_set () {
	case "${1}" in

	# distro info
	#__________________
		-M|--mint)
			ARCH="${2}"
			DISTRO="mint"
			COMPONENTS="${UBUNTUCOMOPONENTS}"
			REPOS='http://archive.ubuntu.com/ubuntu'
#			REPOS=' http://packages.linuxmint.com'
			;;

		-U|--ubuntu)
			ARCH="${2}"
			DISTRO="ubuntu"
			COMPONENTS="${UBUNTUCOMOPONENTS}"
			REPOS='http://archive.ubuntu.com/ubuntu'
			;;

		-D|--debian)
			ARCH="${2}"
			DISTRO="debian"
			COMPONENTS="${DEBIANCOMOPONENTS}"
			REPOS='http://ftp.us.debian.org/debian'
			;;

		-e|--extra)
			EXTRA="true"
			;;

		-f|--file)
			OPTIONSFILE="${2}"
			;;

		-n|--host-name)
			NEWHOSTNAME="${2}"
			;;

		-p|--path)
			VNFSROOT="${2}"
			;;

		-R|--repos)
			NEWREPOS="${2}"
			;;

		-c|--codename)
			CODENAME="${2}"
			;;

		-r|--release)
			RELEASEVER="${2}"
			;;

	# standard info
	#__________________
		--create-template)
			echo
			create_template ;
			echo "mkchroot-options.template created"
			exit 0
			;;

		-h|--help)
			echo
			print_help ;
			echo
			print_full_help ;
			exit 0
			;;

		-o|--optionfile-help)
			echo
			print_options_help ;
			exit 0
			;;

		-s|--show)
			echo
			print_package_info ;
			echo
			exit 0
			;;

		-v|--version)
			echo
			print_help ;
			;;

		*)
			echo
			echo "***	---	***	---	***"
			echo 	"Error: ${1} is an invalid option."
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


arch_request () {

	local temp=""

	if [[ ${ARCH} =~ ^(i386|i586|i686) ]]
	then
		ARCH="i386"
		PACKNAME="i386"
		QEMUARCH="i386"
		DEBLINIMAGE="${DEBLINIMAGE}-686"

	elif [[ ${ARCH} =~ ^(x86_64|amd64) ]]
	then
		ARCH="amd64"
		PACKNAME="amd64"
		QEMUARCH="x86_64"
		DEBLINIMAGE="${DEBLINIMAGE}-amd64"
	else
		if [[ "${DISTRO}" != "debian" ]]
		then
			warn_msg wrongarch ;
			exit 1
		else
			# should do some check to make sure is in
			# debian's list of valid arch's
			for i in ${VALIDDEBARCH}
			do
				if [[ "${i}" == "${ARCH}" ]]
				then
					temp="${i}"
				fi
			done

			if [[ -n ${temp} ]]
			then
				ARCH="${temp}"
				PACKNAME="${temp}"
				QEMUARCH="${temp}"
				warn_msg uncharted ;
			else
				warn_msg wrongarch ;
				exit 1
			fi				
		fi
	fi
}


clean_up () {

	umount ${VNFSROOT}/${NAME}/proc/fs/nfsd 2>/dev/null
	umount ${VNFSROOT}/${NAME}/proc 2>/dev/null

	if grep -q "${VNFSROOT} " /proc/mounts; then
	   echo "ERROR: there are mounted file systems in ${VNFSROOT}"
	   exit 1
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
	if [[ -e ${CONFPATH}/${NAME}.conf ]]
	then
		warn_msg duplicate ;

		if user_decide
		then
			# create new file
			mv -f ${CONFPATH}/${NAME}.conf ${CONFPATH}/${NAME}.conf.BACK
			> ${CONFPATH}/${NAME}.conf ;
		else
			# use existing file
			OLDCONFIG="true"
		fi
	fi
}


create_template () {
cat <<'EOF' >mkchroot-options.template
# This file is an example file created by mkchroot-mud.sh.
# There are 2 ways to include values with this file. You can either
# include additional packages to the default install, or you can
# override the defaults using one or both options.
#
# To see a list of all default values
#	sudo mkchroot-mud.sh --show
#
# Lines starting with # are comments
#_________________________________________________________________________
# This format will add these values to the defaults and should
# only be used for these variables.

#    COMPONENTS="${COMPONENTS},source1,source-2,source_3"
#    BOOTSTRAPINCLUDES="${BOOTSTRAPINCLUDES},package1 package-2 package_3"

#_________________________________________________________________________
# This format will override the defaults and only use these values
# Is usefull for when needing specific package versions such as kernel's
# or excluding files and/or directories from being imported into warewulf etc .. 

#    COMPONENTS="source1,source-2,source_3"
#    BOOTSTRAPINCLUDES="package1 package-2 package_3"
#    VARIANT="minbase"
#    NEWHOSTNAME="Deb-Nodes"
#    QEMUFILENAME="qemu-arm-static"
#    EXCLUSIONS="/path_to/file /path_to/directory"


EOF
}


cross_hardware () {

	FINDQEMU=$(ls /usr/bin/qemu*)

	if [[ -z ${FINDQEMU} ]]
	then
		warn_msg need_qemu ;

		#--------
		if [[ "${HOSTMATCH}" == "i386" ]] && [[ "${QEMUARCH}" == "x86_64" ]]
		then
			warn_msg qemu_mayfail ;
		fi

		warn_msg install_qemu ;

		if user_decide
		then
			if apt-cache search qemu-user-static
			then
				apt-get install binfmt-support qemu qemu-user-static ;

			elif apt-cache search qemu-kvm-extras-static
			then
				apt-get install binfmt-support qemu qemu-kvm-extras-static ;

			else
				warn_msg noqemu_pack ;
				exit 1
			fi

		else
			warn_msg abort ;
			exit 1
		fi
	fi
}


edit_fstab () {

	# prompt for add to fstab
	warn_msg fstab ;

	# Since fstab was just created this should never
	# hapen but we'll put the check here any ways
	if more "${VNFSROOT}/${NAME}/etc/fstab" | grep "${NAME}" > /dev/null
	then
		echo
		echo "============================================"
		echo "${VNFSROOT}/${NAME}/etc/fstab  --->  ${NAME}"
		warn_msg no_edit ;
		read -p "After reading message press [ENTER]"
	else
		if user_decide
		then
			# promp for address
			warn_msg address ;
			user_input ;

			# add to fstab file
			echo "" >> ${VNFSROOT}/${NAME}/etc/fstab ;
			echo "${CHOICE}:${VNFSROOT}/${NAME} /mnt/${NAME} nfs ro,rsize=8192" >> ${VNFSROOT}/${NAME}/etc/fstab ;
		fi
	fi
}


excludes () {

	warn_msg excludes ;

	if user_decide
	then
		# add to vnfs conf file
		echo "excludes += /var/cache/apt" >> ${CONFPATH}/${NAME}.conf ;

		for n in ${EXCLUSIONS}
		do
			echo "excludes += ${n}" >> ${CONFPATH}/${NAME}.conf ;
		done
	fi
}


exports () {

	local temp=""

	warn_msg exports ;

	if user_decide
	then

		if more "/etc/exports" | grep "${VNFSROOT}/${NAME}" > /dev/null
		then
			echo "============================================================"
			echo
			echo "/etc/exports ---> ${VNFSROOT}/${NAME}"
			warn_msg no_edit ;
			read -p "After reading message press [ENTER]"
		else
			warn_msg network ;
			user_input ;
			temp="${CHOICE}"

			warn_msg subnet ;
			user_input ;
			temp="${temp}/${CHOICE}"

			echo "${VNFSROOT}/${NAME} ${temp} (ro,root_squash)" >> /etc/exports ;
		fi
	fi
}


extras () {

	warn_msg extras ;

	if user_decide
	then
		conf_check ;

		if [[ -z ${OLDCONFIG} ]]
		then
			excludes ;
			hybridize ;
			edit_fstab ;
		fi
	fi
}


hybridize () {

	# promp about hybrid
	warn_msg hybridprompt ;

	if user_decide
	then
		# add to vnfs conf file
		echo "hybrid path = /mnt/${NAME}" >> ${CONFPATH}/${NAME}.conf ;
		exports ;

	fi
}


match_host_hw () {

	if [[ -n ${HOSTMATCH} ]]
	then
		if [[ ${HOSTMATCH} =~ ^(i386|i586|i686) ]]
		then
			HOSTMATCH="i386"
		fi

		if [[ "${HOSTMATCH}" != "${QEMUARCH}" ]]
		then
			cross_hardware ;
			FOREIGN="--foreign"
			warn_msg foreign ;
		fi
	else
		warn_msg hw-missmatch ;
		exit 1
	fi
}


print_help () {
cat <<EOF
		__________________________________________________

			$MYNAME : $VERSION
			Website : $URL			

			To view the help documentation type:

			sudo mkchroot-mud.sh --help

			sudo mkchroot-mud.sh --optionfile-help
    =============================================================================
EOF
}


# Prints to screen complete help
print_full_help () {
cat <<EOF

	This is designed to create vnfs frameworks for a wide range of distros and
	hardware. No matter what bash capable distro or hardware architecture of the
	host machine.

	FEATURES:

		cross debootstrap:
			Uses QEMU to build vnfs for non native architecture 
			ie. create a 32 bit vnfs on a 64 bit machine or any debian supported arch.
			note: Building a 64 bit vnfs on a 32 operating system is likely to fail.

		multiple .deb flavors:
			By default will allow the creation of any release of Debian or Ubuntu.
			Options exist to allow creation of most any version/architecture from
			most any distro/repository.

		warewulf import:
			Allows for automatically importing ( wwbootstrap  and/or wwvnfs ) the created
			vnfs into warewulf.


	Support is built in to allow for all debian supported architectures to
	be built on any machine. However, this is experimental and mostly untested.
	Individule experiences could vary greatly. See Experimental architectures below.

        Valid architectures are:
            x86_64 (defaults to amd64)
            amd64
            i386

        Experimental architectures are:
            armel
            kfreebsd-i386
            kfreebsd-amd64
            ia64 mips
            mipsel
            powerpc
            sparc

	To date these are the current releases.
	Any future releases not listed below should also be supported.

	RELEASE NUMBERS-CODE NAMES:

		Ubuntu: 10.04-lucid , 10.10-maverick , 11.04-natty , 11.10-oneiric , 12.04-precise

		Debian: 5.0-lenny , 6.0-squeeze , 7.0-wheezy , sid 

		Mint:   9-Isadora , 10-Julia , 11-Katya , 12-Lisa


	TROUBLESHOOTING:

          Building a 64 bit vnfs on a 32 operating system is likely to fail. Theoretically, QEMU should
          allow the creation of 64 bit vnfs on a 32 bit OS. This may or may not be possible with 64 bit
          kernel installed, and a CPU that supports virtualization, which must also be turned on in BIOS.
          
          After vnfs creation, it is easy to add additional packages in the chroot environment
          by using the included packmgr-mud.sh script.

          There are times when building a vnfs for a distro different from the host machine,
          the system will fail to find the correct debootsrap build file. Many times the files
          in question are simply just links to a standard file. For instance, when trying to build
          an Ubuntu vnfs on a native Debian system, you may encounter an error as such :
			  No such script: /usr/share/debootstrap/scripts/oneiric

          To remedy this, you can use option "QEMUFILENAME=" in an options file or simply create the
          required link. In this instance, the script to debootstrap an Ubuntu oneiric system is the
          same script used for the Debian gutsy release.
		     sudo ln -s -T /usr/share/debootstrap/scripts/gutsy /usr/share/debootstrap/scripts/oneiric

          Errors like the following are caused by matching distro to incorrect codenames.
          This error was created by setting the distro to Debian and trying to use an
          Ubuntu codename. Debian servers do not have Ubuntu repos.
		     Failed getting release file http://ftp.us.debian.org/debian/dists/oneiric/Release

          Ubuntu is at the core of Linux Mint. Even though the Mint option is available, the Ubuntu
          repositories will be used for debootstrap by default. The naming convention is all that is gained
          here. However, by using the --repos and --file options together will allow you to build most any
          disto/package combination you need.

          Since the repos are from Ubuntu, the correct code name must be used. Building a 32 bit vnfs for
          Mint12 would look like this.

	         sudo mkchroot-mud.sh -M i386 -c oneiric -r 12 -p /var/chroots

	Examples:
        To create a 32 bit Ubuntu vnfs from the standard repository:
			sudo mkchroot-mud.sh -U i386 -c oneiric -r 11.10 -p /var/chroots

        To create an amd compatibla 64 bit debian vnfs from the standard
        repository with a custom list of packages from an option file:
			sudo mkchroot-mud.sh -D x86_64 -c squeeze -r 6.0 -f mkchroot-options.template -p /var/chroots

	___________________________________________________________________________________________
	___________________________________________________________________________________________
	
        -M  --mint               Sets the distro to LinuxMint. Takes an architecture as an argument

        -U  --ubuntu             Sets the distro to Ubuntu. Takes an architecture as an argument

        -D  --debian             Sets the distro to Debian. Takes an architecture as an argument

        -R  --repos              (Optional) Change the default repository.
                                  The default repositories are:
                                     Mint/Ubuntu
                                         'http://archive.ubuntu.com/ubuntu'
                                     Debian
                                         'http://ftp.us.debian.org/debian'

        -c  --codename           Choose the code name designation for this distro.

            --create-template    This will create an example options file in the same directory as

        -e --extra               This will install the extra packages. The default install is Aprox: 200M. Installing
                                 the extra packages can be over 2.0G Use option --show to see package lists this script. 

        -f  --file               Path to a file for additional options like source and packages

        -h  --help               Display this help message

        -n --host-name           Change the host name of the nodes ( default is this machines host name )

        -o --optionfile-help     Display help about an the additional options file

        -p --path                Set the path to where this vnfs will be created

        -r  --release            Designated distro version number 

        -s  --show               Display all default sources and packages

        -v  --version            Display basic information with version number



EOF
}


print_options_help () {
cat <<EOF
	It's recommended to name this file to correspond with the name
	of the vnfs it is related to. The option file is used to pass
	in custom package lists along with setting various other values
	like debootstrap variants, node host names, etc..
	___________________________________________________________

	The following command will create an example template file
	in the same directory as this script. It will be named
	example-options.template

		sudo mkchroot-mud.sh --create-template	

	___________________________________________________________

EOF
}


print_package_info () {
cat <<EOF

VARIANT="minbase"
______________________________________________________________________
Minimal packages to be installed.

Ubuntu:
    COMPONENTS="main,restricted,universe"

    BOOTSTRAPINCLUDES="${UBUNTUINCLUDES}"


Debian:
    COMPONENTS="main,contrib,non-free"

    BOOTSTRAPINCLUDES="${DEBIANINCLUDES},linux-image-[ARCH]"

#	[ARCH] = depends on the architechture requested at build time
______________________________________________________________________

Additional packages for a full default install.
Using the --extra option will include these with install:

    ${FULLINSTALL}


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


user_input () {

	read -p ">>> $ " CHOICE

	warn_msg chosen ;

	if ! user_decide
	then
		echo "Try again"
		user_input ;
	fi
}


wwboot () {

	# check if we should import this into WW
	warn_msg bootstrap ;

	if user_decide
	then
		KERNELVERSION="$( ls ${VNFSROOT}/${NAME}/boot | grep 'vmlinuz-' )"
		${WWBOOT} --root ${VNFSROOT}/${NAME} ${KERNELVERSION/vmlinuz-/}
	fi
}


wwimport () {

	# check if we should import this into WW
	warn_msg import ;

	if user_decide
	then

		${WWVNFS} --chroot=${VNFSROOT}/${NAME}
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
			# then if first char of ${1} is not "-"
			# then it is our arg and not the next
			# command so assign it to this_arg
			if [[ ! ${1} =~ ^\- ]] 
			then
				this_arg="${1}"
				shift
			fi
		fi

		arg_set ${this_cmd} ${this_arg} ;
	done

	for i in "${DISTRO}" "${RELEASEVER}" "${ARCH}" "${CODENAME}" "${VNFSROOT}"
	do
		if [[ -z ${i} ]]
		then
			warn_msg incomplete ;
			print_help ;
			warn_msg abort ;
			exit 1
		fi
	done

	# this command line option overrides the default repostitories
	if [[ -n ${NEWREPOS} ]]
	then
		REPOS="${NEWREPOS}"
	fi


	# final compatability tests
  #___________________________________________________

	arch_request ;
	match_host_hw ;


	# establish the new system
  #___________________________________________________

	NAME="${DISTRO}-${RELEASEVER}.${ARCH}"

	echo "Building in: ${VNFSROOT}/${NAME}/"
	mkdir -p ${VNFSROOT}/${NAME}
	if [[ "${DISTRO}" == "debian" ]]
	then
		BOOTSTRAPINCLUDES="${DEBIANINCLUDES},${DEBLINIMAGE}"
	else
		BOOTSTRAPINCLUDES="${UBUNTUINCLUDES}"
	fi

	if [[ -n ${EXTRA} ]]
	then
		BOOTSTRAPINCLUDES="${BOOTSTRAPINCLUDES},${FULLINSTALL}"
	fi

	if [[ -n ${OPTIONSFILE} ]]
	then
		if [[ -e ${OPTIONSFILE} ]]
		then
			source ${OPTIONSFILE} ;
		else
			print_help ;
			warn_msg nofile	;
			exit 1		
		fi
	fi

	if [[ -n ${VARIANT} ]]
	then
		VARIANT="--variant=${VARIANT}"
	fi

	if [[ -n ${BOOTSTRAPINCLUDES} ]]
	then
		BOOTSTRAPINCLUDES="--include=${BOOTSTRAPINCLUDES}"
	fi

#################
#################
	debootstrap ${FOREIGN} --arch=${ARCH} --components=${COMPONENTS} ${VARIANT} \
				${BOOTSTRAPINCLUDES} ${CODENAME} ${VNFSROOT}/${NAME} ${REPOS} || abort_install;

	if [[ -n ${FOREIGN} ]]
	then
		if [[ -n ${QEMUFILENAME} ]]
		then
			FOREIGN="/usr/bin/${QEMUFILENAME}"
		else
			FOREIGN="/usr/bin/qemu-${QEMUARCH}-static"
		fi

		if [[ -e ${FOREIGN} ]]
		then
			# do second stage debootstrap install
			warn_msg stage2 ;
			cp ${FOREIGN} ${VNFSROOT}/${NAME}/usr/bin/  
			${CHROOT} ${VNFSROOT}/${NAME} /debootstrap/debootstrap --second-stage || abort_install;
		else
			warn_msg missing_qemu ;
			exit 1
		fi
	fi
#################
#################


	# START CONFIGURING THIS VNFS
  #___________________________________________________
	if [[ -n ${NEWHOSTNAME} ]]
	then
		echo "${NEWHOSTNAME}" > ${VNFSROOT}/${NAME}/etc/hostname
	fi

	echo
	echo "Generating basic default fstab"

cat <<EOF >${VNFSROOT}/${NAME}/etc/fstab
	#GENERATED_ENTRIES
	devpts	/dev/pts	devpts	gid=5,mode=620	0 0
	tmpfs	/dev/shm	tmpfs	defaults		0 0
	sysfs	/sys		sysfs	defaults		0 0
	proc	/proc		proc	defaults		0 0
EOF

cat <<EOF > ${VNFSROOT}/${NAME}/etc/network/interfaces
	auto lo			
	iface lo inet loopback
	auto eth0
	iface eth0 inet dhcp
EOF

	# clear out any rules that may have been created by the host system
	echo "# Automatically generated by udev" > ${VNFSROOT}/${NAME}/etc/udev/rules.d/70-persistent-net.rules
	echo " " > ${VNFSROOT}/${NAME}/etc/udev/rules.d/70-persistent-net.rules

	cp /etc/securetty	   ${VNFSROOT}/${NAME}/etc/securetty
	echo "ttyS0"		>> ${VNFSROOT}/${NAME}/etc/securetty
	echo "ttyS1"		>> ${VNFSROOT}/${NAME}/etc/securetty
	echo "127.0.0.1		localhost localhost.localdomain" \
				> ${VNFSROOT}/${NAME}/etc/hosts
	echo "s0:2345:respawn:/sbin/agetty -L 115200 ttyS0 vt100" \
				>> ${VNFSROOT}/${NAME}/etc/inittab
	echo "s1:2345:respawn:/sbin/agetty -L 115200 ttyS1 vt100" \
				>> ${VNFSROOT}/${NAME}/etc/inittab

	if [[ -x "${VNFSROOT}/${NAME}/usr/sbin/pwconv" ]]
	then
	   ${CHROOT} ${VNFSROOT}/${NAME} /usr/sbin/pwconv >/dev/null 2>&1||:
	fi
	if [[ -x "${VNFSROOT}/${NAME}/usr/sbin/update-rc.d" ]]
	then
	   ${CHROOT} ${VNFSROOT}/${NAME} /usr/sbin/update-rc.d xinetd defaults >/dev/null 2>&1
	fi

	sed -i -e 's/# End of file//' ${VNFSROOT}/${NAME}/etc/security/limits.conf
	if ! grep -q "^* soft memlock " ${VNFSROOT}/${NAME}/etc/security/limits.conf
	then
	   echo "* soft memlock 8388608 # 8 GB" >> ${VNFSROOT}/${NAME}/etc/security/limits.conf
	fi
	if ! grep -q "^* hard memlock " ${VNFSROOT}/${NAME}/etc/security/limits.conf
	then
	   echo "* hard memlock 8388608 # 8 GB" >> ${VNFSROOT}/${NAME}/etc/security/limits.conf
	fi
	echo >> ${VNFSROOT}/${NAME}/etc/security/limits.conf
	echo "# End of file" >> ${VNFSROOT}/${NAME}/etc/security/limits.conf

cat <<EOF > ${VNFSROOT}/${NAME}/etc/ssh/ssh_config
	Host *
	   StrictHostKeyChecking no
	   CheckHostIP yes
	   UsePrivilegedPort no
	   Protocol 2
EOF
	chmod +r ${VNFSROOT}/${NAME}/etc/ssh/ssh_config

###############################################################################

###############################################################################

	echo "Generate Random SSH Host Keys"
	/usr/bin/ssh-keygen -q -t rsa1 -f ${VNFSROOT}/${NAME}/etc/ssh/ssh_host_key -C '' -N ''
	/usr/bin/ssh-keygen -q -t rsa -f ${VNFSROOT}/${NAME}/etc/ssh/ssh_host_rsa_key -C '' -N ''
	/usr/bin/ssh-keygen -q -t dsa -f ${VNFSROOT}/${NAME}/etc/ssh/ssh_host_dsa_key -C '' -N ''

	if [ ! -f "${VNFSROOT}/${NAME}/etc/shadow" ]; then
		echo "Creating shadow file"
		/usr/sbin/chroot ${VNFSROOT}/${NAME} /usr/sbin/pwconv
	fi

	if [ -x "${VNFSROOT}/${NAME}/usr/bin/passwd" ]; then
		echo
		echo "Setting root password"
		/usr/sbin/chroot ${VNFSROOT}/${NAME} /usr/bin/passwd root
	else
		# add system root password to the nodes
		echo "Setting root password to NULL, be sure to fix this yourself"
		umask 277               # to prevent user readable files
		sed -e s/root::/root:!!:/ < ${VNFSROOT}/${NAME}/etc/shadow > ${VNFSROOT}/${NAME}/etc/shadow.new
		cp ${VNFSROOT}/${NAME}/etc/shadow.new ${VNFSROOT}/${NAME}/etc/shadow
		rm ${VNFSROOT}/${NAME}/etc/shadow.new
		umask 0022              # set umask back to default
	fi

	# add broken_shadow to pam.d/common-account
	if [[ -f "${VNFSROOT}/${NAME}/etc/pam.d/common-account" ]]
	then

		sed -i -e '/^account.*pam_unix\.so\s*$/s/\s*$/\ broken_shadow/' ${VNFSROOT}/${NAME}/etc/pam.d/common-account
	fi

	# Very Important Do A Final Cleanup
	# Make sure /proc is not mounted inside our new
	# vnfs before we exit else we later get the dreaded
	# cp: reading `./proc/sysrq-trigger': Input/output error
	clean_up ;

	warn_msg completed ;

	#########  Prompt for auto bootstrap and import into WW
	if [[ -n ${WWVNFS} ]]
	then
		extras ;
		wwimport ;
	fi

	if [[ -n ${WWBOOT} ]]
	then
		wwboot;
	fi
}


##---------

do_main $@

##---------

warn_msg finished ;
##---------------------------------------------------------------------
##---------------------------------------------------------------------

exit 0
