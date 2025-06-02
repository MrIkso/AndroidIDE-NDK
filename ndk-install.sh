#!/bin/bash

# Script to install NDK into AndroidIDE
# Author MrIkso

install_dir=$HOME
sdk_dir=$install_dir/android-sdk
cmake_dir=$sdk_dir/cmake
ndk_base_dir=$sdk_dir/ndk

ndk_dir=""
ndk_ver=""
ndk_ver_name=""
ndk_file_name=""
ndk_installed=false
cmake_installed=false
is_lzhiyong_ndk=false
is_musl_ndk=false
if [[ "$arch" == "armv8l" || "$arch" == "armv7l" || "$arch" == "armv7" ]]; then
    is_armv7=true
else
    is_armv7=false
fi

run_install_cmake() {
        echo "Select with CMake version you need install?"
	echo "Notice: Only 3.30.3 and upper supported for ARM."
	select item in "3.10.2" "3.18.1" "3.22.1" "3.25.1" "3.30.3" "3.30.4" "3.30.5" "3.31.0" "3.31.1" "3.31.4" "3.31.5" "3.31.6" "4.0.2" Quit; do
 	case $item in
		"3.10.2")
			cmake_ver="3.10.2"
   			is_musl_cmake=false
			break
			;;
		"3.18.1")
			cmake_ver="3.18.1"
   			is_musl_cmake=false
			break
			;;
		"3.22.1")
			cmake_ver="3.22.1"
   			is_musl_cmake=false
			break
			;;
		"3.25.1")
			cmake_ver="3.25.1"
   			is_musl_cmake=false
			break
			;;
		"3.30.3")
			cmake_ver="3.30.3"
   			is_musl_cmake=true
			break
			;;
		"3.30.4")
			cmake_ver="3.30.4"
   			is_musl_cmake=true
			break
			;;
		"3.30.5")
			cmake_ver="3.30.5"
   			is_musl_cmake=true
			break
			;;
		"3.31.0")
			cmake_ver="3.31.0"
   			is_musl_cmake=true
			break
			;;
		"3.31.1")
			cmake_ver="3.31.1"
   			is_musl_cmake=true
			break
			;;
	  	"3.31.4")
			cmake_ver="3.31.4"
   			is_musl_cmake=true
			break
			;;
	  	"3.31.5")
			cmake_ver="3.31.5"
   			is_musl_cmake=true
			break
			;;
	  	"3.31.6")
			cmake_ver="3.31.6"
   			is_musl_cmake=true
			break
			;;
		"4.0.2")
			cmake_ver="4.0.2"
   			is_musl_cmake=true
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

 	echo "Selected this version $cmake_ver to install"
  
  	if [ -d "$cmake_dir/$cmake_ver" ]; then
		echo "$cmake_ver exists. Deleting CMake $cmake_ver..."
		rm -rf "$cmake_dir/$cmake_ver"
	else
		echo "CMake does not exists."
	fi
	
	download_cmake $cmake_ver $is_musl_cmake
}

download_cmake() {
    cmake_version=$1
    is_musl_cmake=$2

    if [ "$is_musl_cmake" = true ]; then
        if [ "$is_armv7" = true ]; then
            wget "https://github.com/HomuHomu833/cmake-zig/releases/download/$cmake_version/cmake-arm-linux-musleabihf.tar.xz" \
                --no-verbose --show-progress -N
        else
            wget "https://github.com/HomuHomu833/cmake-zig/releases/download/$cmake_version/cmake-aarch64-linux-musl.tar.xz" \
                --no-verbose --show-progress -N
        fi
    else
        wget "https://github.com/MrIkso/AndroidIDE-NDK/releases/download/cmake/cmake-$cmake_version-android-aarch64.zip" \
            --no-verbose --show-progress -N
    fi

    installing_cmake "$cmake_version" $2
}

download_ndk() {
	# download NDK
	echo "Downloading NDK $1..."
	wget $2 --no-verbose --show-progress -N
}

fix_ndk() {
	# create missing link
	if [ -d "$ndk_dir" ]; then
		echo "Creating missing links..."
		cd "$ndk_dir"/toolchains/llvm/prebuilt || exit
		ln -s linux-aarch64 linux-x86_64
		cd "$ndk_dir"/prebuilt || exit
		ln -s linux-aarch64 linux-x86_64
		cd "$install_dir" || exit

		# patching cmake config
		echo "Patching cmake configs..."
		sed -i 's/if(CMAKE_HOST_SYSTEM_NAME STREQUAL Linux)/if(CMAKE_HOST_SYSTEM_NAME STREQUAL Android)\nset(ANDROID_HOST_TAG linux-aarch64)\nelseif(CMAKE_HOST_SYSTEM_NAME STREQUAL Linux)/g' "$ndk_dir"/build/cmake/android-legacy.toolchain.cmake
		sed -i 's/if(CMAKE_HOST_SYSTEM_NAME STREQUAL Linux)/if(CMAKE_HOST_SYSTEM_NAME STREQUAL Android)\nset(ANDROID_HOST_TAG linux-aarch64)\nelseif(CMAKE_HOST_SYSTEM_NAME STREQUAL Linux)/g' "$ndk_dir"/build/cmake/android.toolchain.cmake
		ndk_installed=true
	else
		echo "NDK does not exists."
	fi
}

