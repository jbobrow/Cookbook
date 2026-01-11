# Mac App Distribution Guide

## The Problem: "The application Cookbook can't be opened"

When you archive your Mac app and send it to another computer, macOS Gatekeeper blocks it with the error **"The application Cookbook can't be opened"**.

### Why This Happens

1. **Development Signing**: Your app is signed with a Development Team certificate (63KWA2RPU8), which only works on your development machines
2. **Gatekeeper Protection**: macOS 10.15+ requires all apps from outside the App Store to be **notarized** by Apple
3. **Hardened Runtime**: Your app has `ENABLE_HARDENED_RUNTIME = YES` (good!), which requires notarization for distribution
4. **App Sandbox**: Enabled with iCloud entitlements, which increases security requirements

### Current Build Settings

```
CODE_SIGN_STYLE = Automatic
DEVELOPMENT_TEAM = 63KWA2RPU8
ENABLE_HARDENED_RUNTIME = YES
ENABLE_APP_SANDBOX = YES
CODE_SIGN_ENTITLEMENTS = Cookbook/Cookbook.entitlements
PRODUCT_BUNDLE_IDENTIFIER = com.jonbobrow.Cookbook
```

## Solutions

### Option 1: Notarize for Outside App Store Distribution (Recommended)

This allows you to distribute directly to users while maintaining security.

#### Prerequisites

- Apple Developer Program membership ($99/year)
- Valid Developer ID Application certificate (not Development certificate)
- App-specific password for notarization

#### Steps

