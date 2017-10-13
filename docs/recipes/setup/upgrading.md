# Upgrading Warewulf

As Warewulf introduces new features the object format may change slightly. There is a mechanism within Warewulf to check and update the object formats if necessary, and this should be done after upgrades:

```
$ sudo wwsh object canonicalize
```
