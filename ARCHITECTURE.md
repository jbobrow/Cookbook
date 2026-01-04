# Cookbook App Architecture

## Overview

The Cookbook app follows a clean MVVM (Model-View-ViewModel) architecture using SwiftUI and iCloud for storage.

## Architecture Diagram

```
┌─────────────────────────────────────────────────────────────┐
│                         Views Layer                         │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐    │
│  │  RecipeList  │  │ RecipeDetail │  │  RecipeEdit  │    │
│  │     View     │→ │     View     │  │     View     │    │
│  └──────────────┘  └──────────────┘  └──────────────┘    │
│         ↓                 ↓                  ↓             │
│         └─────────────────┴──────────────────┘             │
│                           ↓                                 │
└───────────────────────────┼─────────────────────────────────┘
                            ↓
                 @EnvironmentObject
                            ↓
┌───────────────────────────┼─────────────────────────────────┐
│                      Services Layer                         │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│                  ┌──────────────┐                          │
│                  │ RecipeStore  │                          │
│                  │ (Observable) │                          │
│                  └──────────────┘                          │
│                         ↓                                   │
│              ┌──────────┴──────────┐                       │
│              ↓                     ↓                        │
│      ┌──────────────┐      ┌──────────────┐               │
│      │    Local     │      │   iCloud     │               │
│      │   Storage    │  ←→  │   Sync       │               │
│      └──────────────┘      └──────────────┘               │
│                                    ↓                        │
└────────────────────────────────────┼────────────────────────┘
                                     ↓
┌────────────────────────────────────┼────────────────────────┐
│                         Models Layer                        │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  ┌────────────┐   ┌────────────┐   ┌────────────┐         │
│  │   Recipe   │   │ Ingredient │   │ Direction  │         │
│  │  (Codable) │   │  (Codable) │   │ (Codable)  │         │
│  └────────────┘   └────────────┘   └────────────┘         │
│                                                             │
└─────────────────────────────────────────────────────────────┘
                            ↓
                         Stored as
                            ↓
┌─────────────────────────────────────────────────────────────┐
│                    iCloud Storage                           │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│         iCloud Drive / Documents / Recipes /                │
│                                                             │
│         ├── [UUID-1].json                                   │
│         ├── [UUID-2].json                                   │
│         └── [UUID-3].json                                   │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

## Component Descriptions

### Views Layer

#### RecipeListView
- **Purpose**: Homepage displaying all recipes
- **Features**: 
  - Searchable list
  - Recipe thumbnails with metadata
  - Navigation to detail view
  - Add new recipe
  - Swipe to delete
- **State**: Observes RecipeStore

#### RecipeDetailView
- **Purpose**: Display full recipe information
- **Features**:
  - Recipe image
  - Checkable ingredients
  - Numbered directions
  - Metadata display
  - Mark as cooked
  - Edit navigation
- **State**: Receives recipe, observes store for updates

#### RecipeEditView
- **Purpose**: Create and edit recipes
- **Features**:
  - Photo picker
  - Form-based input
  - Dynamic ingredient/direction lists
  - Duration pickers
  - Rating selector
- **State**: Local state, saves to RecipeStore

### Services Layer

#### RecipeStore (Observable)
- **Purpose**: Single source of truth for recipe data
- **Responsibilities**:
  - Load recipes from iCloud
  - Save recipes to iCloud
  - Delete recipes
  - Maintain in-memory cache
  - Handle iCloud sync notifications
- **Published Properties**:
  - `recipes: [Recipe]` - Current recipe list

### Models Layer

#### Recipe
- **Purpose**: Core data model
- **Properties**:
  - `id: UUID` - Unique identifier
  - `title: String` - Recipe name
  - `imageData: Data?` - Photo data
  - `ingredients: [Ingredient]` - List of ingredients
  - `directions: [Direction]` - Ordered steps
  - `dateCreated: Date` - Creation timestamp
  - `datesCooked: [Date]` - Cooking history
  - `sourceURL: String` - Origin link
  - `rating: Int` - 0-5 stars
  - `prepDuration: TimeInterval` - Prep time
  - `cookDuration: TimeInterval` - Cook time
  - `notes: String` - Additional notes
- **Conformance**: Identifiable, Codable

#### Ingredient
- **Purpose**: Individual ingredient with checkbox state
- **Properties**:
  - `id: UUID`
  - `text: String`
  - `isChecked: Bool`
- **Conformance**: Identifiable, Codable

#### Direction
- **Purpose**: Ordered cooking step
- **Properties**:
  - `id: UUID`
  - `text: String`
  - `order: Int`
- **Conformance**: Identifiable, Codable

## Data Flow

### Creating a Recipe

```
User Input → RecipeEditView → RecipeStore.saveRecipe()
                                    ↓
                           JSONEncoder.encode()
                                    ↓
                           Write to iCloud file
                                    ↓
                           Update @Published recipes
                                    ↓
                           Views automatically refresh
