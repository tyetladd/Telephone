# SIP MESSAGE Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add send/receive SIP MESSAGE (text over SIP) with messages displayed in the existing call history window alongside calls, distinguished by icon.

**Architecture:** Extend `CallHistoryRecord` with `kind`/`text` fields. Add `AKSIPMessenger` ObjC class wrapping `pjsua_im_send`/`on_pager2`. Reuse existing `CallHistoryRecordAddUseCase` for persistence. Add `[Call]` and `[Send Text]` buttons next to the address field, a popup dialog for composing, and icon differentiation in the history table.

**Tech Stack:** Swift 5 + ObjC, PJSIP 2.17, Cocoa, XCTest

---

### Task 1: Add HistoryRecordKind enum and extend CallHistoryRecord

**Files:**
- Modify: `UseCases/CallHistoryRecord.swift`

- [ ] **Step 1: Add `HistoryRecordKind` enum and new fields to `CallHistoryRecord`**

```swift
// UseCases/CallHistoryRecord.swift — replace entire file:

import Foundation

public enum HistoryRecordKind: String, Codable {
    case call
    case message
}

public struct CallHistoryRecord {
    public let identifier: String
    public let uri: URI
    public let date: Date
    public let duration: Int
    public let isIncoming: Bool
    public let isMissed: Bool
    public let kind: HistoryRecordKind
    public let text: String?

    // Call initializer (backwards compatible)
    public init(uri: URI, date: Date, duration: Int, isIncoming: Bool, isMissed: Bool) {
        identifier = "\(uri.user)@\(uri.host)|\(date.timeIntervalSinceReferenceDate)|\(duration)|\(isIncoming ? 1 : 0)"
        self.uri = uri
        self.date = date
        self.duration = duration
        self.isIncoming = isIncoming
        self.isMissed = isMissed
        self.kind = .call
        self.text = nil
    }

    // Message initializer
    public init(uri: URI, date: Date, isIncoming: Bool, text: String) {
        identifier = "\(uri.user)@\(uri.host)|\(date.timeIntervalSinceReferenceDate)|\(text.hashValue)"
        self.uri = uri
        self.date = date
        self.duration = 0
        self.isIncoming = isIncoming
        self.isMissed = false
        self.kind = .message
        self.text = text
    }

    public func removingHost() -> CallHistoryRecord {
        return CallHistoryRecord(
            uri: URI(user: uri.user, host: "", displayName: uri.displayName),
            date: date,
            duration: duration,
            isIncoming: isIncoming,
            isMissed: isMissed
        )
    }
}

extension CallHistoryRecord: Equatable {
    public static func ==(lhs: CallHistoryRecord, rhs: CallHistoryRecord) -> Bool {
        return
            lhs.identifier == rhs.identifier &&
            lhs.uri == rhs.uri &&
            lhs.date == rhs.date &&
            lhs.duration == rhs.duration &&
            lhs.isIncoming == rhs.isIncoming &&
            lhs.isMissed == rhs.isMissed &&
            lhs.kind == rhs.kind
    }
}

extension CallHistoryRecord {
    public init(call: Call) {
        self.init(
            uri: call.remote,
            date: call.date,
            duration: call.duration,
            isIncoming: call.isIncoming,
            isMissed: call.isMissed
        )
    }
}
```

- [ ] **Step 2: Build to verify compilation**

```bash
cd /Users/aokunev/work/Telephone && xcodebuild -project Telephone.xcodeproj -scheme Telephone -configuration Debug -destination "platform=macOS,arch=x86_64" -derivedDataPath .derived CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY="" build 2>&1 | grep -E 'error:|BUILD'
```

Expected: BUILD SUCCEEDED (or fix any callers that need the new initializer signature)

- [ ] **Step 3: Commit**

```bash
git add UseCases/CallHistoryRecord.swift
git commit -m "feat: add HistoryRecordKind and text field to CallHistoryRecord"
```

---

### Task 2: Add AKSIPMessenger PJSIP bridge

**Files:**
- Create: `Telephone/AKSIPMessenger.h`
- Create: `Telephone/AKSIPMessenger.m`
- Modify: `Telephone/Telephone-Bridging-Header.h`
- Modify: `Telephone/AKSIPUserAgent.h`
- Modify: `Telephone/AKSIPUserAgent.m`

