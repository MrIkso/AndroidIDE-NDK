#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

# Script to install NDK into AndroidIDE
# Author MrIkso

# -------- Helpers --------
# Colors
RED="\033[31m"
GREEN="\033[32m"
YELLOW="\033[33m"
BLUE="\033[34m"
MAGENTA="\033[35m"
CYAN="\033[36m"
RESET="\033[0m"

log() {
  echo -e "${GREEN}[INFO]${RESET} $*"
}

err() {
  echo -e "\n${RED}[ERROR]${RESET} $*\n" >&2
}

die() {
  echo -e "\n${RED}[CRITICAL ERROR]${RESET} $*\n${RED}[CRITICAL ERROR]${RESET} Script failed.\n" >&2
  exit 1
}

# -------- Configuration & defaults --------
INSTALL_DIR="${HOME}"

# For commandline uses. Will add later.
# NDK_VERSION_DEFAULT="${NDK_VERSION:-}"
# NDK_URL="${NDK_URL:-}"
# DRY_RUN=false
# ASSUME_YES=false
# SHOW_HELP=false
# ARCH_OVERRIDE="${ARCH:-}"

PLATFORM="$(uname -s)-$(uname -m)"

# Determine SDK directory
if [ -n "${ANDROID_HOME:-}" ] && [ -d "$ANDROID_HOME" ]; then
  SDK_DIR="$ANDROID_HOME"
elif [ -n "${ANDROID_SDK_ROOT:-}" ] && [ -d "$ANDROID_SDK_ROOT" ]; then
  SDK_DIR="$ANDROID_SDK_ROOT"
else
  SDK_DIR="${INSTALL_DIR}/android-sdk"
  mkdir -p "${SDK_DIR}" || {
    err "Error: Failed to create SDK directory: ${SDK_DIR}"
    exit 1
  }
fi

case "$PLATFORM" in
"Linux-aarch64") ;; # OK
*)
  die "Unsupported platform: $PLATFORM"
  ;;
esac

DEST_NDK_DIR="${SDK_DIR}/ndk"

# This requires to setup temporary directory , setup it to use it.
# Using without adding tmp directory will cause
# Error : "mktemp: failed to create directory via template ‘/tmp/ndk-install.XXXXXX’: No such file or directory"
# WORKDIR="$(mktemp -d /tmp/ndk-install.XXXXXX)" # Create tmp directory to store downloaded ndk then move to target location.

# Define subdirectories and ensure they exist
CMAKE_DIR="${SDK_DIR}/cmake"
NDK_BASE_DIR="${SDK_DIR}/ndk"

mkdir -p "$CMAKE_DIR"
mkdir -p "$NDK_BASE_DIR"

log "Using SDK directory: $SDK_DIR"
log "CMake directory: $CMAKE_DIR"
log "NDK directory: $NDK_BASE_DIR"

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

# This Code requires setup , currently in developmet.

# Requires setup of WORKDIR
# cleanup() {
#   if [ -d "$WORKDIR" ]; then
#     rm -rf "$WORKDIR" || true
#   fi
# }
# trap cleanup EXIT

# usage() {
#   cat <<EOF
# Usage: $0 [options] [NDK_VERSION]
# Options:
#   --url URL           Full URL to NDK archive (zip or tar.xz). If provided, overrides version mapping.
#   --arch ARCH         Override architecture (linux-x86_64, linux-aarch64, etc.)
#   --yes               Assume yes (non-interactive)
#   --dry-run           Show actions but don't download or install
#   --help              Show this help
# If both --url and NDK_VERSION are omitted, the script will attempt to use NDK_VERSION env var.
# EOF
# }
#
# confirm() {
#   if [ "$ASSUME_YES" = true ]; then
#     return 0
#   fi
#   printf "%s [y/N]: " "$1"
#   read -r ans
#   case "$ans" in
#     [Yy]|[Yy][Ee][Ss]) return 0 ;;
#     *) return 1 ;;
#   esac
# }
#
# safe_mv() {
#   local src="$1" dst="$2"
#   if [ -e "$dst" ]; then
#     die "Destination exists: $dst. Remove or move it manually and retry."
#   fi
#   mv "$src" "$dst"
# }

ensure_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    die "Required command '$1' not found. Please install it and re-run."
  fi
}

