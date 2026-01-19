# Keyboard Shortcuts Setup

## What Was Added

### 1. Keyboard Shortcut Model
- File: `lib/core/models/keyboard_shortcuts.dart`
- Defines `KeyboardShortcut` and `KeyboardShortcuts` classes
- Supports serialization to/from JSON for persistence

### 2. Settings Dialog
- File: `lib/features/settings/widgets/settings_dialog.dart`
- Full UI for editing keyboard shortcuts
- Built on Material's `AlertDialog`

### 3. Integration in App
- File: `lib/app.dart`
- Added Settings button (⚙️) to app bar
- Loads shortcuts from SharedPreferences on startup
- Updated keyboard handler to use configurable shortcuts
- Saves shortcuts to persistent storage

## Default Keyboard Shortcuts

| Action | Key |
|--------|-----|
| Next Frame | . (period) |
| Previous Frame | , (comma) |
| Play/Pause | Space |
| Jump Forward 1s | Shift + Right Arrow |
| Jump Backward 1s | Shift + Left Arrow |
| Open File | Ctrl + O |
| Save Annotations | Ctrl + S |
| Undo | Ctrl + Z |
| Redo | Ctrl + Y |

## How to Use

1. Click the Settings button (⚙️) in the top-right corner of the app
2. A dialog will appear showing all keyboard shortcuts
3. Click on any shortcut field to record a new key combination
4. Press the key (or key + modifiers) you want to use
5. Click "Save" to apply changes, or "Reset to Defaults" to restore defaults
6. Click "Cancel" to discard changes

## Technical Details

- Shortcuts are persisted using `SharedPreferences`
- Storage key: `keyboard_shortcuts`
- Data is stored as JSON
- The app loads shortcuts on startup
- All keyboard events go through the configurable shortcut handler in `_handleKeyEvent()`

## Files Modified/Created

- **Created**: `lib/core/models/keyboard_shortcuts.dart`
- **Created**: `lib/features/settings/widgets/settings_dialog.dart`
- **Created**: `lib/features/settings/providers/keyboard_shortcuts_provider.dart` (unused, can be deleted)
- **Modified**: `lib/app.dart`
