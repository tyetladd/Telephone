//
//  DebugConsoleWindowController.swift
//  Telephone
//
//  Copyright © 2025
//
//  Telephone is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  Telephone is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//

import Cocoa

@objcMembers
final class DebugConsoleWindowController: NSWindowController {
    static let shared = DebugConsoleWindowController()

    private let textView = NSTextView()
    private var notificationToken: NSObjectProtocol?
    private let logBuffer = PJSIPLogBuffer.shared()

    private override init(window: NSWindow?) {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 900, height: 500),
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = NSLocalizedString("PJSIP Debug Console", comment: "Window title for the debug console")
        window.isReleasedWhenClosed = false
        window.center()

        super.init(window: window)
        configureContent()
        reloadFromBuffer()
        startObserving()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        stopObserving()
    }

    func showWindowCentered() {
        window?.center()
        showWindow(self)
    }
}

// MARK: - Private

private extension DebugConsoleWindowController {
    func configureContent() {
        guard let contentView = window?.contentView else { return }

        let scrollView = NSScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.borderType = .bezelBorder

        textView.isEditable = false
        textView.isSelectable = true
        textView.font = NSFont.monospacedSystemFont(ofSize: 11, weight: .regular)
        textView.textContainerInset = NSSize(width: 6, height: 8)
        textView.autoresizingMask = .width

        scrollView.documentView = textView
        contentView.addSubview(scrollView)

        NSLayoutConstraint.activate([
            scrollView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: contentView.topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor)
        ])
    }

    func reloadFromBuffer() {
        textView.string = logBuffer.combinedLog()
        appendTrailingNewlineIfNeeded()
        scrollToBottom()
    }

    func startObserving() {
        notificationToken = NotificationCenter.default.addObserver(
            forName: .PJSIPLogBufferDidAppendEntry,
            object: logBuffer,
            queue: .main
        ) { [weak self] notification in
            guard
                let self,
                let message = notification.userInfo?[PJSIPLogBufferMessageUserInfoKey] as? String
            else { return }
            self.append(message)
        }
    }

    func stopObserving() {
        if let token = notificationToken {
            NotificationCenter.default.removeObserver(token)
        }
        notificationToken = nil
    }

    func append(_ message: String) {
        if !textView.string.isEmpty {
            textView.string.append("\n")
        }
        textView.string.append(message)
        scrollToBottom()
    }

    func appendTrailingNewlineIfNeeded() {
        if !textView.string.isEmpty && !textView.string.hasSuffix("\n") {
            textView.string.append("\n")
        }
    }

    func scrollToBottom() {
        let length = (textView.string as NSString).length
        textView.scrollRangeToVisible(NSRange(location: length, length: 0))
    }
}
