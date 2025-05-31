# AndroidIDE-NDK
This bash script will install NDK to [AndroidIDE](https://github.com/itsaky/AndroidIDE) and [Termux](https://github.com/termux/termux-app).

How to install NDK to [AndroidIDE](https://github.com/itsaky/AndroidIDE) or [Termux](https://github.com/termux/termux-app) in one command:

- Copy and paste this commnad on terminal
```
cd && pkg upgrade && pkg install wget && wget https://github.com/MrIkso/AndroidIDE-NDK/raw/main/ndk-install.sh --no-verbose --show-progress -N && chmod +x ndk-install.sh && bash ndk-install.sh
```
- Select NDK version with will you need install and wait it downloaded and unpacked
- Edit or set ```ndkVersion``` in your build.gradle or build.gradle.kts to ```ndkVersion "<YOUR_NDK_VERSION>"```

Warning CMake work on Android 10+

Demo

```
plugins {
    id 'com.android.application'
}

android {
    compileSdk 33
    buildToolsVersion "33.0.0"
    ndkVersion "24.0.8215888"

    defaultConfig {
        applicationId "com.myapplication"
        minSdk 23
        targetSdk 33
        versionCode 1
        versionName "1.0"
    }
    
    buildTypes {
        release {
            minifyEnabled false
            proguardFiles getDefaultProguardFile('proguard-android-optimize.txt'), 'proguard-rules.pro'
        }
    }

    compileOptions {
        sourceCompatibility JavaVersion.VERSION_1_8
        targetCompatibility JavaVersion.VERSION_1_8
    }

    externalNativeBuild {
        cmake {
            path file('src/main/cpp/CMakeLists.txt')
        }
    }
}

dependencies {
   ...
}
```

Thanks to:
- [x] [jzinferno](https://github.com/jzinferno/termux-ndk)
- [x] [lzhiyong](https://github.com/lzhiyong/termux-ndk)
- [x] [HomuHomu833](https://github.com/HomuHomu833/android-ndk-custom)