```

### Loading Recipes

```
App Launch → RecipeStore.init()
                  ↓
           setupiCloudDirectory()
                  ↓
           loadRecipes()
                  ↓
      Read iCloud directory
                  ↓
      For each .json file:
      - JSONDecoder.decode()
      - Add to recipes array
                  ↓
      Sort alphabetically
                  ↓
      @Published triggers view update
```

### Syncing via iCloud

```
Device A: Save recipe
       ↓
iCloud uploads .json file
       ↓
iCloud syncs to Device B
       ↓
NSUbiquitousKeyValueStore notification
       ↓
Device B: RecipeStore.iCloudDataChanged()
       ↓
RecipeStore.loadRecipes()
       ↓
UI updates automatically
```

## Storage Strategy

### Why Flat Files?

1. **Simplicity**: Easy to understand and debug
2. **Portability**: JSON is universal
3. **Backup-friendly**: Simple to export/import
4. **iCloud Integration**: Works seamlessly with CloudDocuments
5. **No Dependencies**: No database framework needed

### File Naming Convention

Files are named using UUIDs: `[UUID].json`
- Ensures uniqueness
- Prevents conflicts
- Platform independent

### Sync Strategy

- **Write**: Immediate write to iCloud on save
- **Read**: On app launch and iCloud notification
- **Conflict Resolution**: Last-write-wins (handled by iCloud)
- **Performance**: In-memory cache prevents constant file reads

## Cross-Platform Support

### Platform Abstraction

```swift
#if os(iOS)
typealias PlatformImage = UIImage
#elseif os(macOS)
typealias PlatformImage = NSImage
#endif
```

### Platform-Specific Features

- **iOS**: PhotosPicker for camera roll access
- **macOS**: Same PhotosPicker works for file system
- **Shared**: All business logic is platform-agnostic

## Performance Considerations

### Memory Management
- Images stored as `Data` in memory
- Large images may impact performance
- Consider implementing image compression

### File I/O
- Recipes cached in memory
- File reads only on app launch and sync
- Async file operations prevent UI blocking

### Scalability
- Current design works well for 100-1000 recipes
- For 10,000+ recipes, consider:
  - Pagination
  - Lazy loading
  - Database solution

## Security

### Data Privacy
- All data stored in user's iCloud account
- No external servers
- Apple handles encryption

### Authentication
- iCloud authentication via Apple ID
- Automatic secure storage

## Error Handling

### Storage Errors
- Logged to console
- Silent failures (user experience preserved)
- Consider adding user notifications

### Sync Errors
- Automatic retry via iCloud
- No manual intervention needed

## Future Architecture Improvements

### Potential Enhancements
1. **CoreData Integration**: Better performance at scale
2. **CloudKit**: More advanced sync features
3. **Image Optimization**: Automatic compression
4. **Offline Mode**: Better offline handling
5. **Conflict Resolution**: Custom merge strategies
6. **Background Sync**: App refresh background tasks
7. **Search Indexing**: Spotlight integration

### Testing Strategy
1. **Unit Tests**: Model encoding/decoding
2. **Integration Tests**: Storage operations
3. **UI Tests**: User flows
4. **Sync Tests**: Multi-device scenarios

## Design Patterns Used

- **MVVM**: Separation of concerns
- **Observer**: @Published and ObservableObject
- **Repository**: RecipeStore as data access layer
- **Singleton**: Single RecipeStore instance via @StateObject
- **Dependency Injection**: Via @EnvironmentObject

## Best Practices Implemented

1. ✅ SwiftUI property wrappers for state management
2. ✅ Codable for serialization
3. ✅ UUID for unique identifiers
4. ✅ Optional chaining for safety
5. ✅ Error handling with try-catch
6. ✅ Platform abstractions for cross-platform code
7. ✅ Proper separation of concerns
8. ✅ Observable pattern for reactive updates
