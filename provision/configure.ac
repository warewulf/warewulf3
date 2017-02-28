AC_PREREQ(2.59)
AC_INIT([warewulf-provision], [3.7], [warewulf-devel@lbl.gov])
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
GITVERSION=`git show -s --pretty=format:%h 2>/dev/null || echo 0000`
AC_SUBST(GITVERSION)

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
