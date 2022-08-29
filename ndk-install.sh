#!/bin/bash

# Script to install NDK into AndroidIDE
install_dir=$HOME
sdk_dir=$install_dir/android-sdk
ndk_dir=$sdk_dir/ndk/24.0.8215888

echo 'Warning! This NDK only for aarch64'
cd $install_dir
# download NDK
echo 'Downloading NDK r24'
wget https://github.com/jzinferno/termux-ndk/releases/download/v1/android-ndk-r24-aarch64.zip 
echo 'Unziping NDK r24'
unzip android-ndk-r24-aarch64.zip 
rm android-ndk-r24-aarch64.zip
# moving ndk to Android SDK directory
mkdir $sdk_dir/ndk 
mv android-ndk-r24 $sdk_dir/ndk/24.0.8215888 

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
chmod -R +x $sdk_dir/cmake/3.23.1/bin
# add cmake to path
echo -e "\nPATH=\$PATH:$HOME/android-sdk/cmake/3.23.1/bin" >> $SYSROOT/etc/ide-environment.properties

echo 'Installation Finished. Ndk has been installed successfully, please restart AndroidIDE!'
