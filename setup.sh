#!/usr/bin/env bash
#
# One-time setup for the Plantex mobile app.
# Generates the native android/ios shells (Flutter SDK does this — it can't be
# committed) and patches the camera permission + min-SDK that the barcode
# scanner (mobile_scanner) needs. After this, just build the APK.
#
#   bash setup.sh
#   flutter build apk --release
#
set -e

command -v flutter >/dev/null 2>&1 || { echo "ERROR: Flutter SDK not found in PATH. Install: https://docs.flutter.dev/get-started/install"; exit 1; }

echo "==> flutter create  (generates android/ + ios/, does NOT touch lib/)"
flutter create . --org work.plantex --platforms=android,ios --project-name plantex_mobile

echo "==> flutter pub get"
flutter pub get

MANIFEST="android/app/src/main/AndroidManifest.xml"
GRADLE="android/app/build.gradle"
GRADLE_KTS="android/app/build.gradle.kts"
PLIST="ios/Runner/Info.plist"

# --- Android: CAMERA permission (mobile_scanner) ---
if [ -f "$MANIFEST" ] && ! grep -q "android.permission.CAMERA" "$MANIFEST"; then
  echo "==> AndroidManifest: add CAMERA permission"
  perl -0pi -e 's/(<manifest\b[^>]*>)/$1\n    <uses-permission android:name="android.permission.CAMERA" \/>/' "$MANIFEST"
fi

# --- Android: minSdk 21 (mobile_scanner requires >= 21) ---
if [ -f "$GRADLE" ]; then
  echo "==> build.gradle: minSdk 21"
  perl -0pi -e 's/minSdkVersion\s+flutter\.minSdkVersion/minSdkVersion 21/g; s/minSdk\s*=?\s*flutter\.minSdkVersion/minSdk 21/g' "$GRADLE"
fi
if [ -f "$GRADLE_KTS" ]; then
  echo "==> build.gradle.kts: minSdk 21"
  perl -0pi -e 's/minSdk\s*=\s*flutter\.minSdkVersion/minSdk = 21/g' "$GRADLE_KTS"
fi

# --- iOS: camera usage description ---
if [ -f "$PLIST" ] && ! grep -q "NSCameraUsageDescription" "$PLIST"; then
  echo "==> Info.plist: add NSCameraUsageDescription"
  perl -0pi -e 's/(<dict>)/$1\n\t<key>NSCameraUsageDescription<\/key>\n\t<string>Used to scan product and box barcodes.<\/string>/' "$PLIST"
fi

echo ""
echo "==> Setup complete. Build the app:"
echo "    flutter build apk --release        # Android"
echo "    flutter build ipa --release        # iOS (on a Mac)"
echo "    flutter run                        # dev run on a device/emulator"
echo "    # point at a different backend:  --dart-define=API_BASE_URL=http://10.0.2.2:8000"
