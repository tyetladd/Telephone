//
//  CompositionRoot.swift
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

import Contacts
import Foundation
import UseCases
import os

final class CompositionRoot: NSObject {
    @objc let userAgent: AKSIPUserAgent
    @objc let preferencesController: PreferencesController
    @objc let ringtonePlayback: RingtonePlaybackUseCase
    @objc let userAgentStart: UseCase
    @objc let settingsMigration: ProgressiveSettingsMigration
    @objc let orphanLogFileRemoval: OrphanLogFileRemoval
    @objc let workstationSleepStatus: WorkspaceSleepStatus
    @objc let callHistoryViewEventTargetFactory: AsyncCallHistoryViewEventTargetFactory
    @objc let logFileURL: LogFileURL
    @objc let defaultAppSettings: DefaultAppSettings
    @objc let helpMenuActionTarget: HelpMenuActionTarget
    @objc let accountControllers: AccountControllers
    @objc let nameServers: NameServers
    private let defaults: UserDefaults
    private var messageWindowControllers: [NSWindowController] = []

    private let userAgentEventSource: AKSIPUserAgentEventSource
    private let devicesChangeEventSource: CoreAudioSystemAudioDevicesChangeEventSource
    private let soundIOChangeEventSource: CoreAudioDefaultSystemSoundIOChangeEventSource
    private let accountsEventSource: PreferencesControllerAccountsEventSource
    private let callEventSource: AKSIPCallEventSource
    private let contactsChangeEventSource: Any
    private let dayChangeEventSource: NSCalendarDayChangeEventSource
    private let callHistories: DefaultCallHistories

