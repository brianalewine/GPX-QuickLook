# GPX QuickLook

A macOS 13+ app and Finder Quick Look extension for GPX tracks and routes.

## Use

Build with `./scripts/build.sh`, then open `build/Build/Products/Release/GPX QuickLook.app`. For permanent installation, drag that app to Applications and open it once. Select a `.gpx` file in Finder and press Space. If needed, enable GPXPreview under System Settings → General → Login Items & Extensions → Quick Look.

The app can also open GPX files directly with Command-O or Finder's Open With menu.

- OpenStreetMap tiles with attribution; internet access is required for the basemap. The route and statistics work without tiles.
- Small green start and checkered finish circles, including offset markers for loops.
- A top-right overview appears when zoomed in; its viewport follows the main map. Click the overview to recenter. Hover over the minimap for its collapse icon; the collapsed icon expands it again. The collapsed state is remembered.
- Drag to pan; scroll, double click, or use +/− to zoom. The lower-left fit icon restores the initial frame. Wheel and trackpad zoom use smooth fractional steps.
- Initial framing fills the available map with a 10% buffer on each side of the projected track bounds, with a minimum margin for marker visibility. Fractional zoom avoids the excess space caused by rounding to whole zoom levels. Single-point tracks have a sensible maximum zoom. Dateline crossings are unwrapped.
- Start and stop use the first and last point timestamps in the local time zone. Missing timestamps display “Unavailable.” Duration is elapsed time, including pauses.
- Length uses great-circle distances, without connecting separate track segments. Routes are used when there are no tracks. Waypoint-only files show an explanation.
- GPX stays local. Only visible basemap tile requests go to OpenStreetMap. Tile requests use native URLSession networking with HTTP caching and identify the app in its user agent. A transient failure does not leave a permanent warning; Retry reloads the tiles. No bulk download or offline prefetch.

## Development

Open `GPXQuickLook.xcodeproj` in Xcode, or run `./scripts/build.sh`. The generated Xcode project is checked in; XcodeGen is only needed after changing `project.yml`. The local build uses ad hoc signing; distribution to other Macs requires your Developer ID and notarization.

Parser checks:

```sh
swiftc -module-cache-path /tmp/gpx-swift-cache Shared/GPX.swift Tests/ParserTests.swift -o /tmp/gpx-parser-tests
/tmp/gpx-parser-tests
```

WebKit integration check (opens a temporary test window and saves `Samples/Preview.png`):

```sh
swiftc -module-cache-path /tmp/gpx-swift-cache Shared/GPX.swift Shared/MapDocument.swift Shared/TileSchemeHandler.swift Tests/WebSmoke.swift -o /tmp/gpx-web-smoke
/tmp/gpx-web-smoke
```

Map renderer: bundled Leaflet 1.9.4, BSD-2-Clause (see `Resources/Leaflet-LICENSE.txt`). Basemap: [OpenStreetMap contributors](https://www.openstreetmap.org/copyright), subject to its [tile usage policy](https://operations.osmfoundation.org/policies/tiles/). Extension implementation follows Apple's [QLPreviewingController](https://developer.apple.com/documentation/quicklookui/qlpreviewingcontroller) API.

Quick Look networking: macOS applies a dedicated preview sandbox which does not honor the ordinary network-client entitlement for DNS and outgoing sockets. `Preview.entitlements` includes a temporary SBPL exception restricted to the system DNS socket and outgoing HTTPS (TCP 443). The tile handler accepts only OSM tile coordinates and always requests `tile.openstreetmap.org`; it does not accept arbitrary remote URLs. This local-build exception may require review or a different architecture for Mac App Store distribution.
