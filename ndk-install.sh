#!/usr/bin/env bash

# -e: exits instantly if any command returns a non-zero status.
# -u: treat reference to unset variable as error.
# -o: returns exit when command fails
set -euo pipefail

# sets shell internal field separator to only newline and tab, fixing accidental word-splitting on spaces.
IFS=$'\n\t'

# ========== CREATER =============

# Script to install NDK into AndroidIDE
# Author MrIkso

#================================

# -------- Helpers --------
# Colors
RED="\033[31m"
GREEN="\033[32m"
YELLOW="\033[33m"
BLUE="\033[34m"
MAGENTA="\033[35m"
CYAN="\033[36m"
RESET="\033[0m"

# Add seperate echo fun for each type of actions allowing us to depict error and info in
# different colors , This also ensure proper logging of the script.
log() {
  echo -e "${GREEN}[INFO]${RESET} $*"
}

err() {
  echo -e "\n${RED}[ERROR]${RESET} $*\n" >&2
}

die() {
  echo -e "\n${RED}[CRITICAL ERROR]${RESET} $*\n${RED}[CRITICAL ERROR]${RESET} Script failed.\n" >&2
  cleanup
  exit 1
}

# -------- Configuration & defaults -------

INSTALL_DIR="${HOME}"                  # Set default install dir to HOME.
NDK_VERSION_DEFAULT="${NDK_VERSION:-}" # Set NDK_VERSION_DEFAULT to NDK_VERSION if its defined, otherwise use an empty string
NDK_URL="${NDK_URL:-}"                 # Set NDK_URL to NDK_URL if its defined, otherwise use an empty string.
ASSUME_YES=false                       # Name says it all. This just Assume you said yes like pkg i cocafire  -y
SHOW_HELP=false                        # Prints help message
ARCH_OVERRIDE="${ARCH:-}"              # Override your arch , helpful when you are not at aarch64 , script defaultly exits  if device is not aarch64.

PLATFORM="$(uname -s)-$(uname -m)" # Check if device is aarch64 or not.

# Determine SDK directory
# Checks if ANDROID_HOME  or ANDROID_SDK_ROOT exists , if it does ,set SDK_DIR to it.
# Otherwise set SDK_DIR to INSTALL_DIR/android-sdk folder.
# NOTE: Environment variable ANDROID_HOME is now deprecated by google so its only useful for old code.
if [ -n "${ANDROID_SDK_ROOT:-}" ] && [ -d "$ANDROID_SDK_ROOT" ]; then
  SDK_DIR="$ANDROID_SDK_ROOT"
elif [ -n "${ANDROID_HOME:-}" ] && [ -d "$ANDROID_HOME" ]; then
  SDK_DIR="$ANDROID_HOME"
else
  SDK_DIR="${INSTALL_DIR}/android-sdk"
  mkdir -p "${SDK_DIR}" || {
    err "Error: Failed to create SDK directory: ${SDK_DIR}"
    exit 1
  }
fi

# Check if device is aarch64 or not.
# If ARCH_OVERRIDE is set, override detected platform.
if [[ -n "$ARCH_OVERRIDE" ]]; then
  PLATFORM="$ARCH_OVERRIDE"
else
  case "$PLATFORM" in
  "Linux-aarch64") ;; # OK
  *)
    die "Unsupported platform: $PLATFORM"
    ;;
  esac
fi

# Create temporary working directory
WORKDIR="$(mktemp -d "${TMPDIR:-/tmp}/ndk-install.XXXXXX")" || die "Failed to create temporary folder"

# Define subfolders and ensure they exist
CMAKE_DIR="${SDK_DIR}/cmake"
NDK_BASE_DIR="${SDK_DIR}/ndk"

mkdir -p "$CMAKE_DIR"
mkdir -p "$NDK_BASE_DIR"

# Log everything selected.
log "Using SDK directory: $SDK_DIR"
log "CMake directory: $CMAKE_DIR"
log "NDK directory: $NDK_BASE_DIR"
log "Working directory: $WORKDIR"

