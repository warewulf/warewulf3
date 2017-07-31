## Installation using Subversion checkout

First be sure that you have the needed utilities (compilers, development libraries, autoconf, etc...). For example, on a **Red Hat** based system, you can do the following:

```
$ sudo yum groupinstall "Development Tools"
```

### Source Tree

Setup your Warewulf source tree.

```
$ mkdir ~/development
$ cd ~/develpment
$ svn checkout https://warewulf.lbl.gov/svn warewulf
$ cd warewulf/trunk/
$ ls
common/  ipmi/  legacy/  monitor/  nhc/  provision/  skel/  vnfs/
$
```

See the attached _wwBuild.sh_ file for a scripted example of building Warewulf from source.

### Build warewulf-common as a test

warewulf-common has the majority of Warewulf Perl libraries contained within it. Lets do a test build of it.

```
$ pwd
~/development/warewulf/trunk
$ cd common
$ ./autogen.sh
```

By default when autogen.sh is ran, it will run the generated configure script. If you do not want autogen.sh to execute configure, then you can define the variable **NO_CONFIGURE**. For example:

```
$ NO_CONFIGURE=1 ./autogen.sh
```

#### Configure the Package

You can pass options to _configure_ in two different ways. First, after autogen.sh is executed, run **./configure [options]** yourself manually. The second is to pass the options to configure on the autogen.sh line.

```
#### First Way ####
$ NO_CONFIGURE=1 ./autogen.sh
$ ./configure --prefix=/usr/local

#### Second Way ####
$ ./autogen.sh --prefix=/usr/local
```

#### Package Installation

Now that you've configured the package, run make.

```
$ make
```

It's also a very good idea to run **_make test_**

```
$ make test
```

> **NOTE:** Depending on your Perl installation, you **_may_** get an error similar to:

```
#     Tried to use 'Warewulf::Module::Cli::Node'.                                                                                                                       
#     Error:  Can't locate sys/ioctl.ph in @INC (@INC contains: ./lib /usr/lib/perl5/5.10.0/i486-linux-thread-multi
#       /usr/lib/perl5/5.10.0 /usr/lib/perl5/site_perl/5.10.0/i486-linux-thread-multi /usr/lib/perl5/site_perl/5.10.0
#       /usr/lib/perl5/site_perl /usr/lib/perl5/vendor_perl/5.10.0/i486-linux-thread-multi /usr/lib/perl5/vendor_perl/5.10.0
#       /usr/lib/perl5/vendor_perl) at lib/Warewulf/Network.pm line 20\.                                                                                                           
# Compilation failed in require at lib/Warewulf/Module/Cli/Node.pm line 21.
```

If your installed Perl cannot find the ioctl.ph (or any other) file, then it's most likely because it was never created when Perl was installed (it is optional). To fix this, you'll need to use the **h2ph** Perl script.

```
$ cd /usr/include
$ sudo h2ph -al * sys/*
```

For more info on h2ph see (for example): **perldoc -F /usr/bin/h2ph**

Once **make test** passes you can then install it:

```
$ sudo make install
```

##### RPM Installation with warewulf-common.spec file

After you have ran _autogen.sh_ and have the **Makefile**'s created, you can do the following to build an RPM Package.

```
$ mkdir -p ~/rpmbuild/{BUILD,BUILDROOT,RPMS,SOURCES,SPECS,SRPMS}
$ pwd
~/development/warewulf/trunk/common
$ make dist-gzip
$ make distcheck
$ cp -a warewulf-common-[VER].tar.gz ~/rpmbuild/SOURCES/
$ rpmbuild -bb ./warewulf-common.spec
$ rpm -qip ~/rpmbuild/RPMS/[ARCH]/warewulf-common-[VER]-[REL].[ARCH].rpm
```

> **NOTE:** Currently (2012-02-27), the SPEC files are written in such a way that they will always have the options of: prefix=/usr , sysconfdir=/etc . If you wish to change the location of where the RPM installs to, you'll need to modify your RPM Macros. Something like the following should work:

${HOME}/.rpmmacros:

```
%_prefix            /usr/local
%_sysconfdir        /usr/local/etc
```

See your distro's system wide macros file for more info.
