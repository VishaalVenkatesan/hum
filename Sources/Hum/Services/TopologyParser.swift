import Foundation

final class TopologyParser: NSObject, XMLParserDelegate {
    private struct PendingGroup {
        let id: String
        let coordinatorID: String
        var members: [SonosMember] = []
    }

    private var groups: [SonosGroup] = []
    private var pending: PendingGroup?

    static func parse(_ xml: String) -> [SonosGroup] {
        let delegate = TopologyParser()
        let parser = XMLParser(data: Data(xml.utf8))
        parser.delegate = delegate
        parser.parse()
        return delegate.groups.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName: String?, attributes: [String: String] = [:]) {
        switch elementName {
        case "ZoneGroup":
            pending = PendingGroup(id: attributes["ID"] ?? UUID().uuidString, coordinatorID: attributes["Coordinator"] ?? "")
        case "ZoneGroupMember":
            guard
                attributes["Invisible"] != "1",
                attributes["IsZoneBridge"] != "1",
                let uuid = attributes["UUID"],
                let name = attributes["ZoneName"],
                let location = attributes["Location"],
                let host = URL(string: location)?.host
            else { return }
            pending?.members.append(SonosMember(id: uuid, name: name, host: host))
        default:
            break
        }
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName: String?) {
        guard elementName == "ZoneGroup", let group = pending else { return }
        pending = nil
        guard let coordinator = group.members.first(where: { $0.id == group.coordinatorID }) else { return }
        let members = group.members.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        groups.append(SonosGroup(id: group.id, coordinator: coordinator, members: members))
    }
}
