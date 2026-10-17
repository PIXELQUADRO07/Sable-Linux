#!/usr/bin/env bash
# ==============================================================================
# Sable Linux — Native Debian Package Builder (Milestone 17 & 25)
# ==============================================================================
# Builds sable-base, sable-branding, and sable-settings .deb packages.
# ==============================================================================
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd -- "${SCRIPT_DIR}/.." && pwd)"
PACKAGES_DIR="${PROJECT_ROOT}/packages"
OUTPUT_DIR="${PROJECT_ROOT}/build/packages"

show_help() {
    cat << EOF
Usage: $(basename "$0") [OPTIONS]

Options:
  -o, --output DIR   Output directory for generated .deb files (default: build/packages)
  -c, --clean        Clean output directory before building
  -h, --help         Show this help message

Builds native Debian packages from ${PACKAGES_DIR}.
EOF
}

CLEAN=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        -o|--output) OUTPUT_DIR="$2"; shift 2 ;;
        -c|--clean) CLEAN=true; shift ;;
        -h|--help) show_help; exit 0 ;;
        *) echo "Unknown option: $1" >&2; show_help >&2; exit 1 ;;
    esac
done

if [[ "${CLEAN}" == "true" ]]; then
    rm -rf "${OUTPUT_DIR}"
fi
mkdir -p "${OUTPUT_DIR}"

if ! command -v dpkg-deb >/dev/null 2>&1; then
    echo "Error: dpkg-deb is required to build Debian packages." >&2
    exit 1
fi

echo "=========================================================="
echo " 📦 Sable Linux — Building Native Debian Packages"
echo " Destination: ${OUTPUT_DIR}"
echo "=========================================================="

build_package() {
    local pkg_path="$1"
    local pkg_name
    pkg_name="$(basename "${pkg_path}")"
    local control_file="${pkg_path}/debian/control"
    local changelog_file="${pkg_path}/debian/changelog"
    local install_file="${pkg_path}/debian/install"

    if [[ ! -f "${control_file}" ]]; then
        echo "Skipping ${pkg_name}: no debian/control found."
        return 0
    fi

    local version="0.6.0-1"
    if [[ -f "${changelog_file}" ]]; then
        version="$(head -n1 "${changelog_file}" | sed -E 's/.*\((.*)\).*/\1/')"
    fi
    local arch="all"
    if grep -qE '^Architecture:' "${control_file}"; then
        arch="$(grep -E '^Architecture:' "${control_file}" | head -n1 | awk '{print $2}')"
    fi

    local deb_filename="${pkg_name}_${version}_${arch}.deb"
    echo "--> Building ${deb_filename}..."

    local stage_dir
    stage_dir="$(mktemp -d "/tmp/${pkg_name}-build.XXXXXX")"
    trap 'rm -rf "${stage_dir}"' RETURN

    mkdir -p "${stage_dir}/DEBIAN"

    # Process debian/control: extract the Package block
    # Debian control files contain a Source paragraph and one or more Package paragraphs.
    local maintainer="Sable Linux Project <https://github.com/PIXELQUADRO07/Sable-Linux>"
    if grep -qE '^Maintainer:' "${control_file}"; then
        maintainer="$(grep -E '^Maintainer:' "${control_file}" | head -n1 | sed -e 's/^Maintainer:[[:space:]]*//')"
    fi

    awk '
        BEGIN { in_pkg = 0 }
        /^Package:[[:space:]]*'"${pkg_name}"'/ { in_pkg = 1 }
        in_pkg && /^$/ { in_pkg = 0 }
        in_pkg { print }
    ' "${control_file}" > "${stage_dir}/DEBIAN/control"

    # Clean up debhelper variables not expanded without debhelper
    sed -i -e 's/\${misc:Depends},[[:space:]]*//g' \
           -e 's/,[[:space:]]*\${misc:Depends}//g' \
           -e 's/\${misc:Depends}//g' "${stage_dir}/DEBIAN/control"
    # Clean up any trailing/empty Depends line completely
    sed -i -e '/^Depends:[[:space:]]*$/d' "${stage_dir}/DEBIAN/control"

    # Add Version and Maintainer if missing in the binary block
    if ! grep -qE '^Version:' "${stage_dir}/DEBIAN/control"; then
        echo "Version: ${version}" >> "${stage_dir}/DEBIAN/control"
    fi
    if ! grep -qE '^Maintainer:' "${stage_dir}/DEBIAN/control"; then
        echo "Maintainer: ${maintainer}" >> "${stage_dir}/DEBIAN/control"
    fi

    # Copy files according to debian/install or folder structure
    if [[ -f "${install_file}" ]]; then
        while IFS= read -r line || [[ -n "${line}" ]]; do
            line="$(echo "${line}" | sed -e 's/#.*//' -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"
            [[ -z "${line}" ]] && continue
            local src dest
            src="$(echo "${line}" | awk '{print $1}')"
            dest="$(echo "${line}" | awk '{print $2}')"

            mkdir -p "${stage_dir}/${dest}"
            # Expand glob in pkg_path (including hidden dotfiles)
            (
                cd "${pkg_path}"
                shopt -s dotglob nullglob
                for f in ${src}; do
                    if [[ -e "${f}" ]]; then
                        cp -a "${f}" "${stage_dir}/${dest}/"
                    fi
                done
            )
        done < "${install_file}"
    else
        # Default copy: anything other than debian/
        for item in "${pkg_path}"/*; do
            local base
            base="$(basename "${item}")"
            [[ "${base}" == "debian" ]] && continue
            cp -a "${item}" "${stage_dir}/"
        done
    fi

    # Generate md5sums for package integrity
    (
        cd "${stage_dir}"
        find . -type f ! -path "./DEBIAN/*" -exec md5sum {} + | sed 's|\./||' > "${stage_dir}/DEBIAN/md5sums" 2>/dev/null || true
    )

    # Build .deb archive
    dpkg-deb --build --root-owner-group "${stage_dir}" "${OUTPUT_DIR}/${deb_filename}" >/dev/null

    echo "  ✓ Generated: ${OUTPUT_DIR}/${deb_filename} ($(du -h "${OUTPUT_DIR}/${deb_filename}" | cut -f1))"
}

for pkg_dir in "${PACKAGES_DIR}"/*; do
    if [[ -d "${pkg_dir}" ]]; then
        build_package "${pkg_dir}"
    fi
done

echo
echo "All Sable packages built successfully."
echo "=========================================================="