- [ ] **Step 1: Create AKSIPMessenger.h**

```objc
// Telephone/AKSIPMessenger.h

#import <Foundation/Foundation.h>
#import <pjsua-lib/pjsua.h>

@class AKSIPUserAgent;

NS_ASSUME_NONNULL_BEGIN

@interface AKSIPMessenger : NSObject

@property(nonatomic, weak) AKSIPUserAgent *userAgent;

- (instancetype)initWithUserAgent:(AKSIPUserAgent *)userAgent;

/// Send a text/plain MESSAGE via the given account.
- (pj_status_t)sendMessage:(NSString *)text
                        to:(NSString *)destinationURI
                 accountId:(pjsua_acc_id)accId;

/// Callback from PJSIP — processes incoming MESSAGE.
+ (void)onPagerCallbackWithCallId:(pjsua_call_id)callId
                             from:(const pj_str_t *)from
                               to:(const pj_str_t *)to
                          contact:(const pj_str_t *)contact
                        mimeType:(const pj_str_t *)mimeType
                             body:(const pj_str_t *)body
                           rdata:(pjsip_rx_data *)rdata
                           accId:(pjsua_acc_id)accId;

@end

NS_ASSUME_NONNULL_END
```

- [ ] **Step 2: Create AKSIPMessenger.m**

```objc
// Telephone/AKSIPMessenger.m

#import "AKSIPMessenger.h"
#import "AKSIPUserAgent.h"

@implementation AKSIPMessenger

- (instancetype)initWithUserAgent:(AKSIPUserAgent *)userAgent {
    self = [super init];
    if (self) {
        _userAgent = userAgent;
    }
    return self;
}

- (pj_status_t)sendMessage:(NSString *)text
                        to:(NSString *)destinationURI
                 accountId:(pjsua_acc_id)accId {
    pj_str_t to = pj_str((char *)[destinationURI UTF8String]);
    pj_str_t mime = pj_str("text/plain");
    pj_str_t content = pj_str((char *)[text UTF8String]);
    pjsua_msg_data msgData;
    pjsua_msg_data_init(&msgData);
    return pjsua_im_send(accId, &to, &mime, &content, &msgData, NULL);
}

+ (void)onPagerCallbackWithCallId:(pjsua_call_id)callId
                             from:(const pj_str_t *)from
                               to:(const pj_str_t *)to
                          contact:(const pj_str_t *)contact
                        mimeType:(const pj_str_t *)mimeType
                             body:(const pj_str_t *)body
                           rdata:(pjsip_rx_data *)rdata
                           accId:(pjsua_acc_id)accId {
    AKSIPUserAgent *agent = [AKSIPUserAgent sharedUserAgent];
    NSString *fromStr = [[NSString alloc] initWithBytes:from->ptr length:from->slen encoding:NSUTF8StringEncoding];
    NSString *bodyStr = [[NSString alloc] initWithBytes:body->ptr length:body->slen encoding:NSUTF8StringEncoding];
    [agent handleIncomingMessage:bodyStr from:fromStr];
}

@end
```

- [ ] **Step 3: Add import to bridging header**

In `Telephone/Telephone-Bridging-Header.h`, add after the existing imports:

```objc
#import "AKSIPMessenger.h"
```

- [ ] **Step 4: Add Messenger property and delegate method to AKSIPUserAgent.h**

```objc
// In AKSIPUserAgent.h, add:
@class AKSIPMessenger;

// Add property:
@property(nonatomic, readonly) AKSIPMessenger *messenger;

// Add method declaration:
- (void)handleIncomingMessage:(NSString *)body from:(NSString *)fromURI;
```

- [ ] **Step 5: Wire messenger in AKSIPUserAgent.m**

In `AKSIPUserAgent.m`, add to the `@interface` or `@implementation`:

```objc
// In init or start method, after PJSUA init:
_messenger = [[AKSIPMessenger alloc] initWithUserAgent:self];

// In the callback setup (around line 416), add:
userAgentConfig.cb.on_pager2 = &AKSIPMessengerOnPager2Callback;
```

Add the static callback bridge function (before `@implementation`):

