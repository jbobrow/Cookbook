# Opening Cookbook on Your Mac

If you received a test build of Cookbook and see the error **"The application Cookbook can't be opened"**, follow these instructions:

## Quick Fix (2 steps)

### Step 1: Extract the ZIP file
Double-click `Cookbook.zip` or `Cookbook-test.zip` to extract the app.

### Step 2: Remove the quarantine attribute

1. Open **Terminal** (Applications → Utilities → Terminal)
2. Type the following command and press Enter:

```bash
xattr -cr
```

**Important**: Add a space after `-cr`, then drag the `Cookbook.app` file from Finder into the Terminal window. Your command should look like:

```bash
xattr -cr /Users/yourname/Downloads/Cookbook.app
```

3. Press **Enter**
4. Double-click `Cookbook.app` to open it

## Alternative Method: System Settings

If the Terminal method doesn't work:

1. Try to double-click `Cookbook.app` (it will show an error)
2. Go to **System Settings** → **Privacy & Security**
3. Scroll down to the **Security** section
4. You'll see a message about "Cookbook was blocked"
5. Click **Open Anyway**
6. Confirm when prompted

## Why Is This Necessary?

This is a **test build** that hasn't been notarized with Apple yet. macOS's Gatekeeper security feature blocks apps from "unidentified developers" by default.

The final release version will be properly signed and notarized, so you won't need these steps.

## Troubleshooting

### "xattr: command not found"
The command should work on all modern Macs. Make sure you're in the Terminal app, not a text editor.

### App still won't open
1. Make sure you extracted the ZIP file first (don't try to open from the ZIP)
2. Try moving the app to your Applications folder first
3. Check that you're running macOS 14.6 or later (required)

### "App is damaged and can't be opened"
This usually means the download was corrupted. Ask the sender for a fresh copy.

### Still having issues?
Contact the developer with details about:
- Your macOS version (Apple menu → About This Mac)
- The exact error message you see
- Screenshot if possible

## App Requirements

- macOS 14.6 or later
- Signed into iCloud (the app uses iCloud for recipe storage)

## First Launch

When you first open Cookbook:
1. You may be asked to grant photo library access (for adding images to recipes)
2. The app will set up iCloud storage for your recipes
3. Your recipes will sync across your Apple devices signed into the same iCloud account
