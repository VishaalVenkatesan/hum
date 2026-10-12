import Foundation

enum SonosService {
    case avTransport
    case renderingControl
    case groupRenderingControl
    case zoneGroupTopology
    case deviceProperties

    var path: String {
        switch self {
        case .avTransport: "/MediaRenderer/AVTransport/Control"
        case .renderingControl: "/MediaRenderer/RenderingControl/Control"
        case .groupRenderingControl: "/MediaRenderer/GroupRenderingControl/Control"
        case .zoneGroupTopology: "/ZoneGroupTopology/Control"
        case .deviceProperties: "/DeviceProperties/Control"
        }
    }

    var urn: String {
        switch self {
        case .avTransport: "urn:schemas-upnp-org:service:AVTransport:1"
        case .renderingControl: "urn:schemas-upnp-org:service:RenderingControl:1"
        case .groupRenderingControl: "urn:schemas-upnp-org:service:GroupRenderingControl:1"
        case .zoneGroupTopology: "urn:schemas-upnp-org:service:ZoneGroupTopology:1"
        case .deviceProperties: "urn:schemas-upnp-org:service:DeviceProperties:1"
        }
    }
}

enum SonosSOAPError: Error {
    case badStatus(Int)
    case invalidResponse
}

struct SonosSOAP: Sendable {
    static let port = 1400

    private static let session: URLSession = {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 4
        configuration.timeoutIntervalForResource = 6
        configuration.httpMaximumConnectionsPerHost = 4
        return URLSession(configuration: configuration)
    }()

    let host: String

    @discardableResult
    func call(_ service: SonosService, _ action: String, _ arguments: KeyValuePairs<String, String> = [:]) async throws -> [String: String] {
        guard let url = URL(string: "http://\(host):\(Self.port)\(service.path)") else { throw SonosSOAPError.invalidResponse }

        let body = arguments.map { "<\($0.key)>\(Self.escape($0.value))</\($0.key)>" }.joined()
        let envelope = """
        <?xml version="1.0" encoding="utf-8"?>\
        <s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/" s:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/">\
        <s:Body><u:\(action) xmlns:u="\(service.urn)">\(body)</u:\(action)></s:Body></s:Envelope>
        """

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = Data(envelope.utf8)
        request.setValue("text/xml; charset=\"utf-8\"", forHTTPHeaderField: "Content-Type")
        request.setValue("\"\(service.urn)#\(action)\"", forHTTPHeaderField: "SOAPACTION")

        let (data, response) = try await Self.session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw SonosSOAPError.invalidResponse }
        guard http.statusCode == 200 else { throw SonosSOAPError.badStatus(http.statusCode) }
        return SOAPResponseParser.parse(data, action: action)
    }

    func text(at path: String) async throws -> String {
        guard let url = URL(string: "http://\(host):\(Self.port)\(path)") else { throw SonosSOAPError.invalidResponse }
        let (data, response) = try await Self.session.data(from: url)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw SonosSOAPError.invalidResponse }
        return String(decoding: data, as: UTF8.self)
    }

    static func escape(_ value: String) -> String {
        value
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
    }
}

private final class SOAPResponseParser: NSObject, XMLParserDelegate {
    private let responseElement: String
    private var values: [String: String] = [:]
    private var depth = 0
    private var responseDepth: Int?
    private var currentKey: String?
    private var currentValue = ""

    private init(action: String) {
        responseElement = "\(action)Response"
    }

    static func parse(_ data: Data, action: String) -> [String: String] {
        let delegate = SOAPResponseParser(action: action)
        let parser = XMLParser(data: data)
        parser.shouldProcessNamespaces = true
        parser.delegate = delegate
        parser.parse()
        return delegate.values
    }

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName: String?, attributes: [String: String] = [:]) {
        depth += 1
        if elementName == responseElement {
            responseDepth = depth
        } else if let responseDepth, depth == responseDepth + 1 {
            currentKey = elementName
            currentValue = ""
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        if currentKey != nil { currentValue += string }
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName: String?) {
        if let key = currentKey, elementName == key {
            values[key] = currentValue
            currentKey = nil
        }
        if elementName == responseElement { responseDepth = nil }
        depth -= 1
    }
}