```objc
static void AKSIPMessengerOnPager2Callback(pjsua_call_id call_id, const pj_str_t *from,
                                           const pj_str_t *to, const pj_str_t *contact,
                                           const pj_str_t *mime_type, const pj_str_t *body,
                                           pjsip_rx_data *rdata, pjsua_acc_id acc_id) {
    [AKSIPMessenger onPagerCallbackWithCallId:call_id from:from to:to
                                      contact:contact mimeType:mime_type body:body
                                        rdata:rdata accId:acc_id];
}
```

Add `handleIncomingMessage:from:`:

```objc
- (void)handleIncomingMessage:(NSString *)body from:(NSString *)fromURI {
    // Parse fromURI, create CallHistoryRecord, notify delegate
    // (wired via NSNotification or delegate callback in a later task)
}
```

- [ ] **Step 6: Build to verify compilation**

```bash
cd /Users/aokunev/work/Telephone && xcodebuild -project Telephone.xcodeproj -scheme Telephone -configuration Debug -destination "platform=macOS,arch=x86_64" -derivedDataPath .derived CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY="" build 2>&1 | grep -E 'error:|BUILD'
```

Expected: BUILD SUCCEEDED

- [ ] **Step 7: Commit**

```bash
git add Telephone/AKSIPMessenger.h Telephone/AKSIPMessenger.m Telephone/Telephone-Bridging-Header.h Telephone/AKSIPUserAgent.h Telephone/AKSIPUserAgent.m
git commit -m "feat: add AKSIPMessenger PJSIP IM bridge"
```

---

### Task 3: Add incoming message notification and delegate wiring

**Files:**
- Modify: `Telephone/AKSIPUserAgent.h` (delegate protocol)
- Modify: `Telephone/AKSIPUserAgent.m` (handleIncomingMessage + notification)
- Create: `Telephone/AKSIPUserAgentNotifications.h` (add new notification name)
- Modify: `Telephone/AKSIPUserAgentNotifications.m`

- [ ] **Step 1: Add notification name**

In `Telephone/AKSIPUserAgentNotifications.h`:

```objc
extern NSNotificationName const AKSIPUserAgentDidReceiveMessageNotification;
```

In `Telephone/AKSIPUserAgentNotifications.m`:

```objc
NSNotificationName const AKSIPUserAgentDidReceiveMessageNotification = @"AKSIPUserAgentDidReceiveMessage";
```

- [ ] **Step 2: Post notification in handleIncomingMessage**

```objc
// In AKSIPUserAgent.m handleIncomingMessage:from: :
- (void)handleIncomingMessage:(NSString *)body from:(NSString *)fromURI {
    NSDictionary *userInfo = @{
        @"body": body,
        @"from": fromURI
    };
    [[NSNotificationCenter defaultCenter]
        postNotificationName:AKSIPUserAgentDidReceiveMessageNotification
                      object:self
                    userInfo:userInfo];
}
```

- [ ] **Step 3: Build to verify compilation**

```bash
cd /Users/aokunev/work/Telephone && xcodebuild -project Telephone.xcodeproj -scheme Telephone -configuration Debug -destination "platform=macOS,arch=x86_64" -derivedDataPath .derived CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY="" build 2>&1 | grep -E 'error:|BUILD'
```

- [ ] **Step 4: Commit**

```bash
git add Telephone/AKSIPUserAgentNotifications.h Telephone/AKSIPUserAgentNotifications.m Telephone/AKSIPUserAgent.m
git commit -m "feat: add incoming message notification to AKSIPUserAgent"
```

---

### Task 4: Add MessageSendUseCase

**Files:**
- Create: `UseCases/MessageSendUseCase.swift`

- [ ] **Step 1: Create MessageSendUseCase.swift**

```swift
// UseCases/MessageSendUseCase.swift

import Foundation

public final class MessageSendUseCase: UseCase {
    private let text: String
    private let destination: String
    private let date: Date
    private let recordAdd: CallHistoryRecordAddUseCase
    private let send: (String, String) -> Bool

    public init(
        text: String,
        destination: String,
        date: Date,
        recordAdd: CallHistoryRecordAddUseCase,
        send: @escaping (String, String) -> Bool
    ) {
        self.text = text
        self.destination = destination
        self.date = date
        self.recordAdd = recordAdd
        self.send = send
    }

    public func execute() {
        guard send(text, destination) else { return }
        let record = CallHistoryRecord(
            uri: URI(user: destination, host: "", displayName: ""),
            date: date,
            isIncoming: false,
            text: text
        )
        recordAdd.add(record)
    }
}
```

