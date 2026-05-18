# SIP MESSAGE Support — Design

## Summary

Add sending and receiving of SIP MESSAGE (text over SIP) to Telephone. Messages
appear in the existing call history window alongside calls, distinguished by icon.
A popup dialog provides text composition.

## Data model

### `HistoryRecordKind` (new enum)

```swift
public enum HistoryRecordKind: String, Codable {
    case call
    case message
}
```

### `CallHistoryRecord` changes

Two new fields, one renamed initializer:

```swift
public struct CallHistoryRecord {
    // existing fields unchanged
    public let identifier: String
    public let uri: URI
    public let date: Date
    public let duration: Int
    public let isIncoming: Bool
    public let isMissed: Bool

    // new
    public let kind: HistoryRecordKind
    public let text: String?   // nil for calls, message body for messages
}
```

Message `identifier` format: `"\(uri.user)@\(uri.host)|\(date.timeIntervalSinceReferenceDate)|\(text.hashValue)"`

Existing call initializer defaults `kind = .call, text = nil`. New message
initializer sets `kind = .message, text = body, duration = 0`.

Persistence uses the same `PropertyListStorage` / `SimplePropertyListStorage`. The
`kind` and `text` fields serialize into the existing property list format alongside
the current fields. Backwards compatible — old records without `kind` decode as
`.call`.

## PJSIP bridge

### `AKSIPMessenger` (new ObjC class, owned by `AKSIPUserAgent`)

- **Init**: registers `on_pager2` callback with PJSIP during user agent startup.
  Incoming MESSAGE → creates `CallHistoryRecord(kind: .message, ...)` and
  notifies delegate.
- **sendMessage:to:from:account**: wraps `pjsua_im_send` with `text/plain` MIME
  type. Accepts destination URI string and text body.
- **typing indication**: `pjsua_im_typing` — out of scope for initial version.

### `AKSIPUserAgent` changes

- Stores an `AKSIPMessenger` instance
- Sets `on_pager2` in the PJSIP callback config during `start`
- New delegate callback: `- (void)sipUserAgent:(AKSIPUserAgent *)userAgent didReceiveMessage:(CallHistoryRecord *)record`

## UseCases

Reuse existing:

- `CallHistoryRecordAddUseCase` — works unchanged for message records
- `CallHistoryRecordGetAllUseCase` — returns mixed call + message records

New:

- `MessageSendUseCase` — calls `AKSIPMessenger.sendMessage`, on success creates
  `CallHistoryRecord(kind: .message, ...)` and passes it to
  `CallHistoryRecordAddUseCase`.

## GUI

### Account window toolbar — Call and Send Text buttons

Two `NSButton` instances added to the account window's header area, to the right
of the call destination input field:

- **[Call]** — triggers existing `makeCallToDestination:` action
- **[Send Text]** — opens the message composition popup with the destination
  pre-filled

### Message composition popup

A modal dialog (NSPanel or NSAlert-style) containing:
- Destination URI display (read-only, pre-filled)
- Multi-line `NSTextView` (4-5 rows visible)
- **[Cancel]** and **[Send]** buttons

On Send: resets text field, invokes `MessageSendUseCase`, closes popup.

### History table

`CallHistoryTableRowView` checks `record.kind`:
- **Calls** — existing icons (phone with arrow for outgoing/incoming)
- **Messages** — speech bubble icon: filled for outgoing, outline for incoming.
  Cell shows message text preview instead of call duration.

`PresentationCallHistoryRecord` gains `kind`, `text`, and computed properties for
the cell: `isMessage`, `messagePreview` (truncated to one line).

### Incoming message notification

When `AKSIPUserAgentDelegate` fires `didReceiveMessage:`, the message record is
added to the history store. If the account window is open, the table refreshes.
No separate notification popup — messages appear in history only.

## Out of scope

- Typing indicators (`pjsua_im_typing`)
- Inline chat thread view (separate from history)
- Message delivery status icons in history
- File transfer / MIME types other than `text/plain`
