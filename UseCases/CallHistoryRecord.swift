//
//  CallHistoryRecord.swift
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

import CommonCrypto
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

    public init(uri: URI, date: Date, isIncoming: Bool, text: String) {
        identifier = "\(uri.user)@\(uri.host)|\(date.timeIntervalSinceReferenceDate)|\(stableHash(text))"
        self.uri = uri
        self.date = date
        self.duration = 0
        self.isIncoming = isIncoming
        self.isMissed = false
        self.kind = .message
        self.text = text
    }

    public func removingHost() -> CallHistoryRecord {
        let newURI = URI(user: uri.user, host: "", displayName: uri.displayName)
        if kind == .message, let text = text {
            return CallHistoryRecord(uri: newURI, date: date, isIncoming: isIncoming, text: text)
        }
        return CallHistoryRecord(
            uri: newURI,
            date: date,
            duration: duration,
            isIncoming: isIncoming,
            isMissed: isMissed
        )
    }
}

private func stableHash(_ text: String) -> String {
    guard let data = text.data(using: .utf8) else { return "0" }
    var hash = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
    data.withUnsafeBytes { _ = CC_SHA256($0.baseAddress, CC_LONG(data.count), &hash) }
    return hash.prefix(8).map { String(format: "%02x", $0) }.joined()
}

extension CallHistoryRecord: Equatable {
    public static func ==(lhs: CallHistoryRecord, rhs: CallHistoryRecord) -> Bool {
        return lhs.identifier == rhs.identifier
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
