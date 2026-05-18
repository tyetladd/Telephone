//
//  MessageSendUseCase.swift
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
