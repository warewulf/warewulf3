AC_PREREQ(2.59)
AC_INIT([warewulf-provision], [3.8.2], [warewulf-devel@lbl.gov])
AC_CONFIG_SRCDIR([.])

AC_PROG_INSTALL
AM_INIT_AUTOMAKE([foreign -Wno-portability])

AC_PATH_PROG(WWCONFIGBIN, wwconfig)
if test -z "$WWCONFIGBIN"; then
   AC_MSG_ERROR([wwconfig not found! (Warewulf common component)])
fi
AC_SUBST(WWCONFIGBIN)

AC_EXPAND_DIR(prefix, "${prefix}")
WAREWULF_PREFIX=`$WWCONFIGBIN PREFIX`
force_prefix=""
AC_MSG_CHECKING([warewulf-common prefix vs. current prefix])
if test "${prefix}" = "$WAREWULF_PREFIX"; then
   AC_MSG_RESULT([identical (${prefix})])
else
   AC_MSG_RESULT([MISMATCH (${prefix} vs. $WAREWULF_PREFIX), forcing install prefix on all paths])
   force_prefix="${prefix}"
fi

AC_EXPAND_DIR(datadir, "${datadir}")

AC_MSG_CHECKING([for Warewulf's configuration for statedir])
eval `$WWCONFIGBIN -s statedir`
if test -z "$WAREWULF_STATEDIR"; then
    AC_MSG_ERROR([Warewulf statedir not found])
fi
WAREWULF_STATEDIR="$force_prefix$WAREWULF_STATEDIR"
AC_MSG_RESULT($WAREWULF_STATEDIR)
AC_SUBST(WAREWULF_STATEDIR)


AC_MSG_CHECKING([for Debian based system])
AM_CONDITIONAL(ISDEB, [test -f /etc/debian_version])
AM_COND_IF([ISDEB],
    AC_MSG_RESULT([yes]),
    AC_MSG_RESULT([no])
)

AC_MSG_CHECKING([for SUSE based system])
AM_CONDITIONAL(ISSUSE, [test -e /etc/SUSEConfig ||
		       { test -e /etc/os-release &&
		       grep -q "ID_LIKE=\".*suse.*\"" /etc/os-release; }])
AM_COND_IF([ISSUSE],
    AC_MSG_RESULT([yes]),
    AC_MSG_RESULT([no])
)

AC_PATH_PROG(PERLBIN, perl)
if test -z "$PERLBIN"; then
   AC_MSG_ERROR([perl not found])
fi
AC_SUBST(PERLBIN)

AC_MSG_CHECKING([for Perl vendor lib path])
eval `$PERLBIN -V:installvendorlib`
PERL_VENDORLIB=$installvendorlib
AC_ARG_WITH(perllibdir, [  --with-perllibdir=path  Manually specify where the perl modules should go], [
if test -n "$withval" -a "x$withval" != "xno" ; then
   PERL_VENDORLIB=$withval
fi
])
PERL_VENDORLIB="$force_prefix$PERL_VENDORLIB"
AC_MSG_RESULT($PERL_VENDORLIB)
AC_SUBST(PERL_VENDORLIB)

#AC_CHECK_LIB(fuse, fuse_main, , [
#AC_MSG_ERROR([Fatal:  Fuse libraries not found.])
#])

AC_EXPAND_DIR(fulllibexecdir, "$libexecdir")
AC_SUBST(fulllibexecdir)

AC_EXPAND_DIR(fulllocalstatedir, "$localstatedir")
AC_SUBST(fulllocalstatedir)

AC_EXPAND_DIR(fulldatadir, "$datadir")
AC_SUBST(fulldatadir)

initramfsdir="$localstatedir/warewulf/initramfs/";
AC_SUBST(initramfsdir)

AC_SUBST(PERLBIN)

dnl# Get git version
GITVERSION=`cat .gitversion | tr -d '\n'`
AC_SUBST(GITVERSION)

AC_ARG_ENABLE([cross_compile],
  AS_HELP_STRING([--enable-cross-compile], [Enable cross-compile of iPXE and Initramfs]))

AC_CANONICAL_HOST

AS_CASE([$host_cpu],
    [x86_64],
    [
        build_x86_64=yes
        AS_IF([test "x$enable_cross_compile" = "xyes"], [
            AC_MSG_NOTICE([cross-compile for aarch64 configured])
            CROSS_COMPILE_ARM64="aarch64-linux-gnu-"
            build_arm64=yes
        ])
    ],
    [aarch64],
    [
        build_arm64=yes
        AS_IF([test "x$enable_cross_compile" = "xyes"], [
            AC_MSG_NOTICE([cross-compile for x86_64 configured])
            CROSS_COMPILE_X86_64="x86_64-linux-gnu-"
            build_x86_64=yes
        ])
    ]
)

AC_SUBST(CROSS_COMPILE_X86_64)
AC_SUBST(CROSS_COMPILE_ARM64)
AM_CONDITIONAL(BUILD_X86_64, [test "x$build_x86_64" = "xyes"])
AM_CONDITIONAL(BUILD_ARM64, [test "x$build_arm64" = "xyes"])

AC_OUTPUT(
   Makefile
   warewulf-provision.spec
   3rd_party/Makefile
   3rd_party/GPL/Makefile
   3rd_party/BSD/Makefile
   bin/Makefile
   cgi-bin/Makefile
   etc/Makefile
   etc/defaults/Makefile
   etc/filesystem/Makefile
   etc/filesystem/examples/Makefile
   etc/warewulf-httpd.conf
   initramfs/Makefile
   initramfs/capabilities/Makefile
   initramfs/capabilities/provision-adhoc/Makefile
   initramfs/capabilities/provision-files/Makefile
   initramfs/capabilities/provision-vnfs/Makefile
   initramfs/capabilities/provision-selinux/Makefile
   initramfs/capabilities/setup-filesystems/Makefile
   initramfs/capabilities/transport-http/Makefile
   share/Makefile
   lib/Makefile
   lib/Warewulf/Makefile
   lib/Warewulf/DSO/Makefile
   lib/Warewulf/Event/Makefile
   lib/Warewulf/Module/Makefile
   lib/Warewulf/Module/Cli/Makefile
   lib/Warewulf/Provision/Makefile
   lib/Warewulf/Provision/Dhcp/Makefile
)
