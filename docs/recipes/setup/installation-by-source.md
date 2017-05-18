## Installing by Source

### Downloading Warewulf

Goto the [Download](../../download.md) page and select which distribution type and packages you want to install, and download them to the system you wish to install them on. For example:

```
$ mkdir ~/warewulf-src
$ cd ~/warewulf-src
$ wget http://warewulf.lbl.gov/downloads/testing/2011-06-07/warewulf-common-0.0.1.tar.gz
```

### General Building and Installing

Following the standard build procedures will easily create and install Warewulf on your target system. However, this install will not be managed by your systems package manager. This may or may not be an issue for you. If you are running an RPM based distro, it's recommended to skip to the next section for RPM creation and installation. Thus allowing your systems package manager log your installed applications, and properly handle dependencies.

```
$ cd ~/warewulf-src
$ ./configure
$ make
$ sudo make install
```

### Building and installing RPMs for Warewulf

Once you have downloaded the packages(s) you wish to build, you can easily create RPMS of them by using the **rpmbuild** command. This command is part of Red Hat Enterprise Linux and compatibles when the **Development Tools** package group has been installed.

```
$ sudo yum groupinstall "Development Tools"
$ cd ~/warewulf-src
$ sudo rpmbuild -ta warewulf-common-0.0.1.tar.gz
```

Near the end of the output of the **rpmbuild** command it will tell you where it created the built RPMs. It will create a SRPM as well as a binary RPM. You will want to install the binary RPM and not the SRPM. For example:

```
...
Wrote: /root/rpmbuild/SRPMS/warewulf-common-0.0.1-0.r430.src.rpm
Wrote: /root/rpmbuild/RPMS/noarch/warewulf-common-0.0.1-0.r430.noarch.rpm
Executing(%clean): /bin/sh -e /var/tmp/rpm-tmp.fOQ0dh
+ umask 022
+ cd /root/rpmbuild/BUILD
+ cd warewulf-common-0.0.1
+ rm -rf /root/rpmbuild/BUILDROOT/warewulf-common-0.0.1-0.r430.x86_64
+ exit 0
```

Assuming the above example, you should install the built RPMS using **yum** (which will also install the dependencies) as follows:

```
$ sudo yum install --nogpgcheck /root/rpmbuild/RPMS/noarch/warewulf-common-0.0.1-0.r430.noarch.rpm
```

#### Using Mezzanine to build RPMS

You can also build binary RPMS using Mezzanine (which is how we build RPMS). You can obtain [Mezzanine here](../../mezzanine.md), and build RPMS as follows:

```
$ cd ~/warewulf-src
$ mzbuild warewulf-common-0.0.1.tar.gz
```
