import Foundation

@main
private enum CompanionFeedbackSmoke {
    static func main() {
        var passed = 0

        require(
            CompanionRelationshipFeedbackPolicy.chapterLabel(for: 5) == "初识",
            "chapter boundary before first upgrade"
        )
        passed += 1

        require(
            CompanionRelationshipFeedbackPolicy.chapterLabel(for: 6) == "渐有默契",
            "chapter boundary at first upgrade"
        )
        passed += 1

        let before = CompanionRelationshipFeedbackSnapshot(
            bondMoments: 5,
            chemistryLevel: 0,
            mementoIDs: []
        )
        let after = CompanionRelationshipFeedbackSnapshot(
            bondMoments: 6,
            chemistryLevel: 1,
            mementoIDs: ["task.first-complete"]
        )
        let receipts = CompanionRelationshipFeedbackPolicy.receipts(
            before: before,
            after: after
        )
        require(
            receipts == [
                .moment(delta: 1),
                .chemistry(level: 1),
                .firstMemento,
                .chapter(label: "渐有默契")
            ],
            "moment, chemistry, first memento and chapter receipts"
        )
        passed += 1

        let unchanged = CompanionRelationshipFeedbackPolicy.receipts(
            before: after,
            after: after
        )
        require(unchanged.isEmpty, "unchanged state stays quiet")
        passed += 1

        print("PASS  Companion feedback smoke \(passed)/\(passed)")
    }

    private static func require(
        _ condition: @autoclosure () -> Bool,
        _ name: String
    ) {
        guard condition() else {
            fputs("FAIL  Companion feedback smoke: \(name)\n", stderr)
            exit(1)
        }
    }
}