fix_ndk_musl() {
	# create missing link
	if [ "$is_armv7" == "true" ]; then
		ndk_arch="arm"
	else
		ndk_arch="arm64"
	fi
	if [ -d "$ndk_dir" ]; then
		cd "$ndk_dir/toolchains/llvm/prebuilt" || exit
		ln -s "linux-$ndk_arch" linux-aarch64
		cd "$ndk_dir/prebuilt" || exit
		ln -s "linux-$ndk_arch" linux-aarch64
		cd "$ndk_dir/shader-tools" || exit
		ln -s "linux-$ndk_arch" linux-aarch64
		ndk_installed=true
	else
		echo "NDK does not exists."
	fi
}

installing_cmake() {
    cmake_version=$1
    is_musl_cmake=$2

    echo "Unziping cmake..."

    if [ "$is_musl_cmake" = true ]; then
        if [ "$is_armv7" = true ]; then
            cmake_file="cmake-arm-linux-musleabihf.tar.xz"
        else
            cmake_file="cmake-aarch64-linux-musl.tar.xz"
        fi

        if [ -f "$cmake_file" ]; then
            tar --no-same-owner --warning=no-unknown-keyword -xf "$cmake_file"
            rm "$cmake_file"
            mv "$cmake_version" "$cmake_dir"
            chmod -R +x "$cmake_dir/$cmake_version/bin"
            cmake_installed=true
        else
            echo "$cmake_file does not exists."
        fi
    else
        cmake_file="cmake-$cmake_version-android-aarch64.zip"
        if [ -f "$cmake_file" ]; then
            unzip -qq "$cmake_file"
            rm "$cmake_file"
            mv "$cmake_version" "$cmake_dir"
            chmod -R +x "$cmake_dir/$cmake_version/bin"
            cmake_installed=true
        else
            echo "$cmake_file does not exists."
        fi
    fi
}

echo "Select with NDK version you need install?"
echo "Notice: Only r27c and upper supported for ARM."
select item in r17c r18b r19c r20b r21e r22b r23b r24 r26b r27b r27c r28b r29-beta1 Skip Quit; do
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
  	"r27c")
		ndk_ver="27.2.12479018"
		ndk_ver_name="r27c"
		is_musl_ndk=true
		break
		;;
  	"r28b")
		ndk_ver="28.1.13356709"
		ndk_ver_name="r28b"
		is_musl_ndk=true
		break
		;;
	"r29-beta1")
		ndk_ver="29.0.13113456"
		ndk_ver_name="r29-beta1"
		is_musl_ndk=true
		break
		;;
  	"Skip")
		echo "Skiping.."
		if [ -d "$cmake_dir" ]; then
			cd "$cmake_dir"
			run_install_cmake
		else
			mkdir -p "$cmake_dir"
			cd "$cmake_dir"
			run_install_cmake
		fi
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

arch=$(uname -m)

echo "Selected this version $ndk_ver_name ($ndk_ver) to install"
cd "$install_dir" || exit
# checking if previous installed NDK and cmake

ndk_dir="$ndk_base_dir/$ndk_ver"
if [[ "$is_musl_ndk" == true ]]; then
    if [[ "$is_armv7" == true ]]; then
        ndk_file_name="android-ndk-$ndk_ver_name-arm-linux-musleabihf.tar.xz"
    else
        ndk_file_name="android-ndk-$ndk_ver_name-aarch64-linux-musl.tar.xz"
    fi
else
    ndk_file_name="android-ndk-$ndk_ver_name-aarch64.zip"
fi

if [ -d "$ndk_dir" ]; then
	echo "$ndk_dir exists. Deleting NDK $ndk_ver..."
	rm -rf "$ndk_dir"
else
	echo "NDK does not exists."
fi

if [[ $is_musl_ndk == true ]]; then
	download_ndk "$ndk_file_name" "https://github.com/HomuHomu833/android-ndk-custom/releases/download/$ndk_ver_name/$ndk_file_name"
elif [[ $is_lzhiyong_ndk == true ]]; then
	download_ndk "$ndk_file_name" "https://github.com/MrIkso/AndroidIDE-NDK/releases/download/ndk/$ndk_file_name"
else
	download_ndk "$ndk_file_name" "https://github.com/jzinferno2/termux-ndk/releases/download/v1/$ndk_file_name"
fi

if [ -f "$ndk_file_name" ]; then
	echo "Unziping NDK $ndk_ver_name..."
	if [[ $is_musl_ndk == true ]]; then
		tar --no-same-owner -xf "$ndk_file_name" --warning=no-unknown-keyword
	else
		unzip -qq "$ndk_file_name"
	fi
	rm $ndk_file_name

	# moving NDK to Android SDK directory
	if [ -d "$ndk_base_dir" ]; then
		mv android-ndk-$ndk_ver_name "$ndk_dir"
	else
		echo "NDK base dir does not exists. Creating..."
		mkdir -p "$sdk_dir"/ndk
		mv android-ndk-$ndk_ver_name "$ndk_dir"
	fi

	if [[ $is_musl_ndk == true ]]; then
    		fix_ndk_musl
	elif [[ $is_lzhiyong_ndk == false ]]; then
    		fix_ndk
	else
    		ndk_installed=true
	fi

else
	echo "$ndk_file_name does not exists."
fi

if [ -d "$cmake_dir" ]; then
	cd "$cmake_dir"
	run_install_cmake
else
	mkdir -p "$cmake_dir"
	cd "$cmake_dir"
	run_install_cmake
fi

if [[ $ndk_installed == true && $cmake_installed == true ]]; then
	echo 'Installation Finished. NDK has been installed successfully, please restart AndroidIDE!'
else
	echo 'NDK and cmake has been does not installed successfully!'
fi