ndk_dir=""
ndk_ver=""
ndk_ver_name=""
ndk_file_name=""
ndk_installed=false
cmake_installed=false
is_lzhiyong_ndk=false
is_bionic_ndk=false

# aria2c defaults for fast, safe downloads
ARIA2_OPTS=(
  --continue
  --max-connection-per-server=16
  --split=16
  --min-split-size=1M
  --timeout=5
  --retry-wait=3
  --max-tries=0
  --console-log-level=warn
)

# Track if script was interrupted by Ctrl+C (SIGINT) and mark it.
INTERRUPTED=false
trap 'INTERRUPTED=true' INT

# When work gets done this function ensures to clean the woekking directory.
cleanup() {
  if [ "${INTERRUPTED:-false}" = true ]; then
    err "Interrupted by user (Ctrl+C). Cleaning up..."
  else
    log "Cleaning up temporary directory..."
  fi

  if [ -d "$WORKDIR" ]; then
    rm -rf "$WORKDIR" || true
  fi
}

# Run cleanup on exit; if we were interrupted, exit with 130 after cleanup
trap 'cleanup; if [ "${INTERRUPTED:-false}" = true ]; then exit 130; fi' EXIT

# Usage guide.
usage() {
  cat <<EOF
Usage: $0 [options] [NDK_VERSION]

Install Android NDK and CMake for AndroidIDE on aarch64 platform.

Options:
  --url URL           Full URL to NDK archive (zip or tar.xz). If provided, overrides version mapping.
  --arch ARCH         Override architecture (linux-x86_64, linux-aarch64, etc.)
  --yes               Assume yes to all prompts (non-interactive mode)
  --help              Show this help message

NDK_VERSION can be one of: r17c, r18b, r19c, r20b, r21e, r22b, r23b, r24, r26b, r27b, r27d, r28c, r29

If both --url and NDK_VERSION are omitted, the script will run in interactive mode or use the NDK_VERSION environment variable.

Examples:
  $0 r27b                    # Install NDK r27b
  $0 --url https://...       # Install from custom URL
  $0 --yes r28c              # Install r28c without prompts
  NDK_VERSION=r29 $0 --yes   # Install r29 using env var

EOF
}

# NDK are big files , confirm from the users before user went to install the package.
confirm() {
  if [ "$ASSUME_YES" = true ]; then
    return 0
  fi
  printf "%s [y/N]: " "$1"
  read -r ans
  case "$ans" in
  [Yy] | [Yy][Ee][Ss]) return 0 ;;
  *) return 1 ;;
  esac
}

# Move function with just little bit of more safety.
safe_mv() {
  local src="$1" dir="$2"
  if [ -e "$dir" ]; then
    if [ "$ASSUME_YES" = true ]; then
      log "Directory already exists: $dir. Removing directory..."
      rm -rf "$dir"
    else
      die "Directory already exists: $dir. Remove or move it manually and retry."
    fi
  fi
  mv "$src" "$dir"
}

# Instead of always checking seperately, create a function for that (-Following DRY principals.))
ensure_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    die "Unable to locate command '$1'. Please install it and re-run."
  fi
}

# Checks if package is installed or not if its installed then return or else try to install it.
install_package() {
  local pkg="$1"
  log "$pkg not found. Trying to install..."

  if command -v pkg >/dev/null 2>&1; then # pkg is supported by androidide + termux
    pkg update -y && pkg install -y "$pkg"
  elif command -v apt >/dev/null 2>&1; then # same with apt .
    apt update -y && apt install -y "$pkg"
  else
    return 1 # error , unable to install package return status code 1.
  fi

  return 0 # else return code 0
}

# android ide comes installed with wget , tar and unzip .
# but still ensure if its installed or not.

# Check if aria2c is installed.
ensure_aria2c() {
  if command -v aria2c >/dev/null 2>&1; then
    return
  fi

  install_package aria2 || {
    err "Failed to install aria2c, fallback will use wget only."
  }
}

