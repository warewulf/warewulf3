METHODSCRIPTS = 30-getvnfs 50-config 60-runtimesupport 70-kernelmodules

MAINTAINERCLEANFILES = Makefile.in

MACHINE:=$(shell uname -m)

rootfs:
	rm -rf rootfs
	mkdir -p rootfs/warewulf/provision/
	@ for i in $(METHODSCRIPTS); do \
		echo "install -m 755 $$i rootfs/warewulf/provision/$$i" ; \
		install -p -m 755 $(srcdir)/$$i rootfs/warewulf/provision/$$i; \
	done

# Preserve time stamps of archived files for build reproducibility
capability.cpio: rootfs
	find rootfs/ -type d | xargs touch -r $(word 1,$(METHODSCRIPTS));
	cd rootfs/; find . | cpio -o -H newc --reproducible -F ../capability.cpio

install-data-local: capability.cpio
	install -d -m 755 $(DESTDIR)/$(WAREWULF_STATEDIR)/warewulf/initramfs/$(MACHINE)/capabilities
	install -m 644 capability.cpio $(DESTDIR)/$(WAREWULF_STATEDIR)/warewulf/initramfs/$(MACHINE)/capabilities/provision-vnfs

uninstall-local:
	rm -rf $(DESTDIR)/$(WAREWULF_STATEDIR)/warewulf/initramfs/$(MACHINE)/capabilities/provision-vnfs

clean-local:
	rm -rf rootfs capability.cpio


EXTRA_DIST = $(METHODSCRIPTS) $(INITSCRIPT)

