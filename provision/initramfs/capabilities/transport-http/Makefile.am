METHODSCRIPTS = wwgetscript wwgetnodeconfig wwgetvnfs register functions wwgetfiles

MAINTAINERCLEANFILES = Makefile.in

TRANSPORT_NAME = http


rootfs:
	rm -rf rootfs
	mkdir -p rootfs/warewulf/transports/$(TRANSPORT_NAME)
	@ for i in $(METHODSCRIPTS); do \
		echo "install -m 755 $$i rootfs/warewulf/transports/$(TRANSPORT_NAME)/$$i" ; \
		install -m 755 $(srcdir)/$$i rootfs/warewulf/transports/$(TRANSPORT_NAME)/$$i; \
	done

capability.cpio: rootfs
	cd rootfs/; find . | cpio -o -H newc -F ../capability.cpio

install-data-local: capability.cpio
	install -d -m 755 $(DESTDIR)/$(WAREWULF_STATEDIR)/warewulf/initramfs/capabilities
	install -m 644 capability.cpio $(DESTDIR)/$(WAREWULF_STATEDIR)/warewulf/initramfs/capabilities/transport-http

uninstall-local:
	rm -rf $(DESTDIR)/$(WAREWULF_STATEDIR)/warewulf/initramfs/capabilities/transport-http

clean-local:
	rm -rf rootfs capability.cpio


EXTRA_DIST = $(METHODSCRIPTS)