- [ ] **Step 2: Build to verify compilation**

```bash
cd /Users/aokunev/work/Telephone && xcodebuild -project Telephone.xcodeproj -scheme Telephone -configuration Debug -destination "platform=macOS,arch=x86_64" -derivedDataPath .derived CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY="" build 2>&1 | grep -E 'error:|BUILD'
```

- [ ] **Step 3: Commit**

```bash
git add UseCases/MessageSendUseCase.swift
git commit -m "feat: add MessageSendUseCase"
```

---

### Task 5: Update PresentationCallHistoryRecord and CallHistoryViewPresenter for messages

**Files:**
- Modify: `Telephone/PresentationCallHistoryRecord.swift`
- Modify: `Telephone/CallHistoryViewPresenter.swift`

- [ ] **Step 1: Add kind and text to PresentationCallHistoryRecord**

```swift
// In PresentationCallHistoryRecord.swift, add properties:
@objc let kind: HistoryRecordKind
@objc let text: String?

// Update init to:
init(identifier: String, contact: PresentationContact, date: String, duration: String, isIncoming: Bool, kind: HistoryRecordKind, text: String?) {
    self.identifier = identifier
    self.contact = contact
    self.date = date
    self.duration = duration
    self.isIncoming = isIncoming
    self.kind = kind
    self.text = text
}

// Add computed property:
@objc var isMessage: Bool { return kind == .message }
@objc var cellText: String { return text ?? duration }
```

- [ ] **Step 2: Update makeRecord in CallHistoryViewPresenter**

In `CallHistoryViewPresenter.swift` `makeRecord(from:)`, add `kind` and `text`:

```swift
private func makeRecord(from record: ContactCallHistoryRecord) -> PresentationCallHistoryRecord {
    return PresentationCallHistoryRecord(
        identifier: record.origin.identifier,
        contact: PresentationContact(contact: record.contact, color: contactColor(for: record)),
        date: dateFormatter.string(from: record.origin.date),
        duration: durationFormatter.string(from: TimeInterval(record.origin.duration)) ?? "",
        isIncoming: record.origin.isIncoming,
        kind: record.origin.kind,
        text: record.origin.text
    )
}
```

- [ ] **Step 3: Build to verify compilation**

```bash
cd /Users/aokunev/work/Telephone && xcodebuild -project Telephone.xcodeproj -scheme Telephone -configuration Debug -destination "platform=macOS,arch=x86_64" -derivedDataPath .derived CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY="" build 2>&1 | grep -E 'error:|BUILD'
```

- [ ] **Step 4: Commit**

```bash
git add Telephone/PresentationCallHistoryRecord.swift Telephone/CallHistoryViewPresenter.swift
git commit -m "feat: add message properties to presentation record and presenter"
```

---

### Task 6: Update history table cell for message icons and text

**Files:**
- Modify: `Telephone/CallHistoryDateCellView.swift`

The history table uses `CallHistoryDateCellView` (an `NSTableCellView`) with
`dateField` (bound to `objectValue.date`) and `durationField` (bound to
`objectValue.duration`). Cocoa bindings populate these via the
`NSTableViewDataSource.objectValueFor` method, which returns
`PresentationCallHistoryRecord` instances.

- [ ] **Step 1: Update CallHistoryDateCellView to show message text instead of duration**

