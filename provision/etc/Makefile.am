SUBDIRS = defaults filesystem

confdir = $(sysconfdir)/warewulf/
bash_completiondir = $(sysconfdir)/bash_completion.d/

# Check for Ubuntu first, then for Debian
# (Debian check is also true on Ubuntu, so Ubuntu must be first)
# If neither, check for SUSE.
# If no check succeeds, assume it's Red Hat-based
if ISUBU
httpdir = $(sysconfdir)/apache2/sites-available/
else
if ISDEB
httpdir = $(sysconfdir)/apache2/conf.d/
else
if ISSUSE
httpdir = $(sysconfdir)/apache2/conf.d/
else
httpdir = $(sysconfdir)/httpd/conf.d/
endif
endif
endif
httpdconfdir = $(httpdir)

dist_conf_DATA = provision.conf livesync.conf dhcpd-template.conf dnsmasq-template.conf
dist_httpdconf_DATA = warewulf-httpd.conf

MAINTAINERCLEANFILES = Makefile.in

