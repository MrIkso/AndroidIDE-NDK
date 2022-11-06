#!/bin/bash

# Script to install NDK into AndroidIDE
install_dir=$HOME
sdk_dir=$install_dir/android-sdk
cmake_dir=$sdk_dir/cmake

ndk_dir=""
ndk_ver=""
ndk_ver_name=""

echo "Select with NDK you need install?"

select item in r21e r24 Quit
do
    case $item in
        "r21e")
            ndk_ver="21.4.7075529";
            ndk_ver_name="r21e";
            echo "Selected $ndk_ver_name ($ndk_ver)";
            break
            ;;
            
        "r24")
            ndk_ver="24.0.8215888";
            ndk_ver_name="r24";
            echo "Selected $ndk_ver_name ($ndk_ver)";
            break;;
            
        "Quit")
           echo "Exit.."
           exit
           break;;
        *)
           echo "Ooops";;
    esac
done

echo 'Warning! This NDK only for aarch64'
cd $install_dir
# checking if previous installed NDK and cmake 

ndk_dir=$sdk_dir/ndk/$ndk_ver

if [ -d "$ndk_dir" ]
then
    echo "$ndk_dir exists. Deleting NDK $ndk_ver..."
    rm -rf $ndk_dir
else
    echo "NDK does not exists."
fi

if [ -d "$cmake_dir/3.23.1" ]
then
    echo "$cmake_dir/3.23.1 exists. Deleting cmake..."
    rm -rf $cmake_dir/3.23.1
else
    echo "Cmake does not exists."
fi

# download NDK
echo "Downloading NDK $ndk_ver_name"
wget https://github.com/jzinferno/termux-ndk/releases/download/v1/android-ndk-$ndk_ver_name-aarch64.zip 
echo "Unziping NDK $ndk_ver_name"
unzip android-ndk-$ndk_ver_name-aarch64.zip
rm android-ndk-$ndk_ver_name-aarch64.zip
# moving ndk to Android SDK directory
mkdir $sdk_dir/ndk
mv android-ndk-$ndk_ver_name $ndk_dir

# create missing link
ln -s $ndk_dir/toolchains/llvm/prebuilt/linux-aarch64 $ndk_dir/toolchains/llvm/prebuilt/linux-x86_64
ln -s $ndk_dir/prebuilt/linux-aarch64 $ndk_dir/prebuilt/linux-x86_64

# patching cmake config
sed -i 's/if(CMAKE_HOST_SYSTEM_NAME STREQUAL Linux)/if(CMAKE_HOST_SYSTEM_NAME STREQUAL Android)\nset(ANDROID_HOST_TAG linux-aarch64)\nelseif(CMAKE_HOST_SYSTEM_NAME STREQUAL Linux)/g' $ndk_dir/build/cmake/android-legacy.toolchain.cmake
sed -i 's/if(CMAKE_HOST_SYSTEM_NAME STREQUAL Linux)/if(CMAKE_HOST_SYSTEM_NAME STREQUAL Android)\nset(ANDROID_HOST_TAG linux-aarch64)\nelseif(CMAKE_HOST_SYSTEM_NAME STREQUAL Linux)/g' $ndk_dir/build/cmake/android.toolchain.cmake

# download cmake
wget https://github.com/MrIkso/AndroidIDE-NDK/raw/main/cmake.zip
# unzip cmake
unzip cmake.zip -d $sdk_dir
rm cmake.zip
# set executable permission for cmake
chmod -R +x $cmake_dir/3.23.1/bin
# add cmake to path
echo -e "\nPATH=\$PATH:$HOME/android-sdk/cmake/3.23.1/bin" >> $SYSROOT/etc/ide-environment.properties

echo 'Installation Finished. Ndk has been installed successfully, please restart AndroidIDE!'