# Check if wget is installed.
ensure_wget() {
  if command -v wget >/dev/null 2>&1; then
    return
  fi

  install_package wget || {
    die "Failed to install wget. Unable to download ndk and cmake. Try installing wget or aria2c manually."
  }
}

# Check if unzip is installed.
ensure_unzip() {
  if command -v unzip >/dev/null 2>&1; then
    return
  fi

  install_package unzip || {
    die "Failed to install unzip."
  }
}

# Check if tar is installed.
ensure_tar() {
  if command -v tar >/dev/null 2>&1; then
    return
  fi

  install_package tar || {
    die "Failed to install tar."
  }
}

# Download File with safety.
download_with_fallback() {
  local output="$1"
  local url="$2"

  log "Downloading $output from $url"

  ensure_aria2c

  if command -v aria2c >/dev/null 2>&1; then
    aria2c "${ARIA2_OPTS[@]}" -o "$output" "$url" && [ -f "$output" ] && return
    err "aria2c failed, retrying with wget..."
  fi

  ensure_wget

  if command -v wget >/dev/null 2>&1; then
    wget "$url" -O "$output" --no-verbose --show-progress -c
    [ -f "$output" ] && return
  fi

  die "Download failed. Try installing wget or aria2c: pkg i wget aria2 -y"
}

# install cmake
install_all_cmake_versions() {
  log "Installing CMake versions..."
  local versions=("3.10.2" "3.18.1" "3.22.1" "3.25.1")

  # Intead of calling manually , call with for loop making room for future addition.
  for version in "${versions[@]}"; do
    download_and_unzip_cmake_files "$version"
  done
}

# download and unzip cmake together.
download_and_unzip_cmake_files() {
  local cmake_version=$1
  local file="cmake-$cmake_version-android-aarch64.zip"
  local url="https://github.com/MrIkso/AndroidIDE-NDK/releases/download/cmake/$file"

  log "Checking CMake $cmake_version..."

  cd "$WORKDIR" || die "Failed to change to working directory"

  download_with_fallback "$file" "$url"

  if [ -f "$file" ]; then
    log "Unziping CMake $cmake_version..."
    ensure_unzip

    unzip -qq "$file" -d "$CMAKE_DIR" || die "Failed to unzip CMake $cmake_version"
    rm "$file"

    # Set executable permissions for CMake files
    chmod -R +x "$CMAKE_DIR/$cmake_version/bin"
    cmake_installed=true
  else
    err "CMake zip file not found: $file"
  fi
}

download_ndk() {
  local file="$1"
  local url="$2"

  log "Downloading NDK file: $file"
  log "Checking available storage..."

  # Display how much storage is available .
  df -h "$INSTALL_DIR"

  cd "$WORKDIR" || die "Failed to go to working directory"
  download_with_fallback "$file" "$url"
}

# Just a helping function (this idea suggested by chatgpt to reduce bugs.)
change_directory() {
  cd "$1" || die "Failed to go directory to $1"
}

# Helps in creating symlinks (this one also chatgpt idea.)
create_symlink() {
  local target="$1"
  local link_name="$2"
  ln -sf "$target" "$link_name"
}

fix_ndk() {
  # Create missing symbolic links for standard NDK builds
  if [ ! -d "$ndk_dir" ]; then
    die "NDK directory does not exist: $ndk_dir"
  fi

  log "Creating missing symbolic links..."
  change_directory "$ndk_dir/toolchains/llvm/prebuilt"
  create_symlink "linux-aarch64" "linux-x86_64"

  change_directory "$ndk_dir/prebuilt"
  create_symlink "linux-aarch64" "linux-x86_64"

  change_directory "$INSTALL_DIR"

  # patching CMake config files
  log "patching CMake config files..."
  local CMAKE_PATCH='if(CMAKE_HOST_SYSTEM_NAME STREQUAL Android)\nset(ANDROID_HOST_TAG linux-aarch64)\nelseif(CMAKE_HOST_SYSTEM_NAME STREQUAL Linux)'
  sed -i "s/if(CMAKE_HOST_SYSTEM_NAME STREQUAL Linux)/$CMAKE_PATCH/g" "$ndk_dir"/build/cmake/android-legacy.toolchain.cmake
  sed -i "s/if(CMAKE_HOST_SYSTEM_NAME STREQUAL Linux)/$CMAKE_PATCH/g" "$ndk_dir"/build/cmake/android.toolchain.cmake
  ndk_installed=true
}

