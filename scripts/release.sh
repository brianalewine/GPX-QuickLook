#!/bin/zsh
set -euo pipefail
cd "${0:A:h:h}"

./scripts/build.sh -destination 'generic/platform=macOS' ONLY_ACTIVE_ARCH=NO 'ARCHS=arm64 x86_64'
app='build/Build/Products/Release/GPX QuickLook.app'
version=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$app/Contents/Info.plist")
extension="$app/Contents/PlugIns/GPXPreview.appex"
for executable in "$app/Contents/MacOS/GPX QuickLook" "$extension/Contents/MacOS/GPXPreview"; do
  architectures=" $(lipo -archs "$executable") "
  [[ "$architectures" == *' arm64 '* && "$architectures" == *' x86_64 '* ]] || {
    print -u2 "Missing universal architectures: $executable ($architectures)"
    exit 1
  }
done
codesign --verify --deep --strict "$app"

output="$PWD/build/release"
mkdir -p "$output"
staging=$(mktemp -d "$PWD/build/release-stage.XXXXXX")
trap 'rm -rf "$staging"' EXIT
ditto "$app" "$staging/GPX QuickLook.app"
cp README.md "$staging/INSTALL.md"
ln -s /Applications "$staging/Applications"
image="GPX-QuickLook-${version}-macOS-universal.dmg"
hdiutil create -volname "GPX QuickLook $version" -srcfolder "$staging" -format UDZO -ov "$output/$image"
hdiutil verify "$output/$image"
(cd "$output" && shasum -a 256 "$image" > "$image.sha256")
print "Release disk image: $output/$image"
