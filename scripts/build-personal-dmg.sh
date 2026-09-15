#!/bin/bash
set -euo pipefail

version="${1:-0.19.0}"
if [[ ! "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "Version must use major.minor.patch format." >&2
  exit 1
fi

repo_dir="$(cd "$(dirname "$0")/.." && pwd)"
cd "$repo_dir"
output_dir="$repo_dir/build/personal-dmg"
mkdir -p "$output_dir"

if [[ ! -d MoePeek.xcworkspace ]]; then
  if [[ ! -f Configurations/Signing.xcconfig ]]; then
    cp Configurations/Signing.xcconfig.example Configurations/Signing.xcconfig
  fi
  tuist install
  tuist generate --no-open
fi

xcodebuild archive \
  -workspace MoePeek.xcworkspace \
  -scheme MoePeek \
  -configuration Release \
  -destination 'generic/platform=macOS' \
  -archivePath "$output_dir/MoePeek.xcarchive" \
  -derivedDataPath build/DerivedData \
  ARCHS=arm64 ONLY_ACTIVE_ARCH=NO \
  CODE_SIGN_STYLE=Manual CODE_SIGN_IDENTITY=- DEVELOPMENT_TEAM= \
  VALIDATE_STRINGS_FILES_WHILE_COPYING=NO \
  MARKETING_VERSION="$version" CURRENT_PROJECT_VERSION="${GITHUB_RUN_NUMBER:-1}" \
  | tee "$output_dir/build.log"

app="$output_dir/MoePeek.xcarchive/Products/Applications/MoePeek.app"
test -d "$app"

# Personal packages must not fetch updates from the upstream release feed.
plist="$app/Contents/Info.plist"
/usr/libexec/PlistBuddy -c 'Add :MoePeekDisableUpdates bool true' "$plist"
/usr/libexec/PlistBuddy -c 'Add :SUEnableAutomaticChecks bool false' "$plist"
/usr/libexec/PlistBuddy -c 'Add :SUAllowsAutomaticUpdates bool false' "$plist"
/usr/libexec/PlistBuddy -c 'Delete :SUFeedURL' "$plist"
/usr/libexec/PlistBuddy -c 'Delete :SUPublicEDKey' "$plist"
codesign --force --sign - --timestamp=none "$app"
codesign --verify --deep --strict "$app"
test "$(/usr/libexec/PlistBuddy -c 'Print :MoePeekDisableUpdates' "$plist")" = true
test "$(lipo -archs "$app/Contents/MacOS/MoePeek")" = arm64

staging="$(mktemp -d "$output_dir/staging.XXXXXX")"
trap 'rm -rf "$staging"' EXIT
ditto "$app" "$staging/MoePeek.app"
ln -s /Applications "$staging/Applications"
dmg="$output_dir/MoePeek-${version}-personal-arm64.dmg"
hdiutil create -volname MoePeek -srcfolder "$staging" -format UDZO -ov "$dmg"
hdiutil verify "$dmg"
(cd "$output_dir" && shasum -a 256 "$(basename "$dmg")" > SHA256SUMS.txt)
echo "Built $dmg"
