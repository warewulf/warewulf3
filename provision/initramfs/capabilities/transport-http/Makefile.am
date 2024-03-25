METHODSCRIPTS = wwgetscript wwgetnodeconfig wwgetvnfs register functions wwgetfiles

MAINTAINERCLEANFILES = Makefile.in

MACHINE:=$(shell uname -m)

TRANSPORT_NAME = http


rootfs:
	rm -rf rootfs
	mkdir -p rootfs/warewulf/transports/$(TRANSPORT_NAME)
	@ for i in $(METHODSCRIPTS); do \
		echo "install -m 755 $$i rootfs/warewulf/transports/$(TRANSPORT_NAME)/$$i" ; \
		install -p -m 755 $(srcdir)/$$i rootfs/warewulf/transports/$(TRANSPORT_NAME)/$$i; \
	done

# Preserve time stamps of archived files for build reproducibility
capability.cpio: rootfs
	find rootfs/ -type d | xargs touch -r $(word 1,$(METHODSCRIPTS));
	cd rootfs/; find . | cpio -o -H newc --reproducible -F ../capability.cpio

install-data-local: capability.cpio
	install -d -m 755 $(DESTDIR)/$(WAREWULF_STATEDIR)/warewulf/initramfs/$(MACHINE)/capabilities
	install -m 644 capability.cpio $(DESTDIR)/$(WAREWULF_STATEDIR)/warewulf/initramfs/$(MACHINE)/capabilities/transport-http

uninstall-local:
	rm -rf $(DESTDIR)/$(WAREWULF_STATEDIR)/warewulf/initramfs/$(MACHINE)/capabilities/transport-http

clean-local:
	rm -rf rootfs capability.cpio


EXTRA_DIST = $(METHODSCRIPTS)

