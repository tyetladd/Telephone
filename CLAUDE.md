# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

Telephone is a macOS VoIP SIP softphone (GPL-3.0). It uses PJSIP as the underlying SIP stack and is written in a mix of Objective-C and Swift.

## Build & Test

```bash
# Build unsigned for native architecture (Debug)
xcodebuild -scheme Telephone -configuration Debug \
  -destination "platform=macOS,arch=$(uname -m)" \
  -derivedDataPath .derived \
  CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY="" \
  build

# Build and launch (convenience script)
./run-latest.sh                           # Debug, arm64 by default
ARCH=x86_64 CONFIG=Release ./run-latest.sh

# Run all unit tests
xcodebuild -scheme Telephone -configuration Debug \
  -destination "platform=macOS,arch=$(uname -m)" test
```

Deployment target: macOS 13.5. App is sandboxed (see `Telephone/Telephone.entitlements`).

### Building third-party dependencies from scratch

Dependencies: `bcg729`, `Opus`, `LibreSSL`, and `PJSIP` install into `ThirdParty/`. The Xcode project expects static libs named `*-arm-apple-darwin.a` — when building for x86_64, create symlinks like `libpjsua-arm-apple-darwin.a -> libpjsua-x86_64-apple-darwin*.a`. See `README.md` for the full build steps.

Prerequisites via Homebrew for AMR codec support: `brew install opencore-amr`.

The project's `LIBRARY_SEARCH_PATHS` must include all third-party lib dirs: `ThirdParty/{PJSIP,LibreSSL,Opus,bcg729}/lib` plus `/usr/local/lib` for Homebrew-installed libs. `OTHER_LDFLAGS` for the Telephone target includes `-lbcg729`, `-lopus`, `-lssl`, `-lcrypto`, `-lopencore-amrnb`, `-lopencore-amrwb`, and the PJSIP libs.

## Architecture

### Target graph (dependency order, bottom-up)

```
ThirdParty/          Prebuilt static libs: PJSIP, bcg729, Opus, LibreSSL
    ↓
Domain/              Audio device abstraction layer (Swift framework)
    ↓
UseCases/            Business logic: calls, accounts, call history, contacts,
                     ringtone, store/receipt, use-case/event-target patterns
    ↓
Telephone/           macOS app shell: view controllers, windows, storyboards,
                     PJSIP bridge (AK-prefixed ObjC classes)
    ├── ReceiptValidation/   XPC service for App Store receipt validation
    └── AddressBookPlugIns/  macOS Address Book phone/SIP dialing plugins
```

### Key patterns

- **AK prefix**: All ObjC app-level classes use `AK` (e.g. `AKSIPUserAgent`, `AKSIPAccount`, `AKSIPCall`).
- **PJSIP bridge**: `AKSIPUserAgent` wraps `pjsua-lib`. It's a shared singleton managing accounts, calls, audio devices, codecs, NAT/STUN/ICE. `AKSIPAccount` conforms to the `Account` protocol from UseCases. `AKSIPCall` wraps individual call state.
- **UseCases pattern**: Business logic is organized as `UseCase`/`UseCaseFactory` protocols with `EventTarget` protocols for observer-style output. E.g. `CallHistoryRecordAddUseCase`, `CallHistoryRecordAddUseCaseFactory`, `CallEventTarget`. `Enqueuing*` wrappers dispatch events onto a specific `ExecutionQueue`.
- **Domain pattern**: Audio device abstraction — `SoundIO`, `SystemAudioDevice`, `UserAgentAudioDevice` — maps between system audio devices and PJSIP user-agent audio devices.
- **Swift/ObjC interop**: Bridging headers at `Telephone/Telephone-Bridging-Header.h` and `ReceiptValidation/ReceiptValidation-Bridging-Header.h` expose ObjC headers to Swift. Some modules import `UseCases` via `@import UseCases;`.

### Test structure

Each module has a corresponding test target. Test doubles live in `DomainTestDoubles/` and `UseCasesTestDoubles/`. Tests use XCTest with Given/When/Then comment style, naming convention `test_<behavior>`.

```
TelephoneTests/      App-level tests (view presenters, settings migration, etc.)
DomainTests/         Audio device logic tests
UseCasesTests/       Business logic tests (the largest test suite)
ReceiptValidationTests/
```

## Coding conventions

- Xcode defaults: 4-space indent, spaces over tabs
- Swift: PascalCase types/protocols, camelCase methods/properties, `extension` per protocol/topic, prefer value types
- ObjC: `AK` prefix on app classes, lean headers, ARC, `NS_ENUM` for enums
- Tests named `*Tests.swift` / `*Tests.m`, methods `test_<behavior>`
- Files organized by module mirroring Xcode targets

## Important constraints

- Pull requests are not accepted; share ideas via issues
- Do not commit signing identities or provisioning profiles
- PJSIP/SSL are static builds — regenerate libs before shipping if crypto/codec options change
- App requires sandbox entitlements for microphone, network, address book, USB, Bluetooth, and Apple Events (Spotify/iTunes)
