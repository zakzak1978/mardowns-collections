# Linux Commands

## df -h Command

The `df -h` command in Linux displays disk space usage for all mounted file systems in a human-readable format. Here's what it does:

- **`df`**: Stands for "disk free" and reports the amount of disk space used and available on file systems.
- **`-h`**: The "human-readable" flag formats the output in easy-to-read units (e.g., GB, MB, KB) instead of raw bytes.

Example output might look like this:

```
Filesystem      Size  Used Avail Use% Mounted on
/dev/sda1        50G   20G   28G  42% /
tmpfs           2.0G     0  2.0G   0% /tmp
```

It helps you quickly check disk usage and identify if any partitions are running low on space. If you need more details or variations (like `df -Th` for file system types), let me know!

## lsblk Command

The `lsblk` command in Linux lists information about all available block devices (like hard drives, SSDs, USB drives, and partitions). It provides a tree-like view of the devices and their hierarchy.

Key features:
- Shows device names (e.g., `sda`, `sdb1`)
- Displays sizes, mount points, file system types, and labels
- Includes options like `-f` for file system info or `-o` to customize output columns

Example output:

```bash
NAME   MAJ:MIN RM   SIZE RO TYPE MOUNTPOINT
sda      8:0    0  50G  0 disk 
├─sda1   8:1    0  40G  0 part /
└─sda2   8:2    0  10G  0 part [SWAP]
sdb      8:16   1   8G  0 disk /mnt/usb
```

It's useful for identifying disks and partitions without needing root access.

## cloud-guest-utils Package

### Use of cloud-guest-utils
`cloud-guest-utils` is a package for Debian-based Linux distributions (like Ubuntu) that provides utilities for managing cloud virtual machine instances. Its main purposes include:

- **Disk management**: Tools for resizing and managing virtual disks in cloud environments (e.g., `growpart` for expanding partitions to fill available space).
- **Cloud-init integration**: Supports initialization scripts and configurations for cloud instances, enabling automated setup on first boot (e.g., configuring network, users, or packages).
- **Guest tools**: Includes utilities for interacting with the host hypervisor or cloud provider, such as detecting and configuring network interfaces, storage, or metadata services.

It's essential for cloud platforms like AWS EC2, Azure VMs, or GCP instances, where VMs need to dynamically adapt to allocated resources without manual intervention.

### How to Install cloud-guest-utils
On Ubuntu or Debian-based systems:

1. Update your package list:
   ```bash
   sudo apt update
   ```

2. Install the package:
   ```bash
   sudo apt install cloud-guest-utils
   ```

3. Verify installation:
   ```bash
   dpkg -l | grep cloud-guest-utils
   ```

After installation, tools like `growpart` become available. For example, to resize a partition:
```bash
sudo growpart /dev/sda 1  # Expands partition 1 on /dev/sda
```

## resize2fs Command

The `sudo resize2fs` command is used in Linux to resize ext2, ext3, or ext4 file systems (the most common types for Linux partitions). Here's what it does:

- **Purpose**: It expands or shrinks the file system to match the size of the underlying partition or logical volume. This is often done after resizing the disk/partition (e.g., using tools like `growpart` or `lvextend`).
- **Why `sudo`?**: File system operations require root privileges, so `sudo` elevates permissions.
- **Common use**: After increasing a partition's size in the cloud or VM, `resize2fs` adjusts the file system to use the new space.

Example: To resize the file system on `/dev/sda1` to fill the partition:

```bash
sudo resize2fs /dev/sda1
```

**Warning**: Shrinking requires unmounting the file system first, and it's risky—back up data before proceeding. For expanding, the file system can usually be resized online.

## SSH with -i Option and .pem Files

SSH (Secure Shell) allows secure connections to remote servers. The `-i` option specifies a private key file for authentication, which is common with cloud providers like AWS, where keys are provided as .pem files.

- **What is a .pem file?**: It's a Privacy Enhanced Mail format file containing an RSA private key, used for key-based authentication instead of passwords.
- **Why use `-i`?**: It tells SSH to use the specified key file for the connection.
- **Permissions**: The .pem file should have restricted permissions (e.g., `chmod 400 key.pem`) to prevent unauthorized access.

### Basic Syntax

```bash
ssh -i /path/to/your-key.pem user@hostname
```

### Example

Assuming you have a .pem file named `my-aws-key.pem` for an EC2 instance:

1. Set correct permissions on the key:

   ```bash
   chmod 400 my-aws-key.pem
   ```

2. Connect to the server (replace `ec2-user` with the appropriate user, like `ubuntu` for Ubuntu instances, and `ec2-instance-ip` with the actual IP):

   ```bash
   ssh -i my-aws-key.pem ec2-user@ec2-instance-ip
   ```

This establishes a secure connection using the private key. If the public key is already added to the server's `~/.ssh/authorized_keys`, you'll log in without a password prompt.
