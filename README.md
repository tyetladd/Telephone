Telephone is a VoIP SIP softphone for Mac. It allows you to make phone
calls over the Internet or your company network. If your phone line
supports SIP protocol, you can use it on your Mac instead of a
physical phone anywhere you have a decent network connection.

## Building

### Opus

Opus codec is optional.

Download:

    $ curl -O https://archive.mozilla.org/pub/opus/opus-1.3.1.tar.gz
    $ tar xzvf opus-1.3.1.tar.gz
    $ cd opus-1.3.1

Build and install:

    $ ./configure --prefix=/path/to/Telephone/ThirdParty/Opus --disable-shared CFLAGS='-arch arm64 -arch x86_64 -Os -mmacosx-version-min=13.5'
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

    $ ./configure --prefix=/path/to/Telephone/ThirdParty/LibreSSL --disable-shared CFLAGS='-arch arm64 -arch x86_64 -Os -mmacosx-version-min=13.5'
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
    $ patch -p0 -i /path/to/Telephone/ThirdParty/PJSIP/patches/coreaudio_dev.patch
    $ patch -p0 -i /path/to/Telephone/ThirdParty/PJSIP/patches/ssl_sock_ossl.patch

Build and install (arm64-only binaries are sufficient for the app; keep x86_64 only if you explicitly need Rosetta):

    $ export PKG_CONFIG_PATH=/path/to/Telephone/ThirdParty/bcg729/lib/pkgconfig:/path/to/Telephone/ThirdParty/Opus/lib/pkgconfig
    $ ./configure --prefix=/path/to/Telephone/ThirdParty/PJSIP \
        --with-opus=/path/to/Telephone/ThirdParty/Opus \
        --with-bcg729=/path/to/Telephone/ThirdParty/bcg729 \
        --with-ssl=/path/to/Telephone/ThirdParty/LibreSSL \
        --disable-video --disable-libyuv --disable-libwebrtc \
        --host=arm-apple-darwin \
        CFLAGS='-arch arm64 -Os -DNDEBUG -mmacosx-version-min=13.5' \
        CXXFLAGS='-arch arm64 -Os -DNDEBUG -mmacosx-version-min=13.5' \
        LDFLAGS='-arch arm64 -mmacosx-version-min=13.5'

    $ make dep
    $ make lib
    $ make install

Notes:
- `--with-opus` bundles Opus; omit if you do not want Opus.
- `--with-bcg729` enables G.729 (bcg729). Ensure `ThirdParty/bcg729` is built first so headers/libs are available via `PKG_CONFIG_PATH`.
- Keeping only arm64 reduces build time and output size; add `-arch x86_64` to the flag variables and remove `--host=arm-apple-darwin` if you need a universal build for Rosetta.

    
Build Telephone.

## Contribution

For the legal reasons, pull requests are not accepted. Please feel
free to share your thoughts and ideas by commenting on the issues.
