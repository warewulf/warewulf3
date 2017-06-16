# BIOS / GPT Example with UUIDs

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
mkfs 2 ext4 -L BOOT -U 9c35cf2c-2d12-4d5d-9d0c-7fa32afe1a5a
mkfs 3 swap -L SWAP
mkfs 4 ext4 -L ROOT -U 63f527cc-6bd3-4103-985b-b8e963581163

# fstab NUMBER fs_file fs_vfstype fs_mntops fs_freq fs_passno
fstab UUID=63f527cc-6bd3-4103-985b-b8e963581163 / ext4 defaults 0 0
fstab UUID=9c35cf2c-2d12-4d5d-9d0c-7fa32afe1a5a /boot ext4 defaults 0 0
fstab LABEL=SWAP swap swap defaults 0 0
