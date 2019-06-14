SUBDIRS = defaults filesystem

confdir = $(sysconfdir)/warewulf/
bash_completiondir = $(sysconfdir)/bash_completion.d/

# Check for Debian
if ISDEB
httpdir = $(sysconfdir)/apache2/conf.d/
endif
# Check for SUSE
if ISSUSE
httpdir = $(sysconfdir)/apache2/conf.d/
endif
# Check for Ubuntu
if ISUBU
httpdir = $(sysconfdir)/apache2/sites-available/
endif

# Assume RHEL Layout
httpdir = $(sysconfdir)/httpd/conf.d/
httpdconfdir = $(httpdir)

dist_conf_DATA = provision.conf livesync.conf dhcpd-template.conf dnsmasq-template.conf
dist_httpdconf_DATA = warewulf-httpd.conf

MAINTAINERCLEANFILES = Makefile.in

