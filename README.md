Telephone is a VoIP SIP softphone for Mac. It allows you to make phone
calls over the Internet or your company network. If your phone line
supports SIP protocol, you can use it on your Mac instead of a
physical phone anywhere you have a decent network connection.

## Building

### Prerequisites

- Full Xcode (Command Line Tools alone cannot build .app bundles). Switch with:
  ```
  sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
  ```
- Homebrew packages:
  ```
  brew install opencore-amr
  ```

### Third-party libraries

Dependencies install into `ThirdParty/`:

| Library | Directory | Notes |
|---------|-----------|-------|
| Opus | `ThirdParty/Opus/` | Optional codec |
| LibreSSL | `ThirdParty/LibreSSL/` | TLS for PJSIP |
| bcg729 | `ThirdParty/bcg729/` | G.729 codec (build from source for x86_64) |
| PJSIP | `ThirdParty/PJSIP/` | SIP stack, links all of the above |

### bcg729

The pre-built `ThirdParty/bcg729/` library is arm64-only. Rebuild for x86_64:

```
$ curl -LO https://github.com/BelledonneCommunications/bcg729/archive/refs/tags/1.1.1.tar.gz
$ tar xzf 1.1.1.tar.gz
$ cd bcg729-1.1.1
$ ./autogen.sh
$ ./configure --prefix=/path/to/Telephone/ThirdParty/bcg729 --disable-shared \
    CFLAGS='-arch x86_64 -Os -mmacosx-version-min=13.5'
$ make
$ make install
```

After installing, fix the pkg-config file if it contains a stale prefix:
```
$ sed -i '' 's|prefix=.*|prefix=/path/to/Telephone/ThirdParty/bcg729|' \
    /path/to/Telephone/ThirdParty/bcg729/lib/pkgconfig/libbcg729.pc
```

### Opus

Opus codec is optional.

Download:

    $ curl -O https://archive.mozilla.org/pub/opus/opus-1.3.1.tar.gz
    $ tar xzvf opus-1.3.1.tar.gz
    $ cd opus-1.3.1

Build and install (adjust arch for your Mac — x86_64 for Intel, arm64 for Apple Silicon):

    $ ./configure --prefix=/path/to/Telephone/ThirdParty/Opus --disable-shared \
        CFLAGS='-arch x86_64 -Os -mmacosx-version-min=13.5'
    $ make
    $ make install

### LibreSSL

Download:

    $ curl -O https://ftp.openbsd.org/pub/OpenBSD/LibreSSL/libressl-3.1.5.tar.gz
    $ curl -O https://ftp.openbsd.org/pub/OpenBSD/LibreSSL/libressl-3.1.5.tar.gz.asc
    $ gpg --verify libressl-3.1.5.tar.gz.asc
    $ tar xzvf libressl-3.1.5.tar.gz
    $ cd libressl-3.1.5

Build and install:

    $ ./configure --prefix=/path/to/Telephone/ThirdParty/LibreSSL --disable-shared \
        CFLAGS='-arch x86_64 -Os -mmacosx-version-min=13.5'
    $ make
    $ make install

### PJSIP

Download:

    $ curl -o pjproject-2.15.1.tar.gz https://codeload.github.com/pjsip/pjproject/tar.gz/2.15.1
    $ tar xzvf pjproject-2.15.1.tar.gz
    $ cd pjproject-2.15.1

Create `pjlib/include/pj/config_site.h`:

    #define PJSIP_DONT_SWITCH_TO_TCP 1
    #define PJSUA_MAX_ACC 32
    #define PJMEDIA_RTP_PT_TELEPHONE_EVENTS 101
    #define PJ_DNS_MAX_IP_IN_A_REC 32
    #define PJ_DNS_SRV_MAX_ADDR 32
    #define PJSIP_MAX_RESOLVED_ADDRESSES 32
    #define PJ_HAS_IPV6 1

