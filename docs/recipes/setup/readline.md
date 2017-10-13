# Tab Completion in WWSH via GNU Readline

If you have the Perl interface to Readline GNU installed the Warewulf shell will have tab completion and Bash-like shortcuts. This can be installed directly if you are using the Warewulf YUM/RPM repository:

## Installation Readline via YUM/RPM

If you have the Warewulf or other repository setup on your system that includes this package, you can install it simply via:

```
$ sudo yum install perl-Term-ReadLine-Gnu
```

## Installation from source

You can find the [<span class="icon"> </span>Term::ReadLine::Gnu Perl module on CPAN](http://search.cpan.org/~hayashi/Term-ReadLine-Gnu-1.20/Gnu.pm) and install via

```
$ wget http://search.cpan.org/CPAN/authors/id/H/HA/HAYASHI/Term-ReadLine-Gnu-1.20.tar.gz
$ tar zvxf Term-ReadLine-Gnu-1.20.tar.gz
$ cd Term-ReadLine-Gnu-1.20
$ perl Makefile.PL
$ make
$ sudo make install
```

Then tab completion will work in **wwsh** without rebuilding from the source.
