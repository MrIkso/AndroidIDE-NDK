# AndroidIDE-NDK

This bash script will install NDK to [AndroidIDE](https://github.com/itsaky/AndroidIDE) and [Termux](https://github.com/termux/termux-app).

### How to install NDK to [AndroidIDE](https://github.com/itsaky/AndroidIDE) and [Termux](https://github.com/termux/termux-app)

1. Download the NDK installation script:

   ```bash
   cd && pkg upgrade && pkg install wget aria2 unzip tar -y &&
   wget https://github.com/MrIkso/AndroidIDE-NDK/raw/main/ndk-install.sh --no-verbose --show-progress -N &&
   chmod +x ndk-install.sh && ./ndk-install.sh
   ```

2. Choose your required NDK version from the list by entering the numbers provided and wait for the installation to complete.

3. After installation, edit or set `ndkVersion` in your `build.gradle` or `build.gradle.kts` file as follows:
   - If you choose `r24`, set `ndkVersion` to `"24.0.8215888"`.
   - If you choose `r28c`, set `ndkVersion` to `"28.2.13676358"`.
   - If you choose `r29`, set `ndkVersion` to `"29.0.14206865"`.

## Usage

### Warning

NDK versions installed from the provided URLs are for **aarch64 architecture only**. The script validates your platform and will exit on unsupported architectures. Use `--arch` to override for testing purposes.

```bash
./ndk-install.sh [OPTIONS] [NDK_VERSION]
```

**Options:**

- `--yes`         : Automatically agree to all prompts for non-interactive installation.
- `--url <NDK_URL>`    : Install NDK from a custom URL.
- `--arch <ARCH>`     : Override default architecture (e.g., arm64, x86).
- `--help`         : Show this message.

**NDK Versions Available**:
r17c, r18b, r19c, r20b, r21e, r22b, r23b, r24, r26b, r27b, r27d, r28c, r29

**Examples:**

Interactive mode:

```bash
./ndk-install.sh
```

Install specific version:

```bash
./ndk-install.sh r29
```

Non-interactive installation:

```bash
./ndk-install.sh --yes r28c
```

Custom NDK URL:

```bash
./ndk-install.sh --url "https://example.com/android-ndk.tar.xz"
```

Using environment variables:

```bash
NDK_VERSION=r29 ./ndk-install.sh --yes
```

Architecture override (for testing):

```bash
./ndk-install.sh --arch Linux-x86_64 r27b
```

You can find the downloaded NDK version names by running:

```bash
ls $HOME/android-sdk/ndk
```

(⚠️ Warning: CMake works on Android 10+ Only.)

Example:

```
plugins {
    id 'com.android.application'
}

android {
    compileSdk 33
    buildToolsVersion "33.0.0"
    ndkVersion "28.2.13676358"

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