Patch:

    $ patch -p0 -i /path/to/Telephone/ThirdParty/PJSIP/patches/sock_qos_darwin.patch
    $ patch -p1 -i /path/to/Telephone/ThirdParty/PJSIP/patches/coreaudio_dev.patch
    $ patch -p1 -i /path/to/Telephone/ThirdParty/PJSIP/patches/ssl_sock_ossl.patch

Build and install (x86_64 example — use `-arch arm64` and `--host=arm-apple-darwin` for Apple Silicon):

    $ export PKG_CONFIG_PATH="/path/to/Telephone/ThirdParty/bcg729/lib/pkgconfig:/path/to/Telephone/ThirdParty/Opus/lib/pkgconfig"
    $ ./configure --prefix=/path/to/Telephone/ThirdParty/PJSIP \
        --with-opus=/path/to/Telephone/ThirdParty/Opus \
        --with-bcg729=/path/to/Telephone/ThirdParty/bcg729 \
        --with-ssl=/path/to/Telephone/ThirdParty/LibreSSL \
        --disable-video --disable-libyuv --disable-libwebrtc \
        CFLAGS='-arch x86_64 -Os -DNDEBUG -mmacosx-version-min=13.5' \
        CXXFLAGS='-arch x86_64 -Os -DNDEBUG -mmacosx-version-min=13.5' \
        LDFLAGS='-arch x86_64 -mmacosx-version-min=13.5'

    $ make dep
    $ make
    $ make install

**Important — library naming for x86_64:** the Xcode project links against
`-lpjsua-arm-apple-darwin` and similar arm-named libraries. When building for
x86_64, PJSIP produces `libpjsua-x86_64-apple-darwin*.a`. Create symlinks so the
linker finds them:

```
$ cd /path/to/Telephone/ThirdParty/PJSIP/lib
$ for lib in *-x86_64-apple-darwin*.a; do
    newname=$(echo "$lib" | sed 's/x86_64-apple-darwin[0-9.]*/arm-apple-darwin/')
    ln -sf "$lib" "$newname"
  done
```

**Note:** the Xcode project has been updated to include `ThirdParty/bcg729/lib`,
`/usr/local/lib` in `LIBRARY_SEARCH_PATHS`, and `-lopencore-amrnb`,
`-lopencore-amrwb` in `OTHER_LDFLAGS`. If you regenerate the project, re-apply
these changes.

### Building the app

```
$ xcodebuild -scheme Telephone -configuration Debug \
    -destination "platform=macOS,arch=$(uname -m)" \
    -derivedDataPath .derived \
    CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY="" \
    build
```

Or use the convenience script:

```
$ ./run-latest.sh                           # Debug, native arch
$ ARCH=x86_64 CONFIG=Release ./run-latest.sh
```

The app will be at `.derived/Build/Products/Debug/Telephone.app`. Launch with:

```
$ open .derived/Build/Products/Debug/Telephone.app
```

### Creating a DMG

```
# Build Release first
$ xcodebuild -scheme Telephone -configuration Release \
    -destination "platform=macOS,arch=$(uname -m)" \
    -derivedDataPath .derived \
    CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY="" \
    build

# Package into DMG
$ APP=.derived/Build/Products/Release/Telephone.app
$ STAGING=$(mktemp -d)
$ cp -R "$APP" "$STAGING/"
$ ln -s /Applications "$STAGING/Applications"
$ hdiutil create -volname Telephone -srcfolder "$STAGING" \
    -ov -format UDZO Telephone-$(uname -m).dmg
```

Note: the DMG is unsigned and not notarized. On first launch, right-click the
app and select Open to bypass Gatekeeper.

### Running tests

```
$ xcodebuild -scheme Telephone -configuration Debug \
    -destination "platform=macOS,arch=$(uname -m)" test
```

## Contribution

For the legal reasons, pull requests are not accepted. Please feel
free to share your thoughts and ideas by commenting on the issues.