ensure_aria2c() {
  if command -v aria2c >/dev/null 2>&1; then
    :
  else
    log "aria2c not found. Attempting to install..."

    if command -v pkg >/dev/null 2>&1; then
      pkg update -y && pkg install -y aria2
    elif command -v apt >/dev/null 2>&1; then
      apt update -y && apt install -y aria2
    elif command -v apk >/dev/null 2>&1; then
      apk add aria2
    elif command -v pacman >/dev/null 2>&1; then
      pacman -Sy --noconfirm aria2
    fi

    if ! command -v aria2c >/dev/null 2>&1; then
      err "Failed to install aria2c, fallback will use wget only."
    fi
  fi
}

ensure_wget() {
  if command -v wget >/dev/null 2>&1; then
    return
  fi

  log "wget not found. Attempting to install..."

  if command -v pkg >/dev/null 2>&1; then
    pkg update -y && pkg install -y wget
  elif command -v apt >/dev/null 2>&1; then
    apt update -y && apt install -y wget
  elif command -v apk >/dev/null 2>&1; then
    apk add wget
  elif command -v pacman >/dev/null 2>&1; then
    pacman -Sy --noconfirm wget
  fi

  if ! command -v wget >/dev/null 2>&1; then
    die "Failed to install wget. Downloads may fail. Try installing wget or aria2c manually."
  fi
}

ensure_unzip() {
  if command -v unzip >/dev/null 2>&1; then
    return
  fi

  log "unzip not found. Attempting to install..."

  if command -v pkg >/dev/null 2>&1; then
    pkg update -y && pkg install -y unzip
  elif command -v apt >/dev/null 2>&1; then
    apt update -y && apt install -y unzip
  elif command -v apk >/dev/null 2>&1; then
    apk add unzip
  elif command -v pacman >/dev/null 2>&1; then
    pacman -Sy --noconfirm unzip
  fi

  if ! command -v unzip >/dev/null 2>&1; then
    die "Failed to install unzip."
  fi
}

ensure_tar() {
  if command -v tar >/dev/null 2>&1; then
    return
  fi

  log "tar not found. Attempting to install..."

  if command -v pkg >/dev/null 2>&1; then
    pkg update -y && pkg install -y tar
  elif command -v apt >/dev/null 2>&1; then
    apt update -y && apt install -y tar
  elif command -v apk >/dev/null 2>&1; then
    apk add tar
  elif command -v pacman >/dev/null 2>&1; then
    pacman -Sy --noconfirm tar
  fi

  if ! command -v tar >/dev/null 2>&1; then
    die "Failed to install tar."
  fi
}

download_with_fallback() {
  local output="$1"
  local url="$2"

  log "Downloading: $output"
  log "URL: $url"

  ensure_aria2c

  if command -v aria2c >/dev/null 2>&1; then
    aria2c "${ARIA2_OPTS[@]}" -o "$output" "$url"
    if [ $? -eq 0 ] && [ -f "$output" ]; then
      return
    fi
    err "aria2c failed, retrying with wget..."
  fi

  ensure_wget

  if command -v wget >/dev/null 2>&1; then
    wget "$url" -O "$output" --no-verbose --show-progress -N

    if [ ! -f "$output" ]; then
      err "Download failed: $output"
      return 1
    fi
  fi

  die "Try Installing Wget or Aria2c : pkg i wget aria2 -y"
}

run_install_cmake() {
  log "Attempting to download cmake..."
  download_cmake 3.10.2
  download_cmake 3.18.1
  download_cmake 3.22.1
  download_cmake 3.25.1
}

download_cmake() {
  # download cmake with fallback to ensure , its downloaded correctly..
  cmake_version=$1
  local file="cmake-$cmake_version-android-aarch64.zip"
  local url="https://github.com/MrIkso/AndroidIDE-NDK/releases/download/cmake/$file"

  log "Downloading cmake-$cmake_version..."
  download_with_fallback "$file" "$url"

  installing_cmake "$cmake_version"
}

download_ndk() {
  local file="$1"
  local url="$2"

  log "Downloading NDK $file..."

  log "Checking storage available...\n"
  df -h "$INSTALL_DIR"
  echo -e "\n"

  download_with_fallback "$file" "$url"
}

