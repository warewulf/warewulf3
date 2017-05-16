# Warewulf Installation

Warewulf is developed and thus most tested on Red Hat based distributions of Linux, but it is not specific to these distributions. We encourage other flavors of Linux to be tested, used, and developed on, but Red Hat (and clones) are still the most commonly used distributions for server infrastructures and thus are our focus.

* * *

## Installing Warewulf with YUM/RPM

We host prebuilt packages for Warewulf for RHEL5 and RHEL6 maintained in a YUM repository. This is the easiest way to install Warewulf components on your Red Hat system.

### Warewulf YUM Repository configuration

#### Red Hat Enterprise Linux 5 (and compatibles)

```
$ sudo wget -O /etc/yum.repos.d/warewulf-rhel5.repo http://warewulf.lbl.gov/downloads/repo/warewulf-rhel5.repo
```

#### Red Hat Enterprise Linux 6 (and compatibles)

```
$ sudo wget -O /etc/yum.repos.d/warewulf-rhel6.repo http://warewulf.lbl.gov/downloads/repo/warewulf-rhel6.repo
```

### Installing Warewulf components via YUM

Once you have added the Warewulf repository configuration to YUM, you can then install packages with the following syntax (using the base **warewulf-common** package as an example):

```
$ sudo yum install warewulf-common
```

* * *

## Installing Warewulf on Debian

The installer available for Debian systems offers a complete and easy to use guided install. It is designed to take even a minimalistic Debian install, and produce a configured, and fully functioning Warewulf master node.

It will install all the required dependency via apt-get, including the build environment, and use wget to retrieve the desired version of warewulf sources. The sources will be automatically downloaded, compiled, and installed. An install path may also be chosen, and will be passed as an option to ./configure . The default prefix is /usr/local. It will install any released version available, including nightly builds. It can setup and configure the Warewulf net device, as well as the tftp and mySQL servers.

**NOTE:** Debian support only available on versions 3.5 and above.  
**NOTE:** Debian support only available on nightly builds 2014-02-10 and newer.  
**NOTE:** All source will be downloaded into the same directory as the installer and compiled as root.

#### Download and set the installer executable

```
$ mkdir ~/Downloads
$ cd ~/Downloads
$ wget --no-check-certificate https://warewulf.lbl.gov/svn/trunk/platform/deb/install-wwdebsystem
$ chmod +x install-wwdebsystem
```

**Example 1:**  
Configure the system and Install version 3.5 into the default /usr/local  

```
$ sudo ./install-wwdebsystem 3.5
```

**Example 2:**  
Configure the system and Install a specific nightly build into /usr .

```
$ sudo ./install-wwdebsystem 2014-02-15 /usr
```

Additional help information can be viewed with.

```
$ ./install-wwdebsystem -h
```

#### Mix-n-Match

The installer will not download any new source.tar.gz of the same name, if already found in the same directory as the installer. The existing source.tar.gz file(s) will be used, and only those not found locally will be download for the install. This may be useful when needing to install modules from various different nightly builds, or when installing a fully released version, but with a module(s) from a more recent nightly build.

* * *

## Installation via Source

This procedure is recommended for experienced users that are either editing source or want custom installations. The following is a general build procedure for installing Warewulf via Source.

```
$ cd ~/warewulf-common-3.2
$ ./configure
$ make
$ sudo make install
```

> note: It is required that you build and install warewulf-common first because the other packages need to understand how it is configured. Also, some packages will require root to do the final <tt>make install</tt> because it will need to write configuration files to root owned directories for the package to work (e.g. /etc/httpd/conf.d/).
