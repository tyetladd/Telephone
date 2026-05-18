//
//  PersistentCallHistory.swift
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

import Foundation

public final class PersistentCallHistory {
    private let origin: CallHistory
    private let storage: PropertyListStorage

    public init(origin: CallHistory, storage: PropertyListStorage) {
        precondition(origin.allRecords.count == 0)
        self.origin = origin
        self.storage = storage
        load()
    }

    private func load() {
        do {
            try storage.load().forEach({ origin.add(CallHistoryRecord(dictionary: $0)) })
        } catch {
            print("Could not read call history from file: \(error)")
        }
    }
}

extension PersistentCallHistory: CallHistory {
    public var allRecords: [CallHistoryRecord] {
        return origin.allRecords
    }

    public func add(_ record: CallHistoryRecord) {
        origin.add(record)
        save()
    }

    public func remove(_ record: CallHistoryRecord) {
        origin.remove(record)
        save()
    }

    public func removeAll() {
        origin.removeAll()
        do {
            try storage.delete()
        } catch {
            print("Could not delete call history file: \(error)")
        }
    }

    public func updateTarget(_ target: CallHistoryEventTarget) {
        origin.updateTarget(target)
    }

    private func save() {
        do {
            try storage.save(dictionaries(from: origin.allRecords))
        } catch {
            print("Could not save call history to file: \(error)")
        }
    }
}

private extension CallHistoryRecord {
    init(dictionary: [String: Any]) {
        let uri = URI(
            user: dictionary[Keys.user.rawValue] as? String ?? "",
            host: dictionary[Keys.host.rawValue] as? String ?? "",
            displayName: dictionary[Keys.name.rawValue] as? String ?? ""
        )
        let date = dictionary[Keys.date.rawValue] as? Date ?? Date.distantPast
        let kindRaw = dictionary[Keys.kind.rawValue] as? String
        let kind = kindRaw.flatMap(HistoryRecordKind.init(rawValue:)) ?? .call
        if kind == .message {
            let text = dictionary[Keys.text.rawValue] as? String ?? ""
            self.init(uri: uri, date: date, isIncoming: dictionary[Keys.incoming.rawValue] as? Bool ?? false, text: text)
        } else {
            self.init(
                uri: uri,
                date: date,
                duration: dictionary[Keys.duration.rawValue] as? Int ?? 0,
                isIncoming: dictionary[Keys.incoming.rawValue] as? Bool ?? false,
                isMissed: dictionary[Keys.missed.rawValue] as? Bool ?? false
            )
        }
    }
}

private func dictionaries(from records: [CallHistoryRecord]) -> [[String: Any]] {
    return records.map { record in
        var dict: [String: Any] = [
            Keys.user.rawValue: record.uri.user,
            Keys.host.rawValue: record.uri.host,
            Keys.name.rawValue: record.uri.displayName,
            Keys.date.rawValue: record.date,
            Keys.duration.rawValue: record.duration,
            Keys.incoming.rawValue: record.isIncoming,
            Keys.missed.rawValue: record.isMissed,
            Keys.kind.rawValue: record.kind.rawValue,
        ]
        if let text = record.text {
            dict[Keys.text.rawValue] = text
        }
        return dict
    }
}

private enum Keys: String {
    case user, host, name, date, duration, incoming, missed, kind, text
}
