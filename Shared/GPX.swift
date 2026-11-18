import Foundation

struct TrackPoint: Codable {
    let lat: Double
    let lon: Double
    var time: Date?
}
struct GPXTrack {
    let segments: [[TrackPoint]]
    var points: [TrackPoint] { segments.flatMap { $0 } }
    var start: Date? { points.first?.time }
    var finish: Date? { points.last?.time }
    var distance: Double {
        segments.reduce(0) { total, segment in
            total + zip(segment, segment.dropFirst()).reduce(0) { sum, pair in
                let a = pair.0, b = pair.1, r = Double.pi / 180
                let h = pow(sin((b.lat-a.lat)*r/2), 2) + cos(a.lat*r)*cos(b.lat*r)*pow(sin((b.lon-a.lon)*r/2), 2)
                return sum + 6_371_008.8 * 2 * atan2(sqrt(min(1,h)), sqrt(max(0,1-h)))
            }
        }
    }
    static func read(_ url: URL) throws -> GPXTrack {
        let data = try Data(contentsOf: url, options: .mappedIfSafe)
        guard data.count <= 100_000_000 else { throw GPXError.invalid("This GPX file is too large to preview (100 MB limit).") }
        let delegate = GPXParser()
        let parser = XMLParser(data: data)
        parser.delegate = delegate
        parser.shouldResolveExternalEntities = false
        guard parser.parse() else { throw GPXError.invalid("The GPX file contains invalid XML.") }
        delegate.flush()
        let segments = delegate.tracks.isEmpty ? delegate.routes : delegate.tracks
        guard !segments.isEmpty else { throw GPXError.invalid("No valid track or route points were found in this GPX file.") }
        return GPXTrack(segments: segments)
    }
}
enum GPXError: LocalizedError {
    case invalid(String)
    var errorDescription: String? { if case .invalid(let message) = self { return message }; return nil }
}
private final class GPXParser: NSObject, XMLParserDelegate {
    var tracks: [[TrackPoint]] = []
    var routes: [[TrackPoint]] = []
    var segment: [TrackPoint] = []
    var point: TrackPoint?
    var route = false
    var inTime = false
    var text = ""
    let iso = ISO8601DateFormatter()
    let fractional: ISO8601DateFormatter = { let f = ISO8601DateFormatter(); f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]; return f }()
    func flush() {
        if !segment.isEmpty { if route { routes.append(segment) } else { tracks.append(segment) }; segment = [] }
    }
    func parser(_ parser: XMLParser, didStartElement element: String, namespaceURI: String?, qualifiedName: String?, attributes: [String: String]) {
        let name = element.components(separatedBy: ":").last!
        if name == "trkseg" || name == "rte" { flush(); route = name == "rte" }
        if name == "trkpt" || name == "rtept" {
            point = nil
            if let lat = Double(attributes["lat"] ?? ""), let lon = Double(attributes["lon"] ?? ""), lat.isFinite, lon.isFinite, abs(lat) <= 90, abs(lon) <= 180 { point = TrackPoint(lat: lat, lon: lon) }
        }
        if name == "time", point != nil { inTime = true; text = "" }
    }
    func parser(_ parser: XMLParser, foundCharacters string: String) { if inTime { text += string } }
    func parser(_ parser: XMLParser, didEndElement element: String, namespaceURI: String?, qualifiedName: String?) {
        let name = element.components(separatedBy: ":").last!
        if name == "time", inTime { let value = text.trimmingCharacters(in: .whitespacesAndNewlines); point?.time = fractional.date(from: value) ?? iso.date(from: value); inTime = false }
        if name == "trkpt" || name == "rtept" { if let point { segment.append(point) }; point = nil }
        if name == "trkseg" || name == "rte" { flush() }
    }
}
