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
        setIcon(symbolName: record.isIncoming ? "bubble.left" : "bubble.left.fill",
                tint: record.isIncoming ? .secondaryLabelColor : .labelColor)
    }

    func configureForCall(_ record: PresentationCallHistoryRecord) {
        if record.isIncoming {
            setIcon(symbolName: "phone.arrow.down.left",
                    tint: record.isMissed ? .systemRed : .secondaryLabelColor)
        } else {
            setIcon(symbolName: "phone.arrow.up.right",
                    tint: .secondaryLabelColor)
        }
    }

    func setIcon(symbolName: String, tint: NSColor) {
        if imageView == nil {
            let iv = NSImageView()
            iv.translatesAutoresizingMaskIntoConstraints = false
            iv.imageScaling = .scaleProportionallyDown
            addSubview(iv)
            NSLayoutConstraint.activate([
                iv.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 4),
                iv.centerYAnchor.constraint(equalTo: centerYAnchor),
                iv.widthAnchor.constraint(equalToConstant: 16),
                iv.heightAnchor.constraint(equalToConstant: 16)
            ])
            imageView = iv
        }
        imageView?.image = NSImage(systemSymbolName: symbolName, accessibilityDescription: nil)
        imageView?.contentTintColor = tint
    }
}
