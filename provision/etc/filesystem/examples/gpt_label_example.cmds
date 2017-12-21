# BIOS / GPT Example with UUIDs

# Parted specific commands
# Parted specific commands
select /dev/sda
mklabel gpt
mkpart ESP fat32 1MiB 513MiB
mkpart primary linux-swap 513MiB 20%
mkpart primary ext4 20% 100%
name 1 ESP
name 2 swap
name 3 root
set 1 boot on

# mkfs NUMBER FS-TYPE [ARGS...]
mkfs 1 vfat -n ESP
mkfs 2 swap -L SWAP
mkfs 3 ext4 -L ROOT -U 63f527cc-6bd3-4103-985b-b8e963581163

# fstab NUMBER fs_file fs_vfstype fs_mntops fs_freq fs_passno
fstab UUID=63f527cc-6bd3-4103-985b-b8e963581163 / ext4 defaults 0 0
fstab LABEL=ESP /boot/efi vfat defaults 0 0
fstab LABEL=SWAP swap swap defaults 0 0

