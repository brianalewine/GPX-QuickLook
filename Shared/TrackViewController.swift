import AppKit
import WebKit

private final class MapWebView: WKWebView {
    var onMagnify: ((NSEvent) -> Void)?

    override func magnify(with event: NSEvent) {
        guard let onMagnify else {
            super.magnify(with: event)
            return
        }
        onMagnify(event)
    }
}

class TrackViewController: NSViewController, WKNavigationDelegate {
    private var web: MapWebView!
    override func loadView() {
        let configuration = WKWebViewConfiguration()
        MapPreferences.configure(configuration)
        web = MapWebView(frame: NSRect(x: 0, y: 0, width: 960, height: 680), configuration: configuration)
        web.onMagnify = { [weak self] event in
            guard let web = self?.web else { return }
            let point = web.convert(event.locationInWindow, from: nil)
            let phase: String
            if event.phase.contains(.began) {
                phase = "start"
            } else if event.phase.contains(.ended) || event.phase.contains(.cancelled) {
                phase = "end"
            } else {
                phase = "change"
            }
            let x = point.x
            let y = web.bounds.height - point.y
            web.evaluateJavaScript("window.gpxNativePinch?.('\(phase)', \(event.magnification), \(x), \(y))")
        }
        web.navigationDelegate = self
        web.customUserAgent = "GPXQuickLook/1.0 (macOS GPX track preview)"
        view = web
        preferredContentSize = NSSize(width: 960, height: 680)
    }
    func show(_ url: URL) throws {
        let track = try GPXTrack.read(url)
        _ = view
        if view !== web { view = web }
        let bundle = Bundle(for: TrackViewController.self)
        let dates = DateFormatter(); dates.dateStyle = .medium; dates.timeStyle = .medium
        let duration: String
        if let start = track.start, let finish = track.finish, finish >= start {
            let seconds = Int(finish.timeIntervalSince(start))
            duration = String(format: "%dh %02dm %02ds", seconds/3600, seconds/60%60, seconds%60)
        } else { duration = "Unavailable" }
        let payload: [String: Any] = [
            "name": url.deletingPathExtension().lastPathComponent,
            "segments": track.segments.map { $0.map { [$0.lat, $0.lon] } },
            "start": track.start.map { dates.string(from: $0) } ?? "Unavailable",
            "finish": track.finish.map { dates.string(from: $0) } ?? "Unavailable",
            "duration": duration,
            "distance": String(format: "%.2f km", track.distance/1000),
            "detail": "\(track.points.count.formatted()) points · \(track.segments.count) segments · \(TimeZone.current.abbreviation() ?? "Local time")"
        ]
        let html = try MapDocument.render(resources: bundle.resourceURL!, payload: payload)
        web.loadHTMLString(html, baseURL: nil)
    }
    func showError(_ error: Error) {
        _ = view
        let label = NSTextField(wrappingLabelWithString: error.localizedDescription)
        label.alignment = .center
        label.frame = NSRect(x: 40, y: 100, width: 600, height: 100)
        let errorView = NSView(frame: NSRect(x: 0, y: 0, width: 680, height: 300))
        errorView.addSubview(label); view = errorView
    }
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        if navigationAction.navigationType == .linkActivated, let url = navigationAction.request.url {
            if url.scheme == "https" { NSWorkspace.shared.open(url) }
            decisionHandler(.cancel)
        } else { decisionHandler(.allow) }
    }
}
