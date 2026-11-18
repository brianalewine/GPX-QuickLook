import Foundation

enum MapDocument {
    static func render(resources: URL, payload: [String: Any]) throws -> String {
        let template = try String(contentsOf: resources.appendingPathComponent("map.html"), encoding: .utf8)
        let javascript = try String(contentsOf: resources.appendingPathComponent("leaflet.js"), encoding: .utf8)
        let css = try String(contentsOf: resources.appendingPathComponent("leaflet.css"), encoding: .utf8)
        let encoded = try JSONSerialization.data(withJSONObject: payload).base64EncodedString()
        // Inline bundled assets: Quick Look's WebKit process cannot reliably read sibling files.
        return template.replacingOccurrences(of: "<link rel=\"stylesheet\" href=\"leaflet.css\">", with: "<style>\(css)</style>")
            .replacingOccurrences(of: "<script src=\"leaflet.js\"></script>", with: "<script>\(javascript)</script>")
            .replacingOccurrences(of: "__TRACK_BASE64__", with: encoded)
    }
}