fix_ndk() {
  # create missing link
  # Use ln -sf , this overrides already available links if it exists.
  if [ -d "$ndk_dir" ]; then
    log "Creating missing links..."
    cd "$ndk_dir/toolchains/llvm/prebuilt" || exit
    ln -sf "linux-aarch64" "linux-x86_64"
    cd "$ndk_dir/prebuilt" || exit
    ln -sf "linux-aarch64" "linux-x86_64"
    cd "$INSTALL_DIR" || exit

    # patching cmake config
    log "Patching cmake configs..."
    sed -i 's/if(CMAKE_HOST_SYSTEM_NAME STREQUAL Linux)/if(CMAKE_HOST_SYSTEM_NAME STREQUAL Android)\nset(ANDROID_HOST_TAG linux-aarch64)\nelseif(CMAKE_HOST_SYSTEM_NAME STREQUAL Linux)/g' "$ndk_dir"/build/cmake/android-legacy.toolchain.cmake
    sed -i 's/if(CMAKE_HOST_SYSTEM_NAME STREQUAL Linux)/if(CMAKE_HOST_SYSTEM_NAME STREQUAL Android)\nset(ANDROID_HOST_TAG linux-aarch64)\nelseif(CMAKE_HOST_SYSTEM_NAME STREQUAL Linux)/g' "$ndk_dir"/build/cmake/android.toolchain.cmake
    ndk_installed=true
  else
    err "NDK does not exist."
  fi
}

fix_ndk_bionic() {
  # create missing link
  if [ -d "$ndk_dir" ]; then
    log "Creating missing links..."
    cd "$ndk_dir/toolchains/llvm/prebuilt" || exit
    ln -sf "linux-arm64" "linux-aarch64"
    cd "$ndk_dir/prebuilt" || exit
    ln -sf "linux-arm64" "linux-aarch64"
    cd "$ndk_dir/shader-tools" || exit
    ln -sf "linux-arm64" "linux-aarch64"
    ndk_installed=true
  else
    err "NDK does not exist."
  fi
}

installing_cmake() {
  cmake_version=$1
  cmake_file=cmake-"$cmake_version"-android-aarch64.zip
  # unzip cmake
  if [ -f "$cmake_file" ]; then
    log "Unziping cmake..."

    log "Checking if unzip already exists..."

    ensure_unzip

    if command -v unzip >/dev/null 2>&1; then
      unzip -qq "$cmake_file" -d "$CMAKE_DIR"
    else
      die "Unable to unzip $cmake_file. Command failed. Try installing tar and unzip : pkg i unzip tar -y"
    fi

    log "Removing unused file $cmake_file..."
    rm "$cmake_file"

    # set executable permission for cmake
    chmod -R +x "$CMAKE_DIR"/"$cmake_version"/bin

    cmake_installed=true
  else
    err "$cmake_file does not exist."
  fi
}

log "Select which NDK version you need install?"

select item in r17c r18b r19c r20b r21e r22b r23b r24 r26b r27b r27d r28c r29 Quit; do
  case $item in
  "r17c")
    ndk_ver="17.2.4988734"
    ndk_ver_name="r17c"
    break
    ;;
  "r18b")
    ndk_ver="18.1.5063045"
    ndk_ver_name="r18b"
    break
    ;;
  "r19c")
    ndk_ver="19.2.5345600"
    ndk_ver_name="r19c"
    break
    ;;
  "r20b")
    ndk_ver="20.1.5948944"
    ndk_ver_name="r20b"
    break
    ;;
  "r21e")
    ndk_ver="21.4.7075529"
    ndk_ver_name="r21e"
    break
    ;;
  "r22b")
    ndk_ver="22.1.7171670"
    ndk_ver_name="r22b"
    break
    ;;
  "r23b")
    ndk_ver="23.2.8568313"
    ndk_ver_name="r23b"
    break
    ;;
  "r24")
    ndk_ver="24.0.8215888"
    ndk_ver_name="r24"
    break
    ;;
  "r26b")
    ndk_ver="26.1.10909125"
    ndk_ver_name="r26b"
    is_lzhiyong_ndk=true
    break
    ;;
  "r27b")
    ndk_ver="27.1.12297006"
    ndk_ver_name="r27b"
    is_lzhiyong_ndk=true
    break
    ;;
  "r27d")
    ndk_ver="27.3.13750724"
    ndk_ver_name="r27d"
    is_bionic_ndk=true
    break
    ;;
  "r28c")
    ndk_ver="28.2.13676358"
    ndk_ver_name="r28c"
    is_bionic_ndk=true
    break
    ;;
  "r29")
    ndk_ver="29.0.14206865"
    ndk_ver_name="r29"
    is_bionic_ndk=true
    break
    ;;
  "Quit")
    echo "Exit.."
    exit
    ;;
  *)
    echo "Ooops"
    ;;
  esac
