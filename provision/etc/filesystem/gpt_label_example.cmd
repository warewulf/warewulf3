# BIOS / GPT Example with Labels

# Parted specific commands
select /dev/sda
mklabel gpt
mkpart primary 1MiB 3MiB
mkpart primary ext4 3MiB 513MiB
mkpart primary linux-swap 513MiB 50%
mkpart primary ext4 50% 100%
name 1 grub
name 2 boot
name 3 swap
name 4 root
set 1 bios_grub on
set 2 boot on

# mkfs NUMBER FS-TYPE [ARGS...]
mkfs 2 ext4 -L BOOT
mkfs 3 swap -L SWAP
mkfs 4 ext4 -L ROOT

# fstab NUMBER fs_file fs_vfstype fs_mntops fs_freq fs_passno
fstab LABEL=ROOT / ext4 defaults 0 0
fstab LABEL=BOOT /boot ext4 defaults 0 0
fstab LABEL=SWAP swap swap defaults 0 0
