# AndroidIDE-NDK
This bash script will install ndk r24 by [jzinferno](https://github.com/jzinferno) to  [AndroidIDE](https://github.com/itsaky/AndroidIDE) app.
- Install NDK r24 to [AndroidIDE](https://github.com/itsaky/AndroidIDE) in one command :
```
cd && pkg upgrade && pkg install wget && wget https://github.com/MrIkso/AndroidIDE-NDK/raw/main/ndk-install.sh -N && chmod +x ndk-install.sh && ./ndk-install.sh
```
- Restart [AndroidIDE](https://github.com/itsaky/AndroidIDE)
- Edit or set ```ndkVersion``` in your build.gradle to ```ndkVersion "24.0.8215888"``` and set cmake version to ```version '3.23.1'```

Warning Cmake work on Android 10+

Demo

```
plugins {
    id 'com.android.application'
}

android {
    compileSdk 32
    buildToolsVersion "33.0.0"
    ndkVersion "24.0.8215888"

    defaultConfig {
        applicationId "com.myapplication"
        minSdk 23
        targetSdk 32
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
            version '3.23.1'
        }
    }
}

dependencies {
   ...
}
```

Thanks to [jzinferno](https://github.com/jzinferno/termux-ndk) and [Lzhiyong](https://github.com/Lzhiyong)
