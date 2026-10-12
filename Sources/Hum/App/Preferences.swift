enum Preferences {
    static let showTrackInMenuBar = "showTrackInMenuBar"
    static let hotKeysEnabled = "hotKeysEnabled"
    static let mediaKeysEnabled = "mediaKeysEnabled"
    static let showLyrics = "showLyrics"
    static let callBehavior = "callBehavior"
}

enum CallBehavior: String, CaseIterable, Identifiable {
    case off
    case lower
    case pause

    var id: String { rawValue }

    var title: String {
        switch self {
        case .off: "Do Nothing"
        case .lower: "Lower Music"
        case .pause: "Pause Music"
        }
    }
}
