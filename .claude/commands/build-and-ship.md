Build MeetsVault, zip the app bundle, and copy it to the Desktop (replacing any existing zip).

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

echo "Zipping..."
cd build/Build/Products/Release
zip -r MeetsVault.zip MeetsVault.app
cd -

echo "Copying to Desktop..."
cp -f build/Build/Products/Release/MeetsVault.zip ~/Desktop/MeetsVault.zip

echo "Done: ~/Desktop/MeetsVault.zip"
```
