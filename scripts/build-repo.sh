#!/usr/bin/env bash
# ==============================================================================
# Sable Linux — APT Repository Generator (Milestone 24)
# ==============================================================================
# Generates standard Debian APT repository metadata (Release, Packages.gz)
# from built .deb packages in build/packages/.
# ==============================================================================
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd -- "${SCRIPT_DIR}/.." && pwd)"
PACKAGES_DIR="${PROJECT_ROOT}/build/packages"
REPO_DIR="${PROJECT_ROOT}/build/repo"
SUITE="trixie"
CODENAME="Nightfall"
ORIGIN="Sable Linux"
LABEL="Sable"
ARCH="amd64"

REPO_URI="${SABLE_REPO_URI:-https://repo.sable-linux.org/}"
GPG_KEY="${SABLE_GPG_KEY:-}"

show_help() {
    cat << EOF
Usage: $(basename "$0") [OPTIONS]

Options:
  -p, --packages-dir DIR  Directory with built .deb files (default: build/packages)
  -o, --output-dir DIR    Repository target directory (default: build/repo)
  -s, --suite SUITE       Debian suite name (default: trixie)
  -u, --uri URI           Base repository URI for client .sources (default: https://repo.sable-linux.org/)
  -k, --key KEY_ID        GPG key ID to sign Release file (InRelease & Release.gpg)
  -h, --help              Show this help message

Builds an APT repository pool and metadata index.
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        -p|--packages-dir) PACKAGES_DIR="$2"; shift 2 ;;
        -o|--output-dir) REPO_DIR="$2"; shift 2 ;;
        -s|--suite) SUITE="$2"; shift 2 ;;
        -u|--uri) REPO_URI="$2"; shift 2 ;;
        -k|--key) GPG_KEY="$2"; shift 2 ;;
        -h|--help) show_help; exit 0 ;;
        *) echo "Unknown option: $1" >&2; show_help >&2; exit 1 ;;
    esac
done

