import Foundation

struct CodexEventBridgeHealth: Sendable, Equatable {
    let isReady: Bool
    let code: String?
}

struct CodexCompletionPollReceipt: Sendable, Equatable {
    let signals: [CodexTaskSignal]
    let eventBridgeHealth: CodexEventBridgeHealth
}

/// Owns transport polling, restart baselining, deduplication and bridge health.
/// Envelope decoding and privacy projection live in `CompanionEventIngress`.
actor CodexCompletionWatcher {
    private let root: URL
    private let protocolRoot: URL
    private let startedAt: Date
    private let legacySessionsEnabled: Bool
    private var offsets: [String: UInt64] = [:]
    private var ignoredFiles: Set<String> = []
    private var deliveredIDs: Set<String> = []
    private var deliveredProtocolIDs: Set<String> = []
    private var deliveredProtocolIDOrder: [String] = []
    private var primedSignals: [CodexTaskSignal] = []
    private var protocolInboxPrimed = false
    private var eventSpool = CompanionEventSpool()

    init(
        root: URL? = nil,
        protocolRoot: URL? = nil,
        startedAt: Date = Date(),
        legacySessionsEnabled: Bool = false
    ) {
        self.root = root ?? FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".codex/sessions", isDirectory: true)
        self.protocolRoot = protocolRoot ?? FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        )[0]
            .appendingPathComponent("Chengyin", isDirectory: true)
            .appendingPathComponent("events", isDirectory: true)
        self.startedAt = startedAt
        self.legacySessionsEnabled = legacySessionsEnabled
    }

    func prime() {
        _ = CompanionEventBridgeRepairer().repair(root: protocolRoot)
        primeProtocolInbox()
        guard legacySessionsEnabled else { return }
        for url in recentSessionFiles() {
            let path = url.path
            offsets[path] = fileSize(url)
            if isCompanionSession(url) {
                ignoredFiles.insert(path)
            }
        }
    }

    func protocolBridgeIsReady() -> Bool {
        eventSpool.inspectRoot(protocolRoot) == .ready
    }

    func protocolBridgeHealth() -> CodexEventBridgeHealth {
        let status = eventSpool.inspectRoot(protocolRoot)
        return CodexEventBridgeHealth(
            isReady: status == .ready,
            code: status.companionErrorCode
        )
    }

    func repairProtocolBridge() -> CompanionEventBridgeRepairReceipt {
        CompanionEventBridgeRepairer().repair(root: protocolRoot)
    }

    func poll() -> [CodexTaskSignal] {
        pollWithHealth().signals
    }

    func pollWithHealth(now: Date = Date()) -> CodexCompletionPollReceipt {
        let spoolReceipt = eventSpool.scan(root: protocolRoot, now: now)
        var signals = primedSignals
        primedSignals.removeAll(keepingCapacity: true)
        signals.append(contentsOf: pollProtocolEvents(spoolReceipt))
        guard legacySessionsEnabled else {
            return pollReceipt(signals: signals, spoolReceipt: spoolReceipt)
        }
        for url in recentSessionFiles() {
            let path = url.path
            if ignoredFiles.contains(path) { continue }
            if isCompanionSession(url) {
                ignoredFiles.insert(path)
                continue
            }

            let size = fileSize(url)
            let previous = offsets[path] ?? 0
            guard size > previous else {
                offsets[path] = size
                continue
            }

            guard let handle = try? FileHandle(forReadingFrom: url) else { continue }
            defer { try? handle.close() }
            try? handle.seek(toOffset: previous)
            let data = (try? handle.readToEnd()) ?? Data()
            offsets[path] = size

            guard let text = String(data: data, encoding: .utf8) else { continue }
            for line in text.split(separator: "\n") {
                guard
                    let row = try? JSONSerialization.jsonObject(
                        with: Data(line.utf8)
                    ) as? [String: Any],
                    row["type"] as? String == "event_msg",
                    let payload = row["payload"] as? [String: Any],
                    payload["type"] as? String == "task_complete",
                    let id = payload["turn_id"] as? String,
                    !deliveredIDs.contains(id)
                else { continue }

                let completedAt = (payload["completed_at"] as? NSNumber)?.doubleValue ?? 0
                guard completedAt >= startedAt.timeIntervalSince1970 - 3 else { continue }
                deliveredIDs.insert(id)
                let milliseconds = (payload["duration_ms"] as? NSNumber)?.doubleValue ?? 0
                signals.append(
                    CodexTaskSignal(
                        id: id,
                        duration: milliseconds / 1_000,
                        type: .responseReady,
                        outcome: .unknown,
                        occurredAt: Date(timeIntervalSince1970: completedAt),
                        origin: .legacyTurnBoundary
                    )
                )
            }
        }
        return pollReceipt(signals: signals, spoolReceipt: spoolReceipt)
    }

    private func pollProtocolEvents(
        _ spoolReceipt: CompanionEventSpoolScanReceipt
    ) -> [CodexTaskSignal] {
        var signals: [CodexTaskSignal] = []
        for entry in spoolReceipt.entries {
            guard
                let signal = CodexProtocolEventExtractor.signal(
                    from: entry.data,
                    startedAt: startedAt
                ),
                signal.id.caseInsensitiveCompare(entry.eventID) == .orderedSame,
                insertProtocolEventID(signal.id)
            else {
                continue
            }

            signals.append(signal)
        }
        return signals
    }

    /// Establishes a restart boundary before normal polling. Safe events that
    /// predate this watcher become a deduplication baseline and are not replayed;
    /// events created after watcher construction but before `prime()` are held
    /// for the first poll so startup does not lose a legitimate fresh signal.
    private func primeProtocolInbox() {
        guard !protocolInboxPrimed else { return }
        protocolInboxPrimed = true
        let receipt = eventSpool.scan(root: protocolRoot)
        guard receipt.isReady else { return }

        for entry in receipt.entries {
            guard
                let signal = CodexProtocolEventExtractor.signal(
                    from: entry.data,
                    startedAt: .distantPast
                ),
                signal.id.caseInsensitiveCompare(entry.eventID) == .orderedSame,
                insertProtocolEventID(signal.id)
            else {
                continue
            }
            if signal.occurredAt >= startedAt {
                primedSignals.append(signal)
            }
        }
    }

    private func pollReceipt(
        signals: [CodexTaskSignal],
        spoolReceipt: CompanionEventSpoolScanReceipt
    ) -> CodexCompletionPollReceipt {
        let sortedSignals = signals.sorted {
            if $0.occurredAt == $1.occurredAt {
                return $0.id < $1.id
            }
            return $0.occurredAt < $1.occurredAt
        }
        return CodexCompletionPollReceipt(
            signals: sortedSignals,
            eventBridgeHealth: CodexEventBridgeHealth(
                isReady: spoolReceipt.isReady,
                code: spoolReceipt.companionErrorCode
            )
        )
    }

    private func insertProtocolEventID(_ eventID: String) -> Bool {
        guard !deliveredProtocolIDs.contains(eventID) else {
            return false
        }

        deliveredProtocolIDs.insert(eventID)
        deliveredProtocolIDOrder.append(eventID)
        if deliveredProtocolIDOrder.count > 512 {
            let removed = deliveredProtocolIDOrder.removeFirst()
            deliveredProtocolIDs.remove(removed)
        }
        return true
    }

    private func recentSessionFiles() -> [URL] {
        guard let enumerator = FileManager.default.enumerator(
            at: root,
            includingPropertiesForKeys: [
                .isRegularFileKey,
                .contentModificationDateKey
            ],
            options: [.skipsHiddenFiles]
        ) else { return [] }

        let cutoff = Date().addingTimeInterval(-36 * 60 * 60)
        var results: [URL] = []
        for case let url as URL in enumerator where url.pathExtension == "jsonl" {
            guard
                let values = try? url.resourceValues(
                    forKeys: [.isRegularFileKey, .contentModificationDateKey]
                ),
                values.isRegularFile == true,
                (values.contentModificationDate ?? .distantPast) >= cutoff
            else { continue }
            results.append(url)
        }
        return results
    }

    private func fileSize(_ url: URL) -> UInt64 {
        let attributes = try? FileManager.default.attributesOfItem(atPath: url.path)
        return (attributes?[.size] as? NSNumber)?.uint64Value ?? 0
    }

    private func isCompanionSession(_ url: URL) -> Bool {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return false }
        defer { try? handle.close() }
        let data = (try? handle.read(upToCount: 32_768)) ?? Data()
        guard let text = String(data: data, encoding: .utf8) else { return false }
        return text.contains("/ChengyinCompanion")
            || text.contains("\\/ChengyinCompanion")
    }
}
