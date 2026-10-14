# 🛠️ Sable Linux — Development Guide

This guide outlines prerequisites, workflow, and operational instructions for developing Sable Linux on the host environment.

---

## 1. Host Prerequisites

Recommended development environment is Linux (e.g., Fedora, Debian, or Ubuntu).

### Fedora
```bash
sudo dnf install debootstrap qemu-system-x86 podman
```

### Debian / Ubuntu
```bash
sudo apt install debootstrap qemu-system-x86 podman
```

---

## 2. Initial Workflow

### Milestone 0 & 1: Configuration & Structure
All core system parameters reside in `config/sable.conf`:
- `SABLE_NAME`
- `SABLE_VERSION`
- `SABLE_CODENAME`
- `DEBIAN_SUITE` (default: `trixie`)
- `DEBIAN_ARCH` (default: `amd64`)
- `DEBIAN_MIRROR` (default: `https://deb.debian.org/debian`)

### Milestone 2: Bootstrap Execution
The `./scripts/bootstrap.sh` script initializes the minimal base filesystem using `debootstrap --variant=minbase`.

```bash
sudo ./scripts/bootstrap.sh
```

### Milestone 4 & 5: Chroot Management
To enter the isolated Sable environment shell:

1. **Mount virtual filesystems and DNS:**
   ```bash
   sudo ./scripts/mount.sh
   ```

2. **Enter chroot:**
   ```bash
   sudo ./scripts/chroot.sh
   ```

3. **Operate inside chroot:**
   ```bash
   export HOME=/root
   export LC_ALL=C
   apt update
   apt upgrade
   ```

4. **Exit and clean unmount:**
   ```bash
   exit
   sudo ./scripts/mount.sh -u
   ```

---

## 3. Git Conventions
- Each change or milestone progress must have an atomic and descriptive commit.
- Do not perform unverified pushes to the main remote branch.
