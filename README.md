# Cookbook - A Minimalist Recipe Manager

A clean, minimalist SwiftUI app for iOS and macOS that stores recipes in flat files synced via iCloud.

## Features

### Recipe Management
- **Picture**: Add a photo for each recipe
- **Ingredients Checklist**: Check off ingredients as you gather them
- **Step-by-Step Directions**: Numbered instructions for easy following
- **Metadata**:
  - Date created (automatic)
  - Dates cooked (track when you made it)
  - Source URL (link to original recipe)
  - Star rating (0-5 stars)
  - Prep time
  - Cook time
  - Notes

### User Interface
- **Homepage**: Quick, searchable list of all recipes
- **Search**: Filter by recipe name or ingredients
- **Minimalist Design**: Clean, uncluttered interface
- **Cross-Platform**: Works on both iOS and macOS

### Data Storage
- Recipes stored as individual JSON files in iCloud
- Automatic sync across all your devices
- No database dependencies
- Easy to backup and export

## Project Structure

```
CookbookApp/
├── Models/
│   └── Recipe.swift          # Data models
├── Services/
│   └── RecipeStore.swift     # iCloud storage manager
├── Views/
│   ├── RecipeListView.swift  # Homepage with search
│   ├── RecipeDetailView.swift # Recipe viewing
│   └── RecipeEditView.swift  # Recipe editing
├── CookbookApp.swift         # App entry point
└── Cookbook.entitlements     # iCloud configuration
```

## Setup Instructions

### 1. Xcode Project Setup

1. Open Xcode and create a new project:
   - Choose "Multiplatform App"
   - Product Name: "Cookbook"
   - Interface: SwiftUI
   - Language: Swift

2. Add all the Swift files to your project in the appropriate groups

3. Add the entitlements file to your project

### 2. Configure iCloud

1. In Xcode, select your project in the navigator
2. Select your app target
3. Go to "Signing & Capabilities" tab
4. Click "+ Capability" and add "iCloud"
5. Enable "iCloud Documents"
6. The container identifier should be: `iCloud.$(CFBundleIdentifier)`

### 3. Configure Entitlements

1. In your target's "Signing & Capabilities":
   - Make sure the entitlements file is linked
   - Verify iCloud is enabled with CloudDocuments service

### 4. Info.plist Configuration

Add these keys if needed:
```xml
<key>NSPhotoLibraryUsageDescription</key>
<string>To add photos to your recipes</string>
```

### 5. Build and Run

1. Select your target device/simulator
2. Ensure you're signed in with an Apple ID that has iCloud enabled
3. Build and run (⌘R)

## Requirements

- iOS 17.0+ / macOS 14.0+
- Xcode 15.0+
- Apple ID with iCloud enabled
- Active internet connection for iCloud sync

## Usage

### Adding a Recipe

1. Tap the "+" button in the navigation bar
2. Fill in the recipe details:
   - Add a photo
   - Enter title, source URL, and rating
   - Set prep and cook times
   - Add ingredients (tap + to add each one)
   - Add directions (tap + to add each step)
   - Add any notes
3. Tap "Save"

### Viewing a Recipe

1. Tap any recipe from the list
2. Check off ingredients as you gather them
3. Follow the numbered directions
4. Tap "Mark as Cooked" when finished

### Editing a Recipe

1. Open the recipe detail view
2. Tap "Edit" in the navigation bar
3. Make your changes
4. Tap "Save"

### Searching Recipes

- Use the search bar at the top of the recipe list
- Search by recipe title or ingredients
- Results filter in real-time

## Data Storage Details

### File Format
Each recipe is stored as a JSON file named with its UUID:
```
iCloud/Documents/Recipes/
├── [UUID-1].json
├── [UUID-2].json
└── [UUID-3].json
```

### iCloud Sync
- Automatic synchronization across devices
- Files are stored in the ubiquity container
- Changes propagate when devices are online
- Conflicts are handled by last-write-wins

### Backup
Recipe files can be found in:
```
~/Library/Mobile Documents/iCloud~[YourBundleID]/Documents/Recipes/
```

## Customization

### Changing Colors
The app uses the system accent color by default. To customize:
1. Open `Assets.xcassets`
2. Add a new "Color Set" named "AccentColor"
3. Set your preferred color

### Modifying Time Increments
In `RecipeEditView.swift`, adjust the time picker increments:
```swift
ForEach(0..<60, id: \.self) { minute in
    if minute % 5 == 0 {  // Change this for different increments
        Text("\(minute)m").tag(minute)
    }
}
```

## Troubleshooting

### iCloud Not Working
1. Verify iCloud Drive is enabled in System Settings
2. Check that you're signed in with an Apple ID
3. Ensure iCloud capabilities are properly configured in Xcode
4. Check console logs for specific errors

### Recipes Not Syncing
1. Check internet connection
2. Verify iCloud Drive has sufficient storage
3. Force quit and restart the app
4. Check iCloud sync status in System Settings

### Photos Not Showing
1. Grant photo library permissions
2. Check that image data is being properly encoded
3. Verify file sizes aren't too large (images are stored as data)

## Future Enhancements

Potential features to add:
- Recipe categories/tags
- Meal planning
- Shopping list generation
- Recipe sharing (via JSON export)
- Unit conversion
- Timer integration
- Print recipes
- Import from URLs
- Nutrition information
- Recipe scaling

## License

This project is provided as-is for personal use.

## Contributing

Feel free to fork and customize for your own needs!
