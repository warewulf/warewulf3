AC_PREREQ(2.59)
AC_INIT(warewulf-common, 3.8.2, warewulf-devel@lbl.gov)
AC_CONFIG_SRCDIR([.])

AC_PROG_INSTALL
AM_INIT_AUTOMAKE([foreign])

AC_PATH_PROG(PERLBIN, perl)
if test -z "$PERLBIN"; then
   AC_MSG_ERROR([perl not found])
fi
AC_SUBST(PERLBIN)

AC_MSG_CHECKING(for Perl vendor lib path)
eval `perl -V:installvendorlib`
PERL_VENDORLIB=$installvendorlib
AC_ARG_WITH(perllibdir, [  --with-perllibdir=path  Manually specify where the perl modules should go], [
if test -n "$withval" -a "x$withval" != "xno" ; then
   PERL_VENDORLIB=$withval
fi
])
AC_MSG_RESULT($PERL_VENDORLIB)
AC_SUBST(PERL_VENDORLIB)

AC_ARG_WITH([bashcompletionconfdir],
    [AS_HELP_STRING([--with-bashcompletionconfdir], [Directory for bash completion configuration files (default is SYSCONFDIR/bash_completion.d)])],
    [bashcompletionconfdir=$withval],
    [bashcompletionconfdir='${sysconfdir}/bash_completion.d']
)
AC_SUBST([bashcompletionconfdir])

dnl# Compatibility for RHEL5
if test "x${datarootdir}" = "x"; then
    datarootdir="$datadir"
    AC_SUBST(datarootdir)
fi

dnl# Get git version
GITVERSION=`cat .gitversion | tr -d '\n'`
AC_SUBST(GITVERSION)

AC_OUTPUT(Makefile
   warewulf-common.spec
   share/Makefile
   bin/Makefile
   etc/Makefile
   etc/bash_completion.d/Makefile
   etc/defaults/Makefile
   lib/Makefile
   lib/Warewulf/ACVars.pm
   lib/Warewulf/Makefile
   lib/Warewulf/DSO/Makefile
   lib/Warewulf/Event/Makefile
   lib/Warewulf/System/Makefile
   lib/Warewulf/Module/Makefile
   lib/Warewulf/Module/Cli/Makefile
   lib/Warewulf/DataStore/Makefile
   lib/Warewulf/DataStore/SQL/Makefile
   libexec/Makefile
   libexec/wwinit/Makefile
)

