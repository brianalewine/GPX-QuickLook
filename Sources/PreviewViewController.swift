import Cocoa
import Quartz

final class PreviewViewController: TrackViewController, QLPreviewingController {
    func preparePreviewOfFile(at url: URL, completionHandler handler: @escaping (Error?) -> Void) {
        do { try show(url); handler(nil) }
        catch { showError(error); handler(nil) }
    }
}
