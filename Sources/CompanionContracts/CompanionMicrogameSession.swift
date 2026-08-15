import Foundation

/// The deterministic part of Chengyin's built-in micro-games.
///
/// AppKit owns windows, audio, haptics and timers. This value owns only bounded
/// progress and input decisions so contributors can change a game without
/// reaching into the application view model or observing private user data.
public enum CompanionMicrogameKind: String, Codable, CaseIterable, Sendable {
    case catchPet
    case hideAndSeek
    case gestureCombo
    case heartTrace
    case rhythm
    case feed
}

public enum CompanionMicrogameGesture: String, Codable, CaseIterable, Sendable {
    case tap
    case hold
    case fling
    case other
}

public enum CompanionMicrogameInputOutcome: Equatable, Sendable {
    case ignored
    case advanced
    case completed
    case reset
    case missed
}

public struct CompanionNormalizedPoint: Equatable, Sendable {
    public let x: Double
    public let y: Double

    public init(x: Double, y: Double) {
        self.x = x
        self.y = y
    }
}

/// One ephemeral, content-free play session. It is intentionally not persisted:
/// quitting a game never creates a streak, debt, identity or behavioural log.
public struct CompanionMicrogameSession: Equatable, Sendable {
    public static let catchTarget = 5
    public static let hideTarget = 5
    public static let comboTarget = 3
    public static let rhythmBeatCount = 8
    public static let rhythmMinimumHits = 6
    public static let rhythmMinimumBestCombo = 3
    public static let feedTarget = 3
    public static let heartTraceTolerance = 0.24
    public static let rhythmTapTolerance: TimeInterval = 0.44

    public static let heartTraceGuide: [CompanionNormalizedPoint] = [
        .init(x: 0.00, y: -0.68),
        .init(x: -0.48, y: -0.28),
        .init(x: -0.72, y: 0.18),
        .init(x: -0.46, y: 0.64),
        .init(x: 0.00, y: 0.32),
        .init(x: 0.46, y: 0.64),
        .init(x: 0.72, y: 0.18),
        .init(x: 0.48, y: -0.28),
        .init(x: 0.00, y: -0.68)
    ]

    public private(set) var activeGame: CompanionMicrogameKind?
    public private(set) var score = 0
    public private(set) var combo = 0
    public private(set) var secondsRemaining = 0
    public private(set) var comboStep = 0
    public private(set) var heartTraceProgress = 0
    public private(set) var rhythmBeat = 0
    public private(set) var rhythmPulse = 0
    public private(set) var rhythmReady = false
    public private(set) var rhythmBestCombo = 0

    private var lastSuccessAt: Date?
    private var rhythmBeatAt: Date?
    private var rhythmBeatWasHit = false

    public init() {}

    public mutating func start(_ game: CompanionMicrogameKind) {
        resetProgress()
        activeGame = game
        switch game {
        case .catchPet, .gestureCombo:
            secondsRemaining = 20
        case .hideAndSeek, .heartTrace:
            secondsRemaining = 25
        case .feed:
            secondsRemaining = 30
        case .rhythm:
            secondsRemaining = 0
        }
    }

    /// Decrements timer-driven games and reports whether the session expired.
    /// Rhythm timing is driven by explicit beats and is not wall-clock persisted.
    @discardableResult
    public mutating func tick() -> Bool {
        guard activeGame != nil, activeGame != .rhythm else { return false }
        secondsRemaining = max(0, secondsRemaining - 1)
        return secondsRemaining == 0
    }

    public mutating func end() {
        activeGame = nil
        resetProgress()
    }

    public mutating func registerCatch(at date: Date) -> CompanionMicrogameInputOutcome {
        registerStreakHit(
            for: .catchPet,
            at: date,
            streakWindow: 1.65,
            target: Self.catchTarget
        )
    }

    public mutating func registerHideFind(at date: Date) -> CompanionMicrogameInputOutcome {
        registerStreakHit(
            for: .hideAndSeek,
            at: date,
            streakWindow: 2.1,
            target: Self.hideTarget
        )
    }