```swift
// CallHistoryDateCellView.swift — add message support:

import Cocoa

final class CallHistoryDateCellView: NSTableCellView {
    @IBOutlet private weak var dateField: NSTextField!
    @IBOutlet private weak var durationField: NSTextField!

    override var backgroundStyle: NSView.BackgroundStyle {
        didSet {
            switch backgroundStyle {
            case .normal, .raised, .lowered:
                dateField.textColor = .secondaryLabelColor
            case .emphasized:
                dateField.textColor = .labelColor
            @unknown default:
                break
            }
        }
    }

    override var objectValue: Any? {
        didSet {
            guard let record = objectValue as? PresentationCallHistoryRecord else { return }
            if record.isMessage {
                durationField.stringValue = record.cellText
                // Use SF Symbol speech bubble as image
                let symbolName = record.isIncoming ? "bubble.left" : "bubble.left.fill"
                imageView?.image = NSImage(systemSymbolName: symbolName, accessibilityDescription: nil)
                imageView?.contentTintColor = record.isIncoming ? .secondaryLabelColor : .controlAccentColor
            } else {
                // Existing call icon logic — preserve current behavior
                let symbolName = record.isIncoming ? "phone.arrow.down.left" : "phone.arrow.up.right"
                imageView?.image = NSImage(systemSymbolName: symbolName, accessibilityDescription: nil)
                if record.isMissed {
                    imageView?.contentTintColor = .systemRed
                } else {
                    imageView?.contentTintColor = record.isIncoming ? .secondaryLabelColor : .controlAccentColor
                }
            }
        }
    }
}
```

- [ ] **Step 2: Build to verify compilation**

```bash
cd /Users/aokunev/work/Telephone && xcodebuild -project Telephone.xcodeproj -scheme Telephone -configuration Debug -destination "platform=macOS,arch=x86_64" -derivedDataPath .derived CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY="" build 2>&1 | grep -E 'error:|BUILD'
```

- [ ] **Step 3: Commit**

```bash
git add Telephone/CallHistoryDateCellView.swift
git commit -m "feat: add message icons and text to history table cell"
```

---

### Task 7: Add Call and Send Text buttons to account window

**Files:**
- Modify: `Telephone/ActiveAccountViewController.h`
- Modify: `Telephone/ActiveAccountViewController.m`
- The `.xib` file must be edited (manual step in Xcode Interface Builder)

- [ ] **Step 1: Add IBAction declarations to ActiveAccountViewController.h**

```objc
- (IBAction)sendText:(id)sender;
```

(Existing `makeCall:` IBAction is already there.)

- [ ] **Step 2: Implement sendText in ActiveAccountViewController.m**

```objc
- (IBAction)sendText:(id)sender {
    // This will be connected to CompositionRoot wiring in Task 8.
    // For now, post a notification or call a block.
    if (self.messageSendBlock) {
        self.messageSendBlock([self.callDestinationField stringValue]);
    }
}
```

Add a block property:

```objc
// In ActiveAccountViewController.h:
@property(nonatomic, copy) void (^messageSendBlock)(NSString *destination);
```

- [ ] **Step 3: Add buttons in AccountView.xib via Interface Builder**

Open `Telephone/AccountView.xib` in Xcode. Add two `NSButton` instances to the right of the `NSTokenField` (call destination field):
- **Call** button — connect to `makeCall:` IBAction
- **Send Text** button — connect to `sendText:` IBAction

- [ ] **Step 4: Build to verify compilation**

```bash
cd /Users/aokunev/work/Telephone && xcodebuild -project Telephone.xcodeproj -scheme Telephone -configuration Debug -destination "platform=macOS,arch=x86_64" -derivedDataPath .derived CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY="" build 2>&1 | grep -E 'error:|BUILD'
```

- [ ] **Step 5: Commit**

```bash
git add Telephone/ActiveAccountViewController.h Telephone/ActiveAccountViewController.m Telephone/AccountView.xib
git commit -m "feat: add Call and Send Text buttons to account window"
```

---

### Task 8: Create message composition popup

**Files:**
- Create: `Telephone/MessageCompositionViewController.swift`

- [ ] **Step 1: Create MessageCompositionViewController.swift**

```swift
// Telephone/MessageCompositionViewController.swift

import Cocoa

final class MessageCompositionViewController: NSViewController {
    @IBOutlet private weak var destinationLabel: NSTextField!
    @IBOutlet private var textView: NSTextView!
    var onSend: ((String) -> Void)?
    var destination: String = ""

    convenience init() {
        self.init(nibName: "MessageCompositionViewController", bundle: nil)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        destinationLabel.stringValue = destination
    }

    @IBAction func send(_ sender: Any) {
        onSend?(textView.string)
        dismiss(self)
    }

    @IBAction func cancel(_ sender: Any) {
        dismiss(self)
    }
}
```

