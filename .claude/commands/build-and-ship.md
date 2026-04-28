Build MeetsVault, zip the app bundle with a timestamped filename, and copy it to iCloud Documents.

```bash
set -e

echo "Building MeetsVault..."
xcodebuild -project MeetsVault.xcodeproj \
  -scheme MeetsVault \
  -configuration Release \
  -destination "platform=macOS,arch=arm64" \
  -derivedDataPath build \
  build 2>&1 | tail -20

APP_PATH="build/Build/Products/Release/MeetsVault.app"

if [ ! -d "$APP_PATH" ]; then
  echo "Build failed: $APP_PATH not found"
  exit 1
fi

STAMP=$(date +%Y-%m-%d_%H-%M-%S)
ZIP_NAME="MeetsVault_${STAMP}.zip"
DEST_DIR="/Users/german/Library/Mobile Documents/com~apple~CloudDocs/Documents"

echo "Zipping as ${ZIP_NAME}..."
cd build/Build/Products/Release
zip -r "${ZIP_NAME}" MeetsVault.app
cd -

echo "Copying to iCloud Documents..."
cp -f "build/Build/Products/Release/${ZIP_NAME}" "${DEST_DIR}/${ZIP_NAME}"

echo "Done: ${DEST_DIR}/${ZIP_NAME}"
```
