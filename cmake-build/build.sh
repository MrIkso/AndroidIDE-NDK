#!/usr/bin/env bash

build(){
    abi=$1
    ndkRoot=${ANDROID_NDK_HOME}
    sdkRoot=${ANDROID_SDK_ROOT}
    if [[ ${ndkRoot} == "" ]]; then
        ndkRoot=${ANDROID_NDK_ROOT}
    fi
    if [[ ${ndkRoot} == "" ]]; then
        echo "ANDROID_NDK_HOME or ANDROID_NDK_HOME not defined"
        exit 1
    fi
    outDir=$(pwd)
    dirName=${PWD##*/}
    dirNameSubstring="${dirName::-2}"
    generationDir="build/release"
    echo "-- Build cmake"
    mkdir -p "${generationDir}"
    mkdir -p "${outDir}/out"
    cd "${generationDir}"
    ${sdkRoot}/cmake/3.22.1/bin/cmake \
        -DCMAKE_GENERATOR=Ninja \
        -DCMAKE_MAKE_PROGRAM=${sdkRoot}/cmake/3.22.1/bin/ninja \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_TOOLCHAIN_FILE=${ndkRoot}/build/cmake/android.toolchain.cmake \
        -DANDROID_ABI=${abi} \
        -DANDROID_NATIVE_API_LEVEL=29 \
        -DANDROID_NDK=${ndkRoot} \
        -DCMAKE_DOC_DIR=/doc/"${dirNameSubstring}" \
        -DCMAKE_MAN_DIR=/share/man \
        -DCMAKE_DATA_DIR=/share/"${dirNameSubstring}" \
        -DCMAKE_USE_SYSTEM_LARHIVE=NO \
        -DCMAKE_USE_SYSTEM_LIBUV=NO \
        -DBUILD_TESTING=NO \
        -DSPHINX_MAN=ON \
        ../..
       
    ${sdkRoot}/cmake/3.22.1/bin/cmake  --build . --target all
    cd "${generationDir}"
    
    cmakeVersion=${dirName:6}
    cmakeOutDir=${outDir}/out/"${cmakeVersion}"
    
    ${sdkRoot}/cmake/3.22.1/bin/cmake  -DCMAKE_INSTALL_PREFIX=${cmakeOutDir} -P cmake_install.cmake
    cd -
    echo ""
    echo "Apply patches.."
    cp -r cmake ${cmakeOutDir}/share/"${dirNameSubstring}"
    cd ${cmakeOutDir}/share/"${dirNameSubstring}"
    for i in cmake/*.patch; do patch -p1 < $i; done
    rm -rf ${cmakeOutDir}/share/"${dirNameSubstring}"/cmake
    cd ${outDir}
    echo "Adding ninja.."
    cd ..
    cp ninja-1.11.1/build/release/ninja ${cmakeOutDir}/bin/ninja
    cd ${outDir}/out
    echo "Zipping distributive.."
    7z a ${dirName}-android-aarch64.zip ${cmakeVersion}/
}

yes | apt install p7zip
yes | apt install python3
yes | pip install -U sphinx

build arm64-v8a
