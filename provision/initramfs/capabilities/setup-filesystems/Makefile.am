METHODSCRIPTS = 20-filesystems 80-mkbootable 95-umount 99-postreboot

MAINTAINERCLEANFILES = Makefile.in

rootfs:
	rm -rf rootfs
	mkdir -p rootfs/warewulf/provision/
	@ for i in $(METHODSCRIPTS); do \
		echo "install -m 755 $$i rootfs/warewulf/provision/$$i" ; \
		install -m 755 $(srcdir)/$$i rootfs/warewulf/provision/$$i; \
	done

capability.cpio: rootfs
	cd rootfs/; find . | cpio -o -H newc -F ../capability.cpio

install-data-local: capability.cpio
	install -d -m 755 $(DESTDIR)/$(WAREWULF_STATEDIR)/warewulf/initramfs/capabilities
	install -m 644 capability.cpio $(DESTDIR)/$(WAREWULF_STATEDIR)/warewulf/initramfs/capabilities/setup-filesystems

uninstall-local:
	rm -rf $(DESTDIR)/$(WAREWULF_STATEDIR)/warewulf/initramfs/capabilities/setup-filesystems

clean-local:
	rm -rf rootfs capability.cpio


EXTRA_DIST = $(METHODSCRIPTS) $(INITSCRIPT)
