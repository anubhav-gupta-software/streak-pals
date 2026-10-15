import Foundation

enum CloudNames {
    static func pal(_ id: UUID) -> String { "pal-\(id.uuidString)" }
    static func circle(code: String) -> String { "circle-\(code)" }
    static func habit(_ id: UUID) -> String { "habit-\(id.uuidString)" }
    static func checkIn(_ id: UUID) -> String { "checkin-\(id.uuidString)" }
}

enum MembershipCodec {
    static func encode(_ membership: Membership) -> String {
        let left = membership.leftAt.map { String($0.timeIntervalSince1970) } ?? ""
        return [
            membership.id.uuidString,
            membership.palID.uuidString,
            String(membership.joinedAt.timeIntervalSince1970),
            left
        ].joined(separator: "|")
    }

    static func decode(_ raw: String) -> Membership? {
        let parts = raw.split(separator: "|", omittingEmptySubsequences: false).map(String.init)
        guard parts.count >= 4,
              let id = UUID(uuidString: parts[0]),
              let palID = UUID(uuidString: parts[1]),
              let joined = TimeInterval(parts[2]) else {
            return nil
        }
        let left = TimeInterval(parts[3]).map { Date(timeIntervalSince1970: $0) }
        return Membership(id: id, palID: palID, joinedAt: Date(timeIntervalSince1970: joined), leftAt: left)
    }
}
