import Foundation

struct SemanticVersion: Comparable {
    let major: Int
    let minor: Int
    let patch: Int
    let prerelease: String?

    init?(_ rawValue: String) {
        let coreAndMetadata = rawValue.split(
            separator: "+",
            maxSplits: 1,
            omittingEmptySubsequences: false
        )
        let coreAndPrerelease = coreAndMetadata[0].split(
            separator: "-",
            maxSplits: 1,
            omittingEmptySubsequences: false
        )
        let components = coreAndPrerelease[0].split(
            separator: ".",
            omittingEmptySubsequences: false
        )
        guard components.count == 3,
              let major = Int(components[0]),
              let minor = Int(components[1]),
              let patch = Int(components[2]),
              major >= 0, minor >= 0, patch >= 0 else {
            return nil
        }
        self.major = major
        self.minor = minor
        self.patch = patch
        prerelease = coreAndPrerelease.count == 2
            ? String(coreAndPrerelease[1])
            : nil
    }

    static func < (lhs: Self, rhs: Self) -> Bool {
        if lhs.major != rhs.major { return lhs.major < rhs.major }
        if lhs.minor != rhs.minor { return lhs.minor < rhs.minor }
        if lhs.patch != rhs.patch { return lhs.patch < rhs.patch }
        switch (lhs.prerelease, rhs.prerelease) {
        case (nil, nil):
            return false
        case (nil, _?):
            return false
        case (_?, nil):
            return true
        case let (left?, right?):
            return left.localizedStandardCompare(right) == .orderedAscending
        }
    }
}
