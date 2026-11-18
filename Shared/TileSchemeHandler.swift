import Foundation
import WebKit
import os

/// Fetch tiles in the app/extension process, with an explicit identity and normal HTTP caching.
final class TileSchemeHandler: NSObject, WKURLSchemeHandler {
    private var reportedSuccess = false
    private var tasks: [ObjectIdentifier: URLSessionDataTask] = [:]
    private let session: URLSession = {
        let configuration = URLSessionConfiguration.default
        configuration.urlCache = URLCache(memoryCapacity: 24 * 1024 * 1024, diskCapacity: 100 * 1024 * 1024)
        configuration.requestCachePolicy = .useProtocolCachePolicy
        configuration.timeoutIntervalForRequest = 20
        configuration.httpMaximumConnectionsPerHost = 4
        return URLSession(configuration: configuration)
    }()
    func webView(_ webView: WKWebView, start task: WKURLSchemeTask) {
        guard let source = task.request.url, source.host == "osm",
              source.path.range(of: #"^/\d{1,2}/\d+/\d+\.png$"#, options: .regularExpression) != nil,
              let url = URL(string: "https://tile.openstreetmap.org" + source.path) else {
            task.didFailWithError(URLError(.badURL)); return
        }
        #if DEBUG
        print("Fetching", url)
        #endif
        var request = URLRequest(url: url)
        request.setValue("GPXQuickLook/1.1 (macOS GPX track preview)", forHTTPHeaderField: "User-Agent")
        let identifier = ObjectIdentifier(task)
        let download = session.dataTask(with: request) { [weak self] data, response, error in
            #if DEBUG
            print("Tile response", response as Any, error as Any)
            #endif
            DispatchQueue.main.async {
                guard let self, self.tasks.removeValue(forKey: identifier) != nil else { return }
                guard error == nil, let http = response as? HTTPURLResponse,
                      http.statusCode == 200, http.value(forHTTPHeaderField: "X-Blocked") == nil,
                      let data, !data.isEmpty else {
                    let failure = error ?? URLError(.badServerResponse)
                    Logger(subsystem: "com.brian.GPXQuickLook", category: "Tiles").error("Tile request failed: \(failure.localizedDescription, privacy: .public)")
                    task.didFailWithError(failure); return
                }
                if !self.reportedSuccess {
                    self.reportedSuccess = true
                    Logger(subsystem: "com.brian.GPXQuickLook", category: "Tiles").notice("OpenStreetMap tiles loaded successfully")
                }
                task.didReceive(URLResponse(url: source, mimeType: "image/png", expectedContentLength: data.count, textEncodingName: nil))
                task.didReceive(data)
                task.didFinish()
            }
        }
        tasks[identifier] = download
        download.resume()
    }
    func webView(_ webView: WKWebView, stop task: WKURLSchemeTask) {
        tasks.removeValue(forKey: ObjectIdentifier(task))?.cancel()
    }
    deinit { session.invalidateAndCancel() }
}

final class MapPreferences: NSObject, WKScriptMessageHandler {
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        if let enabled = message.body as? Bool { UserDefaults.standard.set(enabled, forKey: "minimapEnabled") }
    }
    static func configure(_ configuration: WKWebViewConfiguration) {
        configuration.setURLSchemeHandler(TileSchemeHandler(), forURLScheme: "gpx-tile")
        let enabled = UserDefaults.standard.object(forKey: "minimapEnabled") as? Bool ?? true
        configuration.userContentController.addUserScript(WKUserScript(source: "window.gpxMinimapEnabled = \(enabled);", injectionTime: .atDocumentStart, forMainFrameOnly: true))
        configuration.userContentController.add(MapPreferences(), name: "minimapPreference")
    }
}
