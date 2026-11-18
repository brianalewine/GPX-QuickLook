import Foundation

@main struct ParserTests {
    static func main() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathExtension("gpx")
        defer { try? FileManager.default.removeItem(at: url) }
        func parse(_ xml: String) throws -> GPXTrack { try xml.write(to: url, atomically: true, encoding: .utf8); return try GPXTrack.read(url) }
        let track = try parse("""
        <gpx><trk><trkseg><trkpt lat="0" lon="0"><time>2026-01-01T10:00:00Z</time></trkpt><trkpt lat="0" lon="1"><time>2026-01-01T11:00:00.500Z</time></trkpt></trkseg><trkseg><trkpt lat="20" lon="30"/><trkpt lat="20" lon="30"/></trkseg></trk></gpx>
        """)
        precondition(track.segments.count == 2)
        precondition(abs(track.distance - 111195.08) < 1, "Distance must exclude segment gaps")
        precondition(track.start != nil && track.finish == nil, "Do not invent endpoint timestamps")
        precondition(abs(track.points[1].time!.timeIntervalSince(track.start!) - 3600.5) < 0.001)
        let route = try parse("<gpx><rte><rtept lat=\"42\" lon=\"-71\"/><rtept lat=\"42.01\" lon=\"-71\"/></rte></gpx>")
        precondition(route.points.count == 2 && route.start == nil)
        let dateline = try parse("<gpx><trk><trkseg><trkpt lat=\"0\" lon=\"179.9\"/><trkpt lat=\"0\" lon=\"-179.9\"/></trkseg></trk></gpx>")
        precondition(dateline.distance < 23000)
        for invalid in ["<gpx>", "<gpx/>", "<gpx><trk><trkseg><trkpt lat=\"nan\" lon=\"0\"/><trkpt lat=\"91\" lon=\"0\"/></trkseg></trk></gpx>"] {
            do { _ = try parse(invalid); fatalError("Expected invalid GPX rejection") } catch is GPXError {} 
        }
        print("Passed: distance, segment gaps, endpoint timestamps, fractional timestamps, routes, dateline, malformed XML, empty GPX, invalid coordinates")
    }
}