fix_ndk_bionic() {
  # Create missing symbolic links for bionic-based NDK builds
  if [ ! -d "$ndk_dir" ]; then
    die "NDK directory doesnt exist: $ndk_dir"
  fi

  log "Creating missing symbolic links for bionic NDK..."
  change_directory "$ndk_dir/toolchains/llvm/prebuilt"
  create_symlink "linux-arm64" "linux-aarch64"

  change_directory "$ndk_dir/prebuilt"
  create_symlink "linux-arm64" "linux-aarch64"

  change_directory "$ndk_dir/shader-tools"
  create_symlink "linux-arm64" "linux-aarch64"

  change_directory "$INSTALL_DIR"
  ndk_installed=true
}

untar_tar_files() {
  local tar_file="$1"
  local is_tarxz="$2"

  if [ ! -f "$tar_file" ]; then
    die "Tar file not found: $tar_file"
  fi

  log "Untaring tar file: $tar_file"

  if [ "$is_tarxz" = true ]; then
    ensure_tar
    tar --no-same-owner -xf "$tar_file" --warning=no-unknown-keyword || die "Failed to untar $tar_file"
  else
    ensure_unzip
    unzip -qq "$tar_file" || die "Failed to unzip $tar_file"
  fi

  rm -f "$tar_file"
}

get_ndk_versions() {
  local version="$1"

  case $version in
  r17c)
    ndk_ver="17.2.4988734"
    ndk_ver_name="r17c"
    ;;
  r18b)
    ndk_ver="18.1.5063045"
    ndk_ver_name="r18b"
    ;;
  r19c)
    ndk_ver="19.2.5345600"
    ndk_ver_name="r19c"
    ;;
  r20b)
    ndk_ver="20.1.5948944"
    ndk_ver_name="r20b"
    ;;
  r21e)
    ndk_ver="21.4.7075529"
    ndk_ver_name="r21e"
    ;;
  r22b)
    ndk_ver="22.1.7171670"
    ndk_ver_name="r22b"
    ;;
  r23b)
    ndk_ver="23.2.8568313"
    ndk_ver_name="r23b"
    ;;
  r24)
    ndk_ver="24.0.8215888"
    ndk_ver_name="r24"
    ;;
  r26b)
    ndk_ver="26.1.10909125"
    ndk_ver_name="r26b"
    is_lzhiyong_ndk=true
    ;;
  r27b)
    ndk_ver="27.1.12297006"
    ndk_ver_name="r27b"
    is_lzhiyong_ndk=true
    ;;
  r27d)
    ndk_ver="27.3.13750724"
    ndk_ver_name="r27d"
    is_bionic_ndk=true
    ;;
  r28c)
    ndk_ver="28.2.13676358"
    ndk_ver_name="r28c"
    is_bionic_ndk=true
    ;;
  r29)
    ndk_ver="29.0.14206865"
    ndk_ver_name="r29"
    is_bionic_ndk=true
    ;;
  *)
    die "NDK version not found: $version"
    ;;
  esac
}

select_ndk_download_url() {
  if [ -n "$NDK_URL" ]; then
    echo "$NDK_URL"
    return
  fi

  if [[ $is_bionic_ndk == true ]]; then
    local tag_name="$ndk_ver_name"
    case $ndk_ver_name in
    r27d) tag_name="r27" ;;
    r28c) tag_name="r28" ;;
    # r29) tag_name="r29" ;;
    esac
    echo "https://github.com/HomuHomu833/android-ndk-custom/releases/download/$tag_name/$ndk_file_name"
  elif [[ $is_lzhiyong_ndk == true ]]; then
    echo "https://github.com/MrIkso/AndroidIDE-NDK/releases/download/ndk/$ndk_file_name"
  else
    echo "https://github.com/jzinferno2/termux-ndk/releases/download/v1/$ndk_file_name"
  fi
}

