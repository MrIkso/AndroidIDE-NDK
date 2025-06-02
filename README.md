# AndroidIDE-NDK
This bash script will install NDK to [AndroidIDE](https://github.com/itsaky/AndroidIDE) and [Termux](https://github.com/termux/termux-app).

### How to install Ndk to [AndroidIDE](https://github.com/itsaky/AndroidIDE) and [Termux](https://github.com/termux/termux-app).

1. Download the NDK installation script:

   ```bash
   cd && pkg upgrade && pkg install wget && wget https://github.com/MrIkso/AndroidIDE-NDK/raw/main/ndk-install.sh --no-verbose --show-progress -N && chmod +x ndk-install.sh && bash ndk-install.sh
   ```

2. Choose your required NDK version from the list by entering the numbers provided and wait for the installation to complete.

3. After installation, edit or set `ndkVersion` in your `build.gradle` or `build.gradle.kts` file as follows:

   - If you choose `r24`, set `ndkVersion` to `"24.0.8215888"`.
   - If you choose `r28b`, set `ndkVersion` to `"28.1.13356709"`.
   - If you choose `r29-beta1`, set `ndkVersion` to `"29.0.13113456"`.


You can find the downloaded ndk version names by running:
```bash
ls $HOME/android-sdk/ndk
```

Example:

```
plugins {
    id 'com.android.application'
}

android {
    compileSdk 33
    buildToolsVersion "33.0.0"
    ndkVersion "28.1.13356709"

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
