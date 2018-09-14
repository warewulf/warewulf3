SUBDIRS = defaults filesystem

confdir = $(sysconfdir)/warewulf/
bash_completiondir = $(sysconfdir)/bash_completion.d/

# Check for Debian
if ISDEB
httpdir = $(sysconfdir)/apache2/conf.d/
else
if ISSUSE
httpdir = $(sysconfdir)/apache2/conf.d/
else
# Assume RHEL Layout
httpdir = $(sysconfdir)/httpd/conf.d/
endif
endif

httpdconfdir = $(httpdir)

dist_conf_DATA = provision.conf livesync.conf dhcpd-template.conf
dist_httpdconf_DATA = warewulf-httpd.conf

MAINTAINERCLEANFILES = Makefile.in

