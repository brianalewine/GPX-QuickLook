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
        let payload: [String:Any] = ["name":"Charles River walk", "points":track.points.count.formatted(), "segments":track.segments.map{$0.map{[$0.lat,$0.lon]}}, "start":"Nov 18, 2026 at 8:00:00 AM", "finish":"Nov 18, 2026 at 8:50:00 AM", "duration":"0h 50m 00s", "distance":String(format:"%.2f km",track.distance/1000)]
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
                        const initiallyHidden=!minimapVisible;
                        const bounds=line.getBounds(),size=map.getSize();
                        const a=map.latLngToContainerPoint(bounds.getNorthWest()),b=map.latLngToContainerPoint(bounds.getSouthEast());
                        const fill=Math.max((b.x-a.x)/size.x,(b.y-a.y)/size.y);
                        const framingWorks=fill>.93&&fill<.95&&a.x>=11&&a.y>=11&&b.x<=size.x-11&&b.y<=size.y-11;

                        map.fire('dragstart');map.panBy([900,0],{animate:false});
                        const hiddenThroughoutDrag=!minimapVisible;
                        map.fire('dragend');const visibleAfterRelease=minimapVisible;
                        map.fire('dragstart');map.panBy([-900,0],{animate:false});
                        const visibleThroughoutDrag=minimapVisible;
                        map.fire('dragend');const hiddenAfterRelease=!minimapVisible;
                        const dragVisibilityWorks=hiddenThroughoutDrag&&visibleAfterRelease&&visibleThroughoutDrag&&hiddenAfterRelease;
                        const fadeWorks=getComputedStyle(panel).transitionProperty.includes('opacity')&&getComputedStyle(panel).transitionDuration.includes('0.12s');
                        const before=map.getZoom();
                        map.setZoom(before+.03,{animate:false});
                        const stillInsideHidden=!minimapVisible&&map.getBounds().contains(line.getBounds());
                        const originalTiles=Array.from(tiles.getContainer().querySelectorAll('img')).filter(img=>img.complete&&img.naturalWidth);
                        map.setZoom(before+2,{animate:false});
                        const retainedDuringZoom=originalTiles.some(img=>tiles.getContainer().contains(img));
                        const zoomWorks=map.getZoom()>before;
                        const minimapShown=!!minimapVisible&&!document.getElementById('minimap').hidden;
                        collapse.click();const toggleOff=panel.classList.contains('collapsed')&&document.getElementById('minimap').hidden;
                        collapse.click();const toggleOn=!panel.classList.contains('collapsed')&&!document.getElementById('minimap').hidden;
                        const center=map.getCenter();map.panBy([60,40],{animate:false});
                        const panWorks=!center.equals(map.getCenter());
                        window.wheelBefore=map.getZoom();
                        window.trailBeforeWheel=line._path.getAttribute('d');
                        map.getContainer().dispatchEvent(new WheelEvent('wheel',{deltaY:-60,clientX:400,clientY:300,bubbles:true,cancelable:true}));
                        requestAnimationFrame(()=>{
                            window.liveTrailOnWheel=line._path.getAttribute('d')!==trailBeforeWheel&&line._renderer._zoom===map.getZoom()&&line._rings[0][0].distanceTo(map.latLngToLayerPoint(segments[0][0]))<.01;
                            window.immediateWheel=Math.abs(map.getZoom()-(wheelBefore+.25))<.00001;
                            window.anchorStable=map.latLngToContainerPoint(anchorLatLng).distanceTo(zoomAnchor)<.01;
                            const firstZoom=map.getZoom();
                            setTimeout(()=>window.noAddedInertia=Math.abs(map.getZoom()-firstZoom)<.00001,180);
                        });
                        setTimeout(()=>{
                            const emit=(type,scale)=>{const event=new Event(type,{bubbles:true,cancelable:true});Object.assign(event,{scale,clientX:400,clientY:300});map.getContainer().dispatchEvent(event);};
                            const startZoom=map.getZoom(),tileZoom=tiles._tileZoom,trailBeforePinch=line._path.getAttribute('d');
                            emit('gesturestart',1);emit('gesturechange',1.5);
                            requestAnimationFrame(()=>{
                                window.liveTrailDuringPinch=nativePinchActive&&line._path.getAttribute('d')!==trailBeforePinch&&line._renderer._zoom===map.getZoom()&&line._rings[0][0].distanceTo(map.latLngToLayerPoint(segments[0][0]))<.01;
                                window.pinchGainWorks=Math.abs(map.getZoom()-startZoom-Math.log2(1.5)*3)<.00001;
                                window.tilesUpdateDuringGesture=nativePinchActive&&tiles._tileZoom!==tileZoom;
                                window.retainsImagesDuringPinch=Array.from(tiles.getContainer().querySelectorAll('img')).some(img=>img.complete&&img.naturalWidth);
                                emit('gestureend',1.5);
                                const ctrlStart=map.getZoom();
                                map.getContainer().dispatchEvent(new WheelEvent('wheel',{deltaY:-30,ctrlKey:true,clientX:400,clientY:300,bubbles:true,cancelable:true}));
                                requestAnimationFrame(()=>window.ctrlPinchGainWorks=Math.abs(map.getZoom()-ctrlStart-1)<.00001);
                            });
                        },220);
                        initiallyHidden && dragVisibilityWorks && fadeWorks && framingWorks && stillInsideHidden && retainedDuringZoom && zoomWorks && panWorks && minimapShown && toggleOff && toggleOn
                        """) { result,error in
                        guard result as? Bool == true, error == nil else { print("Zoom failed",error as Any);exit(1) }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                        self.web.evaluateJavaScript("window.liveTrailOnWheel && window.liveTrailDuringPinch && window.pinchGainWorks && window.ctrlPinchGainWorks && window.tilesUpdateDuringGesture && window.retainsImagesDuringPinch && window.immediateWheel && window.anchorStable && window.noAddedInertia && !zoomGesture && map.getZoom()>window.wheelBefore && Math.abs(map.getZoom()-Math.round(map.getZoom()))>.01") { result,error in
                        guard result as? Bool == true, error == nil else { print("Smooth wheel zoom failed",error as Any);exit(1) }
                        self.web.evaluateJavaScript("""
                            map.setZoom(24,{animate:false});
                            const overzoom=map.getZoom()===24&&tiles._tileZoom===19;
                            fit();const immediateFit=!minimapVisible&&map.getBounds().contains(line.getBounds());
                            window.returnedTiles=Array.from(tiles.getContainer().querySelectorAll('img')).filter(img=>img.complete&&img.naturalWidth);
                            overzoom&&immediateFit&&returnedTiles.length>0
                            """) { result,error in
                        guard result as? Bool == true, error == nil else { print("Overzoom / instant fit failed",error as Any);exit(1) }
                        self.web.takeSnapshot(with:nil) { image,error in
                            if let image, let data=image.tiffRepresentation,let bitmap=NSBitmapImageRep(data:data),let png=bitmap.representation(using:.png,properties:[:]) { try! png.write(to:root.appendingPathComponent("Samples/Preview.png")) }
                            print("Passed: native tile loading, markers, bounds, zoom, pan, live trail geometry during scroll and pinch, minimap fade, visibility frozen during drag, 3x pinch gain, live tile detail, first-frame wheel response, stable cursor anchor, no added inertia, retained tiles, 3.3% padding, trail-only minimap, level-24 overzoom, instant fit; snapshot saved")
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
