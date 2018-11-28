AC_PREREQ(2.59)
AC_INIT(warewulf-ipmi, 3.8.2, warewulf-devel@lbl.gov)
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
AC_SUBST(PERLBIN)

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

AC_MSG_CHECKING([for Warewulf's configuration for statedir])
eval `$WWCONFIGBIN -s statedir`
if test -z "$WAREWULF_STATEDIR"; then
    AC_MSG_ERROR([Warewulf statedir not found])
fi
WAREWULF_STATEDIR="$force_prefix$WAREWULF_STATEDIR"
AC_MSG_RESULT($WAREWULF_STATEDIR)
AC_SUBST(WAREWULF_STATEDIR)

AC_MSG_CHECKING([for Warewulf's configuration for libexecdir])
eval `$WWCONFIGBIN -s libexecdir`
if test -z "$WAREWULF_LIBEXECDIR"; then
    AC_MSG_ERROR([Warewulf libexecdir not found])
fi
WAREWULF_LIBEXECDIR="$force_prefix$WAREWULF_LIBEXECDIR"
AC_MSG_RESULT($WAREWULF_LIBEXECDIR)
AC_SUBST(WAREWULF_LIBEXECDIR)

dnl# Get git version
GITVERSION=`cat .gitversion | tr -d '\n'`
AC_SUBST(GITVERSION)

AC_MSG_CHECKING([for locally installed ipmitool])
AC_ARG_WITH([local-ipmitool], [
   AS_HELP_STRING([--with-local-ipmitool], [
           use locally installed ipmitool @<:@default is no@:>@
    ])], [], [with_local_ipmitool=no]
)

local_ipmitool_path=
AS_IF([test -n "$with_local_ipmitool" -a "x$with_local_ipmitool" != "xno"], [
    local_ipmitool_path="$with_local_ipmitool"
    AS_IF([test "x$with_local_ipmitool" == "xyes"], [local_ipmitool_path=ipmitool])
    AS_IF([test -f "$local_ipmitool_path"], [
        AC_MSG_RESULT([$local_ipmitool_path])
    ], [
        search_ipmitool_path=`which "$local_ipmitool_path" 2>/dev/null`
        AS_IF([test -z "$search_ipmitool_path"], [
            AC_MSG_ERROR([no, $local_ipmitool_path could not be found])
        ], [
            AC_MSG_RESULT([$search_ipmitool_path])
            local_ipmitool_path="$search_ipmitool_path"
        ])
    ])
], [
      AC_MSG_RESULT([no])
      local_ipmitool_path=
])

AC_SUBST(local_ipmitool_path)

AC_OUTPUT(Makefile
   warewulf-ipmi.spec
   lib/Makefile
   lib/Warewulf/Makefile
   lib/Warewulf/Module/Makefile
   lib/Warewulf/Module/Cli/Makefile
   3rd_party/Makefile
   3rd_party/BSD/Makefile
   initramfs/Makefile
)