done

log "Selected ndk version: $ndk_ver_name ($ndk_ver) to install"
log 'Warning! This NDK only for aarch64'
cd "$INSTALL_DIR" || exit
# checking if previous installed NDK and cmake

ndk_dir="$NDK_BASE_DIR/$ndk_ver"
if [[ $is_bionic_ndk == true ]]; then
  ndk_file_name="android-ndk-$ndk_ver_name-aarch64-linux-android.tar.xz"
else
  ndk_file_name="android-ndk-$ndk_ver_name-aarch64.zip"
fi

if [ -d "$ndk_dir" ]; then
  log "$ndk_dir exists. Deleting NDK $ndk_ver..."
  rm -rf "$ndk_dir"
else
  err "NDK does not exists."
fi

if [ -d "$CMAKE_DIR" ]; then
  log "$CMAKE_DIR exists. Deleting cmake folder..."
  rm -rf "$CMAKE_DIR"
fi

if [[ $is_bionic_ndk == true ]]; then
  tag_name=""
  case $ndk_ver_name in
  "r27d")
    tag_name="r27"
    ;;
  "r28c")
    tag_name="r28"
    ;;
  #"r29")
  #    tag_name="r29"
  #    ;;
  *)
    tag_name="$ndk_ver_name"
    ;;
  esac
  download_ndk "$ndk_file_name" "https://github.com/HomuHomu833/android-ndk-custom/releases/download/$tag_name/$ndk_file_name"
elif [[ $is_lzhiyong_ndk == true ]]; then
  download_ndk "$ndk_file_name" "https://github.com/MrIkso/AndroidIDE-NDK/releases/download/ndk/$ndk_file_name"
else
  download_ndk "$ndk_file_name" "https://github.com/jzinferno2/termux-ndk/releases/download/v1/$ndk_file_name"
fi

if [ -f "$ndk_file_name" ]; then
  log "Unpacking NDK $ndk_ver_name..."
  if [[ $is_bionic_ndk == true ]]; then
    # bionic-style is a tar.xz archive
    log "Checking if tar already exists..."
    ensure_tar

    if command -v tar >/dev/null 2>&1; then
      tar --no-same-owner -xf "$ndk_file_name" --warning=no-unknown-keyword
    else
      die "Unpacking NDK $ndk_ver_name failed. 'tar' not found. Install tar (e.g. pkg i tar) and try again."
    fi
  else
    # standard NDK is a zip archive
    log "Checking if unzip already exists..."
    ensure_unzip

    if command -v unzip >/dev/null 2>&1; then
      unzip -qq "$ndk_file_name"
    else
      die "Unpacking NDK $ndk_file_name failed. 'unzip' not found. Install unzip (e.g. pkg i unzip) and try again."
    fi
  fi

  log "Removing downloaded archive..."
  rm -f "$ndk_file_name"

  # moving NDK to Android SDK directory
  if [ -d "$NDK_BASE_DIR" ]; then
    mv "android-ndk-$ndk_ver_name" "$ndk_dir"
  else
    log "NDK base dir does not exist. Creating..."
    mkdir -p "$NDK_BASE_DIR"
    mv "android-ndk-$ndk_ver_name" "$ndk_dir"
  fi

  if [[ $is_bionic_ndk == true ]]; then
    fix_ndk_bionic
  elif [[ $is_lzhiyong_ndk == false ]]; then
    fix_ndk
  else
    ndk_installed=true
  fi

else
  die "$ndk_file_name does not exist."
fi

if [ -d "$CMAKE_DIR" ]; then
  cd "$CMAKE_DIR"
  run_install_cmake
else
  mkdir -p "$CMAKE_DIR"
  cd "$CMAKE_DIR"
  run_install_cmake
fi

if [[ $ndk_installed == true && $cmake_installed == true ]]; then
  log 'Installation Finished. NDK has been installed successfully, please restart AndroidIDE!'
else
  err 'NDK and cmake failed to install! Try Again'
fi
