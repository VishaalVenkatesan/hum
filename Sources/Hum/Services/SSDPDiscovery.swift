import Foundation
import Darwin

enum SSDPDiscovery {
    private static let multicastHost = "239.255.255.250"
    private static let multicastPort: UInt16 = 1900
    private static let searchTarget = "urn:schemas-upnp-org:device:ZonePlayer:1"

    static func discover(timeout: TimeInterval = 3) async -> Set<String> {
        await Task.detached(priority: .userInitiated) {
            search(timeout: timeout)
        }.value
    }

    private static func search(timeout: TimeInterval) -> Set<String> {
        let fd = socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP)
        guard fd >= 0 else { return [] }
        defer { close(fd) }

        var reuse: Int32 = 1
        setsockopt(fd, SOL_SOCKET, SO_REUSEADDR, &reuse, socklen_t(MemoryLayout<Int32>.size))
        var broadcast: Int32 = 1
        setsockopt(fd, SOL_SOCKET, SO_BROADCAST, &broadcast, socklen_t(MemoryLayout<Int32>.size))
        var ttl: UInt8 = 2
        setsockopt(fd, IPPROTO_IP, IP_MULTICAST_TTL, &ttl, socklen_t(MemoryLayout<UInt8>.size))
        var recvTimeout = timeval(tv_sec: 0, tv_usec: 300_000)
        setsockopt(fd, SOL_SOCKET, SO_RCVTIMEO, &recvTimeout, socklen_t(MemoryLayout<timeval>.size))

        let targets = [multicastHost, "255.255.255.255"].map(address)

        let message = [
            "M-SEARCH * HTTP/1.1",
            "HOST: \(multicastHost):\(multicastPort)",
            "MAN: \"ssdp:discover\"",
            "MX: 1",
            "ST: \(searchTarget)",
            "", ""
        ].joined(separator: "\r\n")
        let payload = Array(message.utf8)

        func send() {
            for var target in targets {
                withUnsafePointer(to: &target) { pointer in
                    pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { address in
                        _ = sendto(fd, payload, payload.count, 0, address, socklen_t(MemoryLayout<sockaddr_in>.size))
                    }
                }
            }
        }

        var hosts = Set<String>()
        var buffer = [UInt8](repeating: 0, count: 2048)
        let deadline = Date().addingTimeInterval(timeout)
        var nextSend = Date()

        while Date() < deadline {
            if Date() >= nextSend {
                send()
                nextSend = Date().addingTimeInterval(1)
            }
            let count = recv(fd, &buffer, buffer.count, 0)
            guard count > 0 else { continue }
            let response = String(decoding: buffer[0..<count], as: UTF8.self)
            if let host = locationHost(in: response) {
                hosts.insert(host)
            }
        }
        return hosts
    }

    private static func address(_ host: String) -> sockaddr_in {
        var target = sockaddr_in()
        target.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        target.sin_family = sa_family_t(AF_INET)
        target.sin_port = multicastPort.bigEndian
        inet_pton(AF_INET, host, &target.sin_addr)
        return target
    }

    private static func locationHost(in response: String) -> String? {
        guard response.contains(searchTarget) else { return nil }
        for line in response.components(separatedBy: "\r\n") {
            let parts = line.split(separator: ":", maxSplits: 1)
            guard parts.count == 2, parts[0].trimmingCharacters(in: .whitespaces).lowercased() == "location" else { continue }
            return URL(string: parts[1].trimmingCharacters(in: .whitespaces))?.host
        }
        return nil
    }
}