    @objc init(preferencesControllerDelegate: PreferencesControllerDelegate, nameServersChangeEventTarget: NameServersChangeEventTarget) {
        userAgent = AKSIPUserAgent.shared()
        defaults = UserDefaults.standard

        let systemAudioDevicesFactory = CoreAudioSystemAudioDevicesFactory(objectIDs: CoreAudioDevicesAudioObjectIDs())

        let useCaseFactory = DefaultUseCaseFactory(factory: systemAudioDevicesFactory, settings: defaults)

        let soundIOFactory = PreferredSoundIOFactory(
            devicesFactory: systemAudioDevicesFactory,
            defaultIOFactory: CoreAudioDefaultSystemSoundIOFactory(defaultIO: CoreAudioDefaultIO()),
            settings: defaults
        )

        let soundFactory = SimpleSoundFactory(
            load: SettingsRingtoneSoundConfigurationLoadUseCase(settings: defaults, factory: soundIOFactory),
            factory: NSSoundToSoundAdapterFactory()
        )

        ringtonePlayback = ConditionalRingtonePlaybackUseCase(
            origin: DefaultRingtonePlaybackUseCase(
                factory: RepeatingSoundFactory(
                    soundFactory: soundFactory,
                    timerFactory: FoundationToUseCasesTimerAdapterFactory()
                )
            ),
            delegate: userAgent
        )

        userAgentStart = UserAgentStartUseCase(agent: userAgent, maxCalls: 30)

        let userAgentEventsUserAgentSoundIOSelection = UserAgentEventsUserAgentSoundIOSelectionUseCase(
            useCase: UserAgentSoundIOSelectionUseCase(
                devicesFactory: systemAudioDevicesFactory, soundIOFactory: soundIOFactory, agent: userAgent
            ),
            agent: userAgent,
            calls: userAgent
        )

        let userAgentSoundIOSelection = AudioDevicesEventsUserAgentSoundIOSelectionUseCase(
            origin: userAgentEventsUserAgentSoundIOSelection
        )

        preferencesController = PreferencesController(
            delegate: preferencesControllerDelegate,
            userAgent: userAgent,
            soundPreferencesViewEventTarget: SoundPreferencesViewEventTarget(
                useCaseFactory: useCaseFactory,
                presenterFactory: PresenterFactory(),
                userAgentSoundIOSelection: userAgentSoundIOSelection,
                ringtoneOutputUpdate: RingtoneOutputUpdateUseCase(playback: ringtonePlayback),
                ringtoneSoundPlayback: DefaultSoundPlaybackUseCase(factory: soundFactory)
            )
        )

        settingsMigration = ProgressiveSettingsMigration(
            settings: defaults, factory: DefaultSettingsMigrationFactory(settings: defaults)
        )

        let applicationDataLocations = DirectoryCreatingApplicationDataLocations(
            origin: SimpleApplicationDataLocations(manager: FileManager.default, bundle: Bundle.main),
            manager: FileManager.default
        )

        orphanLogFileRemoval = OrphanLogFileRemoval(locations: applicationDataLocations, manager: FileManager.default)

        workstationSleepStatus = WorkspaceSleepStatus(workspace: NSWorkspace.shared)

        userAgentEventSource = AKSIPUserAgentEventSource(
            target: UserAgentEventTargets(
                targets: [
                    userAgentEventsUserAgentSoundIOSelection,
                    BackgroundActivityUserAgentEventTarget(process: ProcessInfo.processInfo)
                ]
            ),
            agent: userAgent
        )

        let background = DispatchQueue(label: Bundle.main.bundleIdentifier! + ".background-queue", qos: .userInitiated)

        devicesChangeEventSource = CoreAudioSystemAudioDevicesChangeEventSource(
            target: SystemAudioDevicesChangeEventTargets(
                targets: [
                    UserAgentAudioDeviceUpdateUseCase(agent: userAgent),
                    userAgentSoundIOSelection,
                    PreferencesSoundIOUpdater(preferences: preferencesController)
                ]
            ),
            queue: background
        )

        soundIOChangeEventSource = CoreAudioDefaultSystemSoundIOChangeEventSource(
            target: userAgentSoundIOSelection, queue: background
        )

        self.callHistories = DefaultCallHistories(
            factory: NotifyingCallHistoryFactory(
            origin: ReversedCallHistoryFactory(
                origin: PersistentCallHistoryFactory(
                    history: TruncatingCallHistoryFactory(),
                    storage: SimplePropertyListStorageFactory(manager: FileManager.default),
                    locations: applicationDataLocations
                )
            )
        )
        )

        let contactsBackground = GCDExecutionQueue(queue: background)

        accountsEventSource = PreferencesControllerAccountsEventSource(
            center: NotificationCenter.default,
            target: EnqueuingAccountsEventTarget(
                origin: CallHistoriesHistoryRemoveUseCase(histories: callHistories), queue: contactsBackground
            )
        )

        callEventSource = AKSIPCallEventSource(
            center: NotificationCenter.default,
            target: CallEventTargets(
                targets: [
                    EnqueuingCallEventTarget(
                        origin: CallHistoryCallEventTarget(
                            histories: callHistories, factory: DefaultCallHistoryRecordAddUseCaseFactory()
                        ),
                        queue: contactsBackground
                    ),
                    MusicPlayerCallEventTarget(
                        player: SettingsMusicPlayer(
                            origin: CallsMusicPlayer(
                                origin: AvailableMusicPlayers(factory: MusicPlayerFactory()), calls: userAgent
                            ),
                            settings: SimpleMusicPlayerSettings(settings: defaults)
                        )
                    ),
                    RingtonePlaybackCallEventTarget(playback: ringtonePlayback),
                    UserAttentionRequestCallEventTarget(
                        request: CallsUserAttentionRequest(
                            origin: ApplicationUserAttentionRequest(
                                application: NSApp, center: NotificationCenter.default
                            ),
                            calls: userAgent
                        )
                    )
                ]
            )
        )

        let contactMatchingSettings = SimpleContactMatchingSettings(settings: defaults)
        let contactMatchingIndex = LazyDiscardingContactMatchingIndex(
            factory: SimpleContactMatchingIndexFactory(
                contacts: CNContactStoreToContactsAdapter(), settings: contactMatchingSettings
            )
        )

        contactsChangeEventSource = CNContactStoreContactsChangeEventSource(
            center: NotificationCenter.default,
            target: EnqueuingContactsChangeEventTarget(origin: contactMatchingIndex, queue: contactsBackground)
        )

        let dayChangeEventTargets = DayChangeEventTargets()
        dayChangeEventSource = NSCalendarDayChangeEventSource(center: NotificationCenter.default, target: dayChangeEventTargets)

        let main = GCDExecutionQueue(queue: DispatchQueue.main)

        callHistoryViewEventTargetFactory = AsyncCallHistoryViewEventTargetFactory(
            origin: CallHistoryViewEventTargetFactory(
                histories: callHistories,
                index: contactMatchingIndex,
                settings: contactMatchingSettings,
                dateFormatter: ShortRelativeDateTimeFormatter(),
                durationFormatter: DurationFormatter(),
                dayChangeEventTargets: dayChangeEventTargets,
                background: contactsBackground,
                main: main
            ),
            background: contactsBackground,
            main: main
        )

        logFileURL = LogFileURL(locations: applicationDataLocations, filename: "Telephone.log")

        defaultAppSettings = DefaultAppSettings(
            settings: defaults, localization: Bundle.main.preferredLocalizations.first ?? ""
        )

        helpMenuActionTarget = HelpMenuActionTarget(
            logFileURL: logFileURL,
            homepageURL: URL(string: "https://www.64characters.com/telephone/")!,
            faqURL: URL(string: "https://www.64characters.com/telephone/faq/")!,
            fileBrowser: NSWorkspace.shared,
            webBrowser: NSWorkspace.shared,
            clipboard: NSPasteboard.general,
            settings: AppSettings(
                settings: defaults,
                defaults: defaultAppSettings.defaults,
                accountDefaults: DefaultAppSettings.accountDefaults
            )
        )

        accountControllers = AccountControllers()

        nameServers = NameServers(bundle: Bundle.main, target: nameServersChangeEventTarget)

        super.init()

        setupMessageObservers()
    }

