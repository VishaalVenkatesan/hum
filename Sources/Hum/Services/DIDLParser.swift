import Foundation

final class DIDLParser: NSObject, XMLParserDelegate {
    private var fields: [String: String] = [:]
    private var currentKey: String?
    private var currentValue = ""
    private static let wanted: Set<String> = ["title", "creator", "album", "albumArtURI", "streamContent"]

    static func parse(_ xml: String, host: String) -> NowPlaying {
        guard !xml.isEmpty, xml != "NOT_IMPLEMENTED" else { return .empty }
        let delegate = DIDLParser()
        let parser = XMLParser(data: Data(xml.utf8))
        parser.shouldProcessNamespaces = true
        parser.delegate = delegate
        parser.parse()
        return delegate.nowPlaying(host: host)
    }

    private func nowPlaying(host: String) -> NowPlaying {
        var result = NowPlaying()
        result.title = fields["title"].nonEmpty.flatMap { $0.contains("://") ? nil : $0 }
        result.artist = fields["creator"].nonEmpty
        result.album = fields["album"].nonEmpty

        if let stream = fields["streamContent"].nonEmpty, !stream.hasPrefix("ZPSTR_") {
            let parts = stream.components(separatedBy: " - ")
            if parts.count >= 2 {
                result.artist = parts[0]
                result.title = parts.dropFirst().joined(separator: " - ")
            } else {
                result.title = stream
            }
        }

        if let art = fields["albumArtURI"].nonEmpty {
            result.artURL = art.hasPrefix("http") ? URL(string: art) : URL(string: "http://\(host):\(SonosSOAP.port)\(art)")
        }
        return result
    }

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName: String?, attributes: [String: String] = [:]) {
        guard Self.wanted.contains(elementName), fields[elementName] == nil else { return }
        currentKey = elementName
        currentValue = ""
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        if currentKey != nil { currentValue += string }
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName: String?) {
        guard let key = currentKey, key == elementName else { return }
        fields[key] = currentValue.trimmingCharacters(in: .whitespacesAndNewlines)
        currentKey = nil
    }
}

private extension Optional where Wrapped == String {
    var nonEmpty: String? {
        guard let self, !self.isEmpty else { return nil }
        return self
    }
}
