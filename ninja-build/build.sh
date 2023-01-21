#!/usr/bin/env bash

build(){
    abi=$1
    ndkRoot=${ANDROID_NDK_HOME}
    sdkRoot=${ANDROID_SDK_ROOT}
    if [[ ${ndkRoot} == "" ]]; then
        ndkRoot=${ANDROID_NDK_ROOT}
    fi
    if [[ ${ndkRoot} == "" ]]; then
        echo "ANDROID_NDK_HOME or ANDROID_NDK_ROOT not defined"
        exit 1
    fi
    generationDir="build/release"
    echo "-- Build ninja"
    mkdir -p "${generationDir}"
    cd "${generationDir}"
    ${sdkRoot}/cmake/3.22.1/bin/cmake \
        -DCFLAGS=-fstack-protector-all \
        -DCXXFLAGS=-fstack-protector-all \
        -DCMAKE_GENERATOR=Ninja \
        -DCMAKE_MAKE_PROGRAM=${sdkRoot}/cmake/3.23.1/bin/ninja \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_TOOLCHAIN_FILE=${ndkRoot}/build/cmake/android.toolchain.cmake \
        -DANDROID_ABI=${abi} \
        -DANDROID_NATIVE_API_LEVEL=29 \
        -DANDROID_NDK=${ndkRoot} \
        ../..
    ${sdkRoot}/cmake/3.22.1/bin/cmake --build . --target all
    cd -
    echo ""
}

build arm64-v8a