    public mutating func registerComboGesture(
        _ gesture: CompanionMicrogameGesture
    ) -> CompanionMicrogameInputOutcome {
        guard activeGame == .gestureCombo else { return .ignored }
        let sequence: [CompanionMicrogameGesture] = [.tap, .hold, .fling]
        let expected = sequence[min(comboStep, sequence.count - 1)]
        guard gesture == expected else {
            comboStep = 0
            return .reset
        }
        comboStep += 1
        return comboStep >= Self.comboTarget ? .completed : .advanced
    }

    public mutating func registerHeartPoint(
        _ point: CompanionNormalizedPoint
    ) -> CompanionMicrogameInputOutcome {
        guard activeGame == .heartTrace,
              heartTraceProgress < Self.heartTraceGuide.count
        else { return .ignored }

        let target = Self.heartTraceGuide[heartTraceProgress]
        let distance = hypot(point.x - target.x, point.y - target.y)
        guard distance <= Self.heartTraceTolerance else { return .ignored }
        heartTraceProgress += 1
        return heartTraceProgress >= Self.heartTraceGuide.count
            ? .completed
            : .advanced
    }

    public mutating func resetHeartTrace() {
        guard activeGame == .heartTrace else { return }
        heartTraceProgress = 0
    }

    public mutating func beginRhythmBeat(_ beat: Int, at date: Date) {
        guard activeGame == .rhythm,
              (1...Self.rhythmBeatCount).contains(beat)
        else { return }
        rhythmBeat = beat
        rhythmPulse += 1
        rhythmReady = true
        rhythmBeatAt = date
        rhythmBeatWasHit = false
    }

    /// Closes the visible beat window and breaks the combo only when it was missed.
    public mutating func closeRhythmBeat() {
        guard activeGame == .rhythm else { return }
        rhythmReady = false
        if !rhythmBeatWasHit {
            combo = 0
        }
    }

    public mutating func registerRhythmTap(
        at date: Date
    ) -> CompanionMicrogameInputOutcome {
        guard activeGame == .rhythm else { return .ignored }
        guard rhythmReady,
              let rhythmBeatAt,
              !rhythmBeatWasHit,
              abs(date.timeIntervalSince(rhythmBeatAt)) <= Self.rhythmTapTolerance
        else {
            combo = 0
            return .missed
        }

        rhythmBeatWasHit = true
        rhythmReady = false
        score += 1
        combo += 1
        rhythmBestCombo = max(rhythmBestCombo, combo)
        return .advanced
    }

    public mutating func registerRhythmMiss() -> CompanionMicrogameInputOutcome {
        guard activeGame == .rhythm else { return .ignored }
        combo = 0
        return .missed
    }

    public var rhythmDidWin: Bool {
        score >= Self.rhythmMinimumHits
            && rhythmBestCombo >= Self.rhythmMinimumBestCombo
    }

    public mutating func registerFeedSuccess() -> CompanionMicrogameInputOutcome {
        guard activeGame == .feed else { return .ignored }
        score += 1
        return score >= Self.feedTarget ? .completed : .advanced
    }

    private mutating func registerStreakHit(
        for game: CompanionMicrogameKind,
        at date: Date,
        streakWindow: TimeInterval,
        target: Int
    ) -> CompanionMicrogameInputOutcome {
        guard activeGame == game else { return .ignored }
        if let lastSuccessAt,
           date.timeIntervalSince(lastSuccessAt) >= 0,
           date.timeIntervalSince(lastSuccessAt) < streakWindow {
            combo += 1
        } else {
            combo = 1
        }
        self.lastSuccessAt = date
        score += 1
        return score >= target ? .completed : .advanced
    }

    private mutating func resetProgress() {
        score = 0
        combo = 0
        secondsRemaining = 0
        comboStep = 0
        heartTraceProgress = 0
        rhythmBeat = 0
        rhythmPulse = 0
        rhythmReady = false
        rhythmBestCombo = 0
        lastSuccessAt = nil
        rhythmBeatAt = nil
        rhythmBeatWasHit = false
    }
}
