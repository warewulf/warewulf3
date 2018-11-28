SUBDIRS = defaults bash_completion.d

# This can/should be 600 if you don't want anybody else to see it and thus
# not be able to communicate with the data store.
# NOTE: The httpd process must be able to read database.conf for provisioning
dist_confDATA_INSTALL = ${INSTALL} -m 640


confdir = $(sysconfdir)/warewulf/

dist_conf_DATA = database.conf database-root.conf

MAINTAINERCLEANFILES = Makefile.in

