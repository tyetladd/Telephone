//
//  CallHistoryDateCellView.swift
//  Telephone
//
//  Copyright © 2008-2016 Alexey Kuznetsov
//  Copyright © 2016-2022 64 Characters
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
                configureForMessage(record)
            } else {
                configureForCall(record)
            }
        }
    }
}

private extension CallHistoryDateCellView {
    func configureForMessage(_ record: PresentationCallHistoryRecord) {
        durationField.stringValue = record.cellText
        ensureImageView()
        imageView?.image = NSImage(systemSymbolName: record.isIncoming ? "bubble.left" : "bubble.left.fill", accessibilityDescription: nil)
        imageView?.contentTintColor = record.isIncoming ? .secondaryLabelColor : .labelColor
    }

    func configureForCall(_ record: PresentationCallHistoryRecord) {
        ensureImageView()
        if record.isIncoming {
            imageView?.image = NSImage(systemSymbolName: "phone.arrow.down.left", accessibilityDescription: nil)
            imageView?.contentTintColor = record.isMissed ? .systemRed : .secondaryLabelColor
        } else {
            imageView?.image = NSImage(systemSymbolName: "phone.arrow.up.right", accessibilityDescription: nil)
            imageView?.contentTintColor = .secondaryLabelColor
        }
    }

    func ensureImageView() {
        guard imageView == nil else { return }
        let view = NSImageView()
        view.translatesAutoresizingMaskIntoConstraints = false
        addSubview(view)
        NSLayoutConstraint.activate([
            view.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 0),
            view.centerYAnchor.constraint(equalTo: centerYAnchor),
            view.widthAnchor.constraint(equalToConstant: 16),
            view.heightAnchor.constraint(equalToConstant: 16)
        ])
        imageView = view
    }
}