# If no packages are built yet, invoke build-packages.sh
if [[ ! -d "${PACKAGES_DIR}" ]] || ! ls "${PACKAGES_DIR}"/*.deb >/dev/null 2>&1; then
    echo "Notice: No .deb files found in ${PACKAGES_DIR}. Building packages now..."
    "${SCRIPT_DIR}/build-packages.sh" -o "${PACKAGES_DIR}"
fi

echo "=========================================================="
echo " 🌐 Sable Linux — Generating APT Repository"
echo " Suite: ${SUITE} | Target: ${REPO_DIR}"
echo "=========================================================="

POOL_DIR="${REPO_DIR}/pool/main"
DIST_DIR="${REPO_DIR}/dists/${SUITE}/main/binary-${ARCH}"
mkdir -p "${POOL_DIR}" "${DIST_DIR}"

# Copy deb files to pool
cp -u "${PACKAGES_DIR}"/*.deb "${POOL_DIR}/" 2>/dev/null || cp "${PACKAGES_DIR}"/*.deb "${POOL_DIR}/"

python3 - << PYEOF
import os
import sys
import hashlib
import gzip
import subprocess
from datetime import datetime, timezone

packages_dir = "${PACKAGES_DIR}"
pool_dir = "${POOL_DIR}"
dist_dir = "${DIST_DIR}"
repo_dir = "${REPO_DIR}"
suite = "${SUITE}"
codename = "${CODENAME}"
origin = "${ORIGIN}"
label = "${LABEL}"
arch = "${ARCH}"

deb_files = sorted([f for f in os.listdir(pool_dir) if f.endswith('.deb')])
if not deb_files:
    print("Error: No .deb files found in pool directory.", file=sys.stderr)
    sys.exit(1)

packages_content = []

for deb_name in deb_files:
    deb_path = os.path.join(pool_dir, deb_name)
    rel_path = os.path.relpath(deb_path, repo_dir)
    file_size = os.path.getsize(deb_path)

    with open(deb_path, 'rb') as f:
        data = f.read()
        md5 = hashlib.md5(data).hexdigest()
        sha1 = hashlib.sha1(data).hexdigest()
        sha256 = hashlib.sha256(data).hexdigest()

    # Extract control info via dpkg-deb
    res = subprocess.run(['dpkg-deb', '-f', deb_path], stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, check=True)
    control_text = res.stdout.strip()

    entry = f"{control_text}\nFilename: {rel_path}\nSize: {file_size}\nMD5sum: {md5}\nSHA1: {sha1}\nSHA256: {sha256}\n"
    packages_content.append(entry)

full_packages = "\n".join(packages_content) + "\n"

# Write Packages and Packages.gz
packages_path = os.path.join(dist_dir, "Packages")
with open(packages_path, "w", encoding="utf-8") as f:
    f.write(full_packages)

packages_gz_path = os.path.join(dist_dir, "Packages.gz")
with gzip.open(packages_gz_path, "wb") as f:
    f.write(full_packages.encode("utf-8"))

print(f"  ✓ Indexed {len(deb_files)} packages into Packages and Packages.gz")

# Generate Release file
release_dir = os.path.join(repo_dir, "dists", suite)
release_path = os.path.join(release_dir, "Release")
date_str = datetime.now(timezone.utc).strftime("%a, %d %b %Y %H:%M:%S UTC")

# Collect hashes of indexed files inside dists/suite
index_files = [
    os.path.join("main", f"binary-{arch}", "Packages"),
    os.path.join("main", f"binary-{arch}", "Packages.gz"),
]

md5_lines = []
sha1_lines = []
sha256_lines = []

for rel_f in index_files:
    abs_f = os.path.join(release_dir, rel_f)
    if os.path.exists(abs_f):
        sz = os.path.getsize(abs_f)
        with open(abs_f, "rb") as f:
            d = f.read()
            md5_lines.append(f" {hashlib.md5(d).hexdigest()} {sz} {rel_f}")
            sha1_lines.append(f" {hashlib.sha1(d).hexdigest()} {sz} {rel_f}")
            sha256_lines.append(f" {hashlib.sha256(d).hexdigest()} {sz} {rel_f}")

release_content = f"""Origin: {origin}
Label: {label}
Suite: {suite}
Codename: {codename}
Date: {date_str}
Architectures: {arch}
Components: main
Description: Sable Linux Official Package Repository
MD5Sum:
""" + "\n".join(md5_lines) + "\nSHA1:\n" + "\n".join(sha1_lines) + "\nSHA256:\n" + "\n".join(sha256_lines) + "\n"

with open(release_path, "w", encoding="utf-8") as f:
    f.write(release_content)

print(f"  ✓ Generated Release file at {release_path}")
PYEOF

RELEASE_FILE="${REPO_DIR}/dists/${SUITE}/Release"

# Sign Release file if GPG key is specified
if [[ -n "${GPG_KEY}" ]] && command -v gpg >/dev/null 2>&1; then
    echo "--> Signing Release file with GPG key: ${GPG_KEY}..."
    rm -f "${REPO_DIR}/dists/${SUITE}/InRelease" "${REPO_DIR}/dists/${SUITE}/Release.gpg"
    gpg --default-key "${GPG_KEY}" --clearsign -o "${REPO_DIR}/dists/${SUITE}/InRelease" "${RELEASE_FILE}" || true
    gpg --default-key "${GPG_KEY}" -abs -o "${REPO_DIR}/dists/${SUITE}/Release.gpg" "${RELEASE_FILE}" || true
    gpg --export "${GPG_KEY}" > "${REPO_DIR}/sable-archive-keyring.gpg" 2>/dev/null || true
    echo "  ✓ Generated InRelease and Release.gpg"
fi

# Create client source list template
cat > "${REPO_DIR}/sable.sources" << EOF
Types: deb
URIs: ${REPO_URI}
Suites: ${SUITE}
Components: main
Signed-By: /usr/share/keyrings/sable-archive-keyring.gpg
EOF

# Create local test sources configuration (for offline / test usage)
cat > "${REPO_DIR}/sable-local.sources" << EOF
Types: deb
URIs: file://${REPO_DIR}
Suites: ${SUITE}
Components: main
Trusted: yes
EOF

echo
echo "APT repository generated successfully."
echo "Root: ${REPO_DIR}"
echo "=========================================================="