1. **Create Distribution Certificate**
   - Go to [Apple Developer Certificates](https://developer.apple.com/account/resources/certificates)
   - Create a "Developer ID Application" certificate
   - Download and install in Keychain

2. **Update Xcode Project**
   - Change `CODE_SIGN_STYLE` to `Manual` for Release builds
   - Select "Developer ID Application" certificate for Release
   - Keep "Apple Development" for Debug builds

3. **Archive the App**
   ```bash
   xcodebuild -project Cookbook.xcodeproj \
     -scheme Cookbook \
     -configuration Release \
     -archivePath ./build/Cookbook.xcarchive \
     archive
   ```

4. **Export for Distribution**
   ```bash
   xcodebuild -exportArchive \
     -archivePath ./build/Cookbook.xcarchive \
     -exportPath ./build/export \
     -exportOptionsPlist exportOptions.plist
   ```

5. **Notarize with Apple**
   ```bash
   # Create a zip of the app
   ditto -c -k --keepParent ./build/export/Cookbook.app Cookbook.zip

   # Submit for notarization (requires app-specific password)
   xcrun notarytool submit Cookbook.zip \
     --apple-id "your@email.com" \
     --password "xxxx-xxxx-xxxx-xxxx" \
     --team-id "63KWA2RPU8" \
     --wait

   # Staple the notarization ticket
   xcrun stapler staple ./build/export/Cookbook.app
   ```

6. **Create DMG for Distribution**
   ```bash
   hdiutil create -volname "Cookbook" \
     -srcfolder ./build/export/Cookbook.app \
     -ov -format UDZO Cookbook.dmg
   ```

See the included `notarize.sh` script for automation.

### Option 2: App Store Distribution (Best for Public Release)

Distributing through the Mac App Store provides the best user experience.

#### Prerequisites

- Apple Developer Program membership
- Mac App Store provisioning profile
- App Store Connect listing

#### Steps

1. **Create App Store Profile**
   - Go to [Apple Developer Provisioning Profiles](https://developer.apple.com/account/resources/profiles)
   - Create "Mac App Store" distribution profile

2. **Update Entitlements**
   - Ensure all capabilities are properly configured
   - iCloud entitlements are already set up

3. **Archive and Upload**
   - In Xcode: Product → Archive
   - In Organizer: Distribute App → App Store Connect
   - Submit for review

4. **TestFlight** (Optional)
   - Enable TestFlight for Mac
   - Invite beta testers
   - Get feedback before public release

### Option 3: Developer ID Installer Package

Create a signed installer package (.pkg) instead of a bare .app.

```bash
productbuild --component ./build/export/Cookbook.app /Applications \
  --sign "Developer ID Installer: Your Name (63KWA2RPU8)" \
  Cookbook.pkg

# Notarize the package
xcrun notarytool submit Cookbook.pkg \
  --apple-id "your@email.com" \
  --password "xxxx-xxxx-xxxx-xxxx" \
  --team-id "63KWA2RPU8" \
  --wait

# Staple
xcrun stapler staple Cookbook.pkg
```

## Quick Workarounds (Testing Only)

### For the Recipient (Not Recommended for Distribution)

1. **Remove Quarantine Attribute**
   ```bash
   xattr -cr /path/to/Cookbook.app
   ```

2. **Manually Allow in System Settings**
   - Try to open the app (it will fail)
   - Go to System Settings → Privacy & Security
   - Click "Open Anyway" next to the Cookbook warning

3. **Disable Gatekeeper Temporarily** (Dangerous)
   ```bash
   sudo spctl --master-disable
   # Open the app
   sudo spctl --master-enable
   ```

### For Development/Testing

If sending to a known tester with technical skills:

1. **Share via AirDrop or secure file transfer** (avoid email, which adds quarantine)
2. **Include instructions** for removing quarantine attribute
3. **Sign with Ad Hoc provisioning** if you have their device UDID

## Recommended Approach

For distribution to other users:

1. **Short term**: Use the "Remove Quarantine" workaround for a few test users
2. **Long term**: Set up proper notarization (Option 1) or App Store distribution (Option 2)

### Why Notarization Matters

- **User Trust**: Users see a green checkmark and your verified developer name
- **Security**: Apple scans for malware before allowing distribution
- **Future-Proof**: Required by macOS for all non-App Store apps
- **No Warnings**: Users don't see scary security warnings

## Files Reference

- **Xcode Project**: `Cookbook.xcodeproj/project.pbxproj`
- **Entitlements**: `Cookbook/Cookbook.entitlements` (iCloud setup)
- **Info.plist**: `Cookbook/Info.plist` (app metadata)
- **Notarization Script**: `scripts/notarize.sh` (automated notarization)
- **Export Options**: `exportOptions.plist` (export configuration)

## App-Specific Password Setup

To notarize, you need an app-specific password:

1. Go to [appleid.apple.com](https://appleid.apple.com)
2. Sign in with your Apple ID
3. Under Security → App-Specific Passwords → Generate
4. Name it "Cookbook Notarization"
5. Save the password (format: xxxx-xxxx-xxxx-xxxx)

## Checking Notarization Status

```bash
# Check if an app is notarized
spctl -a -vvv -t install /path/to/Cookbook.app

# Check stapling status
xcrun stapler validate /path/to/Cookbook.app

# View notarization history
xcrun notarytool history --apple-id "your@email.com" --team-id "63KWA2RPU8"
```

## Troubleshooting

### "The app is damaged and can't be opened"
- App was modified after signing
- Quarantine attribute is preventing opening
- Run: `xattr -cr /path/to/Cookbook.app`

### "Code signature invalid"
- Certificate expired or revoked
- Need to re-sign with valid certificate

### "Notarization failed"
- Check hardened runtime is enabled ✓ (already set)
- Check entitlements are valid ✓ (iCloud configured correctly)
- Review notarization log: `xcrun notarytool log <submission-id>`

### "App won't launch on fresh install"
- Check iCloud permissions
- Ensure user is signed into iCloud (required by entitlements)
- Verify `com.jonbobrow.Cookbook` bundle ID is registered

## Next Steps

1. Decide on distribution method (Notarization vs App Store)
2. If notarizing: Create Developer ID Application certificate
3. If App Store: Create App Store Connect listing
4. Set up automated build/notarization pipeline
5. Test on a fresh Mac before distributing widely

## Resources

- [Notarizing macOS Software Before Distribution](https://developer.apple.com/documentation/security/notarizing_macos_software_before_distribution)
- [Customizing the Notarization Workflow](https://developer.apple.com/documentation/security/customizing_the_notarization_workflow)
- [Hardened Runtime](https://developer.apple.com/documentation/security/hardened_runtime)
- [App Sandbox](https://developer.apple.com/documentation/security/app_sandbox)