remove_existing_installation() {
  local dir="$1"
  local name="$2"

  if [ ! -d "$dir" ]; then
    log "No already $name installation found."
    return
  fi

  log "Existing $name installation found: $dir"

  if [ "$ASSUME_YES" = false ]; then
    if ! confirm "Remove existing $name installation?"; then
      die "Unable to remove installed file! , user intervention."
    fi
  fi

  log "Removing existing $name..."
  rm -rf "$dir"

}

# Take commands from command line.
while [[ $# -gt 0 ]]; do
  case $1 in
  --url)
    NDK_URL="$2"
    shift 2
    ;;
  --arch)
    ARCH_OVERRIDE="$2"
    shift 2
    ;;
  --yes)
    ASSUME_YES=true
    shift
    ;;
  --help)
    usage
    exit 0
    ;;
  -*)
    err "Ooops! Invaild Option: $1"
    usage
    exit 1
    ;;
  *)
    NDK_VERSION_DEFAULT="$1" # select default version if user doesnt pass it from command line.
    shift
    ;;
  esac
done

# Select version if user doesnt specify it from command line.
if [ -z "$NDK_VERSION_DEFAULT" ] && [ -z "$NDK_URL" ]; then
  log "Select which NDK version you want to install:"

  select item in r17c r18b r19c r20b r21e r22b r23b r24 r26b r27b r27d r28c r29 Quit; do
    case $item in
    Quit)
      echo "Exiting..."
      exit 0
      ;;
    "")
      echo "Version not available. Please try again."
      ;;
    *)
      NDK_VERSION_DEFAULT="$item"
      break
      ;;
    esac
  done
fi

# Get NDK versions
if [ -n "$NDK_VERSION_DEFAULT" ]; then
  get_ndk_versions "$NDK_VERSION_DEFAULT"
fi

log "Selected NDK version: $ndk_ver_name ($ndk_ver) for installation"
log "Warning! This NDK is only for aarch64 architecture"

change_directory "$INSTALL_DIR"

# Set NDK file name and directory
ndk_dir="$NDK_BASE_DIR/$ndk_ver"
if [[ $is_bionic_ndk == true ]]; then
  ndk_file_name="android-ndk-$ndk_ver_name-aarch64-linux-android.tar.xz"
else
  ndk_file_name="android-ndk-$ndk_ver_name-aarch64.zip"
fi

# Remove existing installations
remove_existing_installation "$ndk_dir" "NDK $ndk_ver"
remove_existing_installation "$CMAKE_DIR" "CMake"

# Download NDK
ndk_url=$(select_ndk_download_url)
download_ndk "$ndk_file_name" "$ndk_url"

# extract NDK file
change_directory "$WORKDIR"
untar_tar_files "$ndk_file_name" "$is_bionic_ndk"

# Move untared NDK to Android SDK folder
mkdir -p "$NDK_BASE_DIR"
safe_mv "android-ndk-$ndk_ver_name" "$ndk_dir"

# fix ndk based on is bionic or not
if [[ $is_bionic_ndk == true ]]; then
  fix_ndk_bionic
elif [[ $is_lzhiyong_ndk == false ]]; then
  fix_ndk
else
  ndk_installed=true
fi

# Install CMake versions
mkdir -p "$CMAKE_DIR" || die "Failed to create CMake folder"
install_all_cmake_versions

# Check both installed correctly
if [[ $ndk_installed == true && $cmake_installed == true ]]; then
  log "Installation completed successfully! NDK and CMake is now installed."
  log "Please restart AndroidIDE or Termux."
else
  err "Installation failed! NDK and CMake not installed correctly. Please try again."
fi