- [ ] **Step 2: Create MessageCompositionViewController.xib**

In Xcode, create a new View XIB:
- Window/Panel with title "Send Message"
- `NSTextField` (read-only) showing destination
- `NSTextView` with 4-5 rows for message body
- **Cancel** and **Send** buttons centered at bottom
- Connect outlets and actions to `MessageCompositionViewController`

- [ ] **Step 3: Build to verify compilation**

```bash
cd /Users/aokunev/work/Telephone && xcodebuild -project Telephone.xcodeproj -scheme Telephone -configuration Debug -destination "platform=macOS,arch=x86_64" -derivedDataPath .derived CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY="" build 2>&1 | grep -E 'error:|BUILD'
```

- [ ] **Step 4: Commit**

```bash
git add Telephone/MessageCompositionViewController.swift Telephone/MessageCompositionViewController.xib
git commit -m "feat: add message composition popup dialog"
```

---

### Task 9: Wire everything in CompositionRoot and AppController

**Files:**
- Modify: `Telephone/CompositionRoot.swift`
- Modify: `Telephone/AppController.m`

- [ ] **Step 1: Wire incoming message observer in CompositionRoot.swift**

```swift
// In CompositionRoot, add after userAgent setup:
NotificationCenter.default.addObserver(
    forName: AKSIPUserAgentDidReceiveMessageNotification,
    object: userAgent,
    queue: .main
) { [weak self] notification in
    guard let body = notification.userInfo?["body"] as? String,
          let from = notification.userInfo?["from"] as? String else { return }
    let record = CallHistoryRecord(
        uri: URI(user: from, host: "", displayName: ""),
        date: Date(),
        isIncoming: true,
        text: body
    )
    // add to history via callHistories or direct addUseCase
}
```

- [ ] **Step 2: Wire messageSendBlock to ActiveAccountViewController**

```swift
// In CompositionRoot, after account view controller creation:
activeAccountVC.messageSendBlock = { [weak self] destination in
    self?.showMessageComposition(for: destination)
}
```

- [ ] **Step 3: Add showMessageComposition method to CompositionRoot**

```swift
func showMessageComposition(for destination: String) {
    let vc = MessageCompositionViewController()
    vc.destination = destination
    vc.onSend = { [weak self] text in
        guard let self else { return }
        let useCase = MessageSendUseCase(
            text: text,
            destination: destination,
            date: Date(),
            recordAdd: self.callHistoryRecordAddUseCase, // need to store/access this
            send: { [weak selfUserAgent = userAgent] txt, dest in
                // Call PJSIP messenger
                let accId = /* current account ID */
                return selfUserAgent.messenger.sendMessage(txt, to: dest, accountId: accId) == PJ_SUCCESS
            }
        )
        useCase.execute()
    }
    // Present as sheet
    NSApplication.shared.keyWindow?.contentViewController?.presentAsSheet(vc)
}
```

- [ ] **Step 4: Build to verify compilation**

```bash
cd /Users/aokunev/work/Telephone && xcodebuild -project Telephone.xcodeproj -scheme Telephone -configuration Debug -destination "platform=macOS,arch=x86_64" -derivedDataPath .derived CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY="" build 2>&1 | grep -E 'error:|BUILD'
```

- [ ] **Step 5: Commit**

```bash
git add Telephone/CompositionRoot.swift Telephone/AppController.m
git commit -m "feat: wire messaging into CompositionRoot and AppController"
```

---

### Task 10: Manual XIB verification and end-to-end test

- [ ] **Step 1: Launch the app and verify UI**

```bash
killall Telephone 2>/dev/null
open /Users/aokunev/work/Telephone/.derived/Build/Products/Debug/Telephone.app
```

Check:
1. Account window shows **[Call]** and **[Send Text]** buttons next to address field
2. Clicking **[Send Text]** opens popup with destination pre-filled
3. Sending a message works (requires SIP server that supports MESSAGE)
4. Incoming messages appear in history with speech bubble icon
5. Call history still works correctly (calls show phone icons)

- [ ] **Step 2: Commit any final fixes**

```bash
git add -A
git commit -m "fix: final adjustments for SIP messaging feature"
```
