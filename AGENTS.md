# AGENTS.md instructions for /Users/ncamargo/projects/Telephone

-- Always run shell commands using `bash -lc` to match CI and avoid shell differences.

<INSTRUCTIONS>
# Repository Guidelines

## Project Structure & Modules

- `Telephone/` — macOS app sources (Objective‑C & Swift), storyboards/xibs, assets.
- `Domain/`, `UseCases/` — modular business logic; Public headers live in matching framework targets.
- `ReceiptValidation/` — XPC service for App Store receipt checks.
- `ThirdParty/` — prebuilt static deps (Opus, LibreSSL, PJSIP). Rebuild only if you change codec/SSL options.
- Tests sit beside modules: `TelephoneTests/`, `DomainTests/`, `UseCasesTests/`, plus in‑module `*Tests.swift`.

## Build, Test, Run

- Build app (signing off):  
  `xcodebuild -scheme Telephone -configuration Release CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY="" build`
- Build with signing (for distribution): configure a valid “Mac Development/Distribution” identity, then drop the signing overrides.
- Run unit tests:  
  `xcodebuild -scheme Telephone -configuration Debug -destination "platform=macOS,arch=arm64" test`
- Rebuild third‑party libs (optional): follow `README.md` sections for Opus, LibreSSL, and PJSIP; install into `ThirdParty/...`.

## Coding Style & Naming

- Follow Xcode defaults: 4‑space indent, spaces over tabs.
- Swift: PascalCase types/protocols, camelCase methods/properties, extend via `extension` per topic; prefer value types and Swift error handling.
- Objective‑C: Prefix app classes with `AK`/module prefix, keep headers lean, ARC on; use class refs vs. forward declarations where possible; enums via NS_ENUM.
- Files live in module folders mirroring targets; tests named `*Tests.swift` / `*Tests.m`.

## Testing Guidelines

- Use XCTest (Swift & Obj‑C). Add targeted unit tests in the corresponding `*Tests` target.
- Name tests `test_<behavior>`; prefer arranging Given/When/Then in comments.
- For UI pieces, keep logic in presenters/view models and test them headlessly.

## Commit & PR Practice

- Commits: short imperative subject (“Fix PJSIP include paths”); bundle related changes only.
- PRs: include purpose, key changes, test command output, and screenshots/GIFs for UI updates. Link issues when applicable.

## Security & Config

- Do not commit signing identities or provisioning profiles.  
- PJSIP/SSL builds are static; if you change crypto/codec options, regenerate libs before shipping.  
- App requires microphone/network permissions at runtime—avoid hardcoding entitlements beyond `Telephone.entitlements`.

</INSTRUCTIONS>
