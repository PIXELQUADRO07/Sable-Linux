# Sable Linux — Architecture

## Overview

Sable Linux is a Debian-based Linux distribution designed as an independent operating system project with its own configuration, branding, build tooling and release process.

## Initial goals

* Build a minimal Debian-based root filesystem.
* Identify the resulting system as Sable Linux.
* Automate the build process.
* Produce a bootable x86_64 image.
* Add a KDE Plasma desktop in a later milestone.

## Initial technical decisions

* Base distribution: Debian 13 (Trixie)
* Architecture: amd64
* Build host: Fedora Linux
* Initial init system: systemd
* Package manager: APT
* Initial release: 0.1.0-dev

## Build architecture

The build host runs the build scripts in an isolated environment.

The scripts bootstrap a Debian root filesystem, apply Sable configuration and prepare the system for packaging into a bootable image.

Generated files are kept separate from source code.

## Design principles

* Reproducible builds where practical.
* Minimal dependencies on the build host.
* Clear separation between source files and generated artifacts.
* Debian package compatibility.
* Independent Sable branding and configuration.

## Initial limitations

The first version is a Debian-derived distribution. It does not attempt to replace Debian's kernel, libc, compiler toolchain or package management infrastructure.
