import AppKit
import WebKit

@main final class WebSmoke: NSObject, NSApplicationDelegate {
    var window: NSWindow!
    var web: WKWebView!
    var ticks = 0
    static func main() { let app = NSApplication.shared; let delegate = WebSmoke(); app.delegate = delegate; withExtendedLifetime(delegate) { app.run() } }
    func applicationDidFinishLaunching(_ notification: Notification) {
        let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let resource = root.appendingPathComponent("Resources")
        let track = try! GPXTrack.read(root.appendingPathComponent("Samples/Charles-River.gpx"))
        let payload: [String:Any] = ["name":"Charles River walk", "detail":"7 points · 1 segment · EST", "segments":track.segments.map{$0.map{[$0.lat,$0.lon]}}, "start":"Nov 18, 2026 at 8:00:00 AM", "finish":"Nov 18, 2026 at 8:50:00 AM", "duration":"0h 50m 00s", "distance":String(format:"%.2f km",track.distance/1000)]
        let html = try! MapDocument.render(resources: resource, payload: payload)
        let configuration = WKWebViewConfiguration()
        MapPreferences.configure(configuration)
        configuration.userContentController.addUserScript(WKUserScript(source: "window.errors=[];window.addEventListener('error',e=>window.errors.push(e.message));", injectionTime: .atDocumentStart, forMainFrameOnly: true))
        web = WKWebView(frame:NSRect(x:0,y:0,width:960,height:680),configuration:configuration); web.customUserAgent = "GPXQuickLook/1.0 (macOS GPX track preview)"
        window = NSWindow(contentRect:web.frame,styleMask:[.titled,.closable,.resizable],backing:.buffered,defer:false);window.contentView=web;window.makeKeyAndOrderFront(nil)
        web.loadHTMLString(html,baseURL:nil)
        Timer.scheduledTimer(withTimeInterval:1,repeats:true) { timer in
            self.ticks += 1
            if self.ticks == 20 {
                self.web.evaluateJavaScript("JSON.stringify({leaflet:typeof L,points:points.length,markers:document.querySelectorAll('.marker').length,contains:map.getBounds().contains(line.getBounds()),tiles:document.querySelectorAll('.leaflet-tile-loaded').length,zoom:map.getZoom()})") { value,error in
                    print("WEB CHECK:", value ?? "nil", error as Any)
                    if error != nil { self.web.evaluateJavaScript("JSON.stringify({errors:window.errors,L:typeof L})") { v,e in print("ERRORS",v as Any);exit(1) };return }
                    guard error == nil, let value = value as? String, value.contains("\"contains\":true"), value.contains("\"markers\":2"), let result = try? JSONSerialization.jsonObject(with: Data(value.utf8)) as? [String: Any], (result["tiles"] as? Int ?? 0) > 0 else { exit(1) }
                    self.web.evaluateJavaScript("""
                        fit();
                        if(!minimapEnabled){minimapEnabled=true;updateMinimap();}
                        const initiallyHidden=panel.hidden;
                        const bounds=line.getBounds(),size=map.getSize();
                        const a=map.latLngToContainerPoint(bounds.getNorthWest()),b=map.latLngToContainerPoint(bounds.getSouthEast());
                        const fill=Math.max((b.x-a.x)/size.x,(b.y-a.y)/size.y);
                        const framingWorks=fill>.93&&fill<.95&&a.x>=11&&a.y>=11&&b.x<=size.x-11&&b.y<=size.y-11;

                        const before=map.getZoom();
                        map.setZoom(before+.03,{animate:false});
                        const stillInsideHidden=panel.hidden&&map.getBounds().contains(line.getBounds());
                        const originalTiles=Array.from(tiles.getContainer().querySelectorAll('img')).filter(img=>img.complete&&img.naturalWidth);
                        map.setZoom(before+2,{animate:false});
                        const retainedDuringZoom=originalTiles.some(img=>tiles.getContainer().contains(img));
                        const zoomWorks=map.getZoom()>before;
                        const minimapShown=!panel.hidden&&!document.getElementById('minimap').hidden;
                        collapse.click();const toggleOff=panel.classList.contains('collapsed')&&document.getElementById('minimap').hidden;
                        collapse.click();const toggleOn=!panel.classList.contains('collapsed')&&!document.getElementById('minimap').hidden;
                        const center=map.getCenter();map.panBy([60,40],{animate:false});
                        const panWorks=!center.equals(map.getCenter());
                        window.wheelBefore=map.getZoom();
                        map.getContainer().dispatchEvent(new WheelEvent('wheel',{deltaY:-60,clientX:400,clientY:300,bubbles:true,cancelable:true}));
                        initiallyHidden && framingWorks && stillInsideHidden && retainedDuringZoom && zoomWorks && panWorks && minimapShown && toggleOff && toggleOn
                        """) { result,error in
                        guard result as? Bool == true, error == nil else { print("Zoom failed",error as Any);exit(1) }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                        self.web.evaluateJavaScript("map.getZoom()>window.wheelBefore && Math.abs(map.getZoom()-Math.round(map.getZoom()))>.01") { result,error in
                        guard result as? Bool == true, error == nil else { print("Smooth wheel zoom failed",error as Any);exit(1) }
                        self.web.evaluateJavaScript("""
                            map.setZoom(24,{animate:false});
                            const overzoom=map.getZoom()===24&&tiles._tileZoom===19;
                            fit();const immediateFit=panel.hidden&&map.getBounds().contains(line.getBounds());
                            window.returnedTiles=Array.from(tiles.getContainer().querySelectorAll('img')).filter(img=>img.complete&&img.naturalWidth);
                            overzoom&&immediateFit&&returnedTiles.length>0
                            """) { result,error in
                        guard result as? Bool == true, error == nil else { print("Overzoom / instant fit failed",error as Any);exit(1) }
                        self.web.takeSnapshot(with:nil) { image,error in
                            if let image, let data=image.tiffRepresentation,let bitmap=NSBitmapImageRep(data:data),let png=bitmap.representation(using:.png,properties:[:]) { try! png.write(to:root.appendingPathComponent("Samples/Preview.png")) }
                            print("Passed: native tile loading, markers, bounds, zoom, pan, fractional wheel zoom, retained tiles, 3.3% padding, trail-only minimap, level-24 overzoom, instant fit; snapshot saved")
                            timer.invalidate();NSApp.terminate(nil)
                        }
                        }
                        }
                        }
                    }
                }
            }
            if self.ticks > 35 { print("Timed out");exit(1) }
        }
    }
}
