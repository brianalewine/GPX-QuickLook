# GPX QuickLook

A macOS 13+ app and Finder Quick Look extension for GPX tracks and routes.

## Use

Build with `./scripts/build.sh`, then open `build/Build/Products/Release/GPX QuickLook.app`. For permanent installation, drag that app to Applications and open it once. Select a `.gpx` file in Finder and press Space. If needed, enable GPXPreview under System Settings → General → Login Items & Extensions → Quick Look.

The app can also open GPX files directly with Command-O or Finder's Open With menu.

- Uses OpenStreetMap as the map base
- Pan and zoom controls
- Minimap for long trails