    private func setupMessageObservers() {
        // Observe incoming SIP messages to add to call history
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name.AKSIPUserAgentDidReceiveMessage,
            object: userAgent,
            queue: .main
        ) { [weak self] notification in
            guard let self,
                  let body = notification.userInfo?["body"] as? String,
                  let from = notification.userInfo?["from"] as? String else { return }
            guard let controller = self.accountControllers.enabled.first else { return }
            let (fromUser, fromHost) = Self.components(ofSIPURI: from)
            let record = CallHistoryRecord(
                uri: URI(user: fromUser, host: fromHost.isEmpty ? controller.account.domain : fromHost, displayName: ""),
                date: Date(),
                isIncoming: true,
                text: body
            )
            let history = callHistories.history(withUUID: controller.account.uuid)
            CallHistoryRecordAddUseCase(history: history, record: record, domain: controller.account.domain).add(record)
            if let sound = NSSound(named: "Ping") {
                sound.play()
            }
        }

        // Observe message composition requests from ObjC side
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name.TelephoneDidRequestMessageComposition,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self,
                  let destination = notification.userInfo?["destination"] as? String,
                  !destination.isEmpty else { return }
            let messageVC = MessageCompositionViewController()
            messageVC.destination = destination
            messageVC.onSend = { [weak self] text in
                guard let self else { return }
                guard let controller = self.accountControllers.enabled.first else {
                    os_log("No enabled account found to send message to %{public}@", log: .default, type: .error, destination)
                    return
                }
                let accId = Int32(controller.account.identifier)
                let uri: String
                if destination.contains("@") {
                    uri = destination.hasPrefix("sip:") ? destination : "sip:\(destination)"
                } else {
                    uri = "sip:\(destination)@\(controller.account.domain)"
                }
                let status = self.userAgent.messenger.sendMessage(text, to: uri, accountId: accId)
                guard status == 0 else {
                    os_log("Failed to send message to %{public}@, status: %d", log: .default, type: .error, uri, status)
                    return
                }
                let record = CallHistoryRecord(
                    uri: URI(user: destination, host: controller.account.domain, displayName: ""),
                    date: Date(),
                    isIncoming: false,
                    text: text
                )
                let history = self.callHistories.history(withUUID: controller.account.uuid)
                CallHistoryRecordAddUseCase(history: history, record: record, domain: controller.account.domain).add(record)
                os_log("Outgoing message added to history: %{public}@", log: .default, type: .info, String(text.prefix(30)))
            }
            let wc = MessageCompositionWindowController(viewController: messageVC)
            self.messageWindowControllers.append(wc)
            NotificationCenter.default.addObserver(
                forName: NSWindow.willCloseNotification,
                object: wc.window,
                queue: .main
            ) { [weak self, weak wc] _ in
                guard let wc else { return }
                self?.messageWindowControllers.removeAll { $0 === wc }
            }
            wc.showWindow(nil)
        }
    }

    // Extracts (user, host) from a raw SIP From-header value such as:
    //   "sip:alice@example.com"
    //   "Alice <sip:alice@example.com;transport=UDP>"
    private static func components(ofSIPURI raw: String) -> (user: String, host: String) {
        var s = raw.trimmingCharacters(in: .whitespaces)
        if let lt = s.range(of: "<"), let gt = s.range(of: ">") {
            s = String(s[lt.upperBound..<gt.lowerBound])
        }
        for prefix in ["sips:", "sip:"] where s.lowercased().hasPrefix(prefix) {
            s = String(s.dropFirst(prefix.count)); break
        }
        if let semi = s.firstIndex(of: ";") { s = String(s[..<semi]) }
        if let at = s.lastIndex(of: "@") {
            let user = String(s[..<at])
            var host = String(s[s.index(after: at)...])
            if let colon = host.lastIndex(of: ":") { host = String(host[..<colon]) }
            return (user, host)
        }
        return (s, "")
    }
}
