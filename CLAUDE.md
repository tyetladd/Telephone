# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

Telephone is a macOS VoIP SIP softphone (GPL-3.0). It uses PJSIP as the underlying SIP stack and is written in a mix of Objective-C and Swift.

## Build & Test

```bash
# Build unsigned for native architecture (Debug) — -project flag required
xcodebuild -project Telephone.xcodeproj -scheme Telephone -configuration Debug \
  -destination "platform=macOS,arch=$(uname -m)" \
  -derivedDataPath .derived \
  CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY="" \
  build

# Build and launch (convenience script)
./run-latest.sh                           # Debug
ARCH=x86_64 CONFIG=Release ./run-latest.sh

# Launch app (kill old instances first if SIP 503 appears)
killall Telephone 2>/dev/null
.derived/Build/Products/Release/Telephone.app/Contents/MacOS/Telephone &

# Run all unit tests
xcodebuild -project Telephone.xcodeproj -scheme Telephone -configuration Debug \
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

### SIP MESSAGE (instant messaging) feature

Incoming SIP MESSAGE flows:
1. `AKSIPMessengerOnPager2Callback` (PJSIP thread) — validates MIME type (`text/*` only), copies `pj_str_t` bytes into `NSString`, then **`dispatch_async(main)`** before calling `handleIncomingMessage:from:`.
2. `AKSIPUserAgent.handleIncomingMessage:from:` (main thread) — posts `AKSIPUserAgentDidReceiveMessageNotification`.
3. `CompositionRoot.setupMessageObservers` (main queue observer) — parses the raw SIP From-header URI via `components(ofSIPURI:)`, creates a `CallHistoryRecord(kind:.message)`, adds it via `CallHistoryRecordAddUseCase`, and plays a `Ping` sound.

Outgoing SIP MESSAGE flows:
1. `ActiveAccountViewController.messageSendBlock` posts `TelephoneDidRequestMessageCompositionNotification` with the destination address.
2. `CompositionRoot` observer creates `MessageCompositionViewController` + `MessageCompositionWindowController`, storing the controller in `messageWindowControllers` (released on `NSWindow.willCloseNotification`).
3. `onSend` closure calls `AKSIPMessenger.sendMessage:to:accountId:`, then adds a `CallHistoryRecord(kind:.message, isIncoming:false)`.

Key files:
- `AKSIPUserAgent.m` — PJSIP callback and `handleIncomingMessage:from:`
- `AKSIPMessenger.m` — `pjsua_im_send` wrapper
- `AKSIPUserAgentNotifications.h/m` — notification name constants (including `TelephoneDidRequestMessageCompositionNotification`)
- `CompositionRoot.swift` — wires both flows together; owns `messageWindowControllers`
- `MessageCompositionViewController.swift` / `MessageCompositionWindowController.swift` — compose UI
- `CallHistoryIconCellView.swift` — renders phone/chat SF Symbol in call history column 0
- `UseCases/CallHistoryRecord.swift` — `HistoryRecordKind` enum (`.call` / `.message`); message identifier includes `stableHash(text)`

**Threading rule**: Every PJSIP C callback must marshal to the main thread before touching any ObjC/Swift objects or posting notifications. Use `dispatch_async(dispatch_get_main_queue(), ^{ … })` as the very first thing after reading PJSIP pointer values (copy any `pj_str_t` data to `NSString` before dispatching).

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
