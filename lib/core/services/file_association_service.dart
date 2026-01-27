import 'dart:ffi';
import 'dart:io';
import 'package:ffi/ffi.dart';
import 'package:win32/win32.dart' hide DocumentProperties;

/// Service for managing Windows file associations
class FileAssociationService {
  static const String progId = 'FrameSketchPlayer.VideoFile';
  static const String appName = 'FrameSketch Player';
  static const List<String> videoExtensions = [
    '.mp4',
    '.mov',
    '.mkv',
    '.avi',
    '.webm',
    '.flv',
    '.m4v',
  ];

  /// Get the path to the current executable
  String _getExecutablePath() {
    return Platform.resolvedExecutable;
  }

  /// Register file associations for all video formats
  Future<bool> registerFileAssociations() async {
    if (!Platform.isWindows) {
      throw UnsupportedError('File associations are only supported on Windows');
    }

    try {
      final exePath = _getExecutablePath();

      // Create ProgID
      _createProgId(exePath);

      // Register each extension
      for (final ext in videoExtensions) {
        _registerExtension(ext);
      }

      // Register in Applications list
      _registerApplication(exePath);

      // Notify shell of changes
      _notifyShell();

      return true;
    } catch (e) {
      // Rethrow to allow proper error handling
      rethrow;
    }
  }

  /// Unregister file associations
  Future<bool> unregisterFileAssociations() async {
    if (!Platform.isWindows) {
      throw UnsupportedError('File associations are only supported on Windows');
    }

    try {
      // Remove ProgID
      _deleteRegistryKey(HKEY_CURRENT_USER, 'Software\\Classes\\$progId');

      // Remove from each extension
      for (final ext in videoExtensions) {
        _removeExtensionAssociation(ext);
      }

      // Remove from Applications
      _deleteRegistryKey(
        HKEY_CURRENT_USER,
        'Software\\Classes\\Applications\\framesketch_player.exe',
      );

      // Notify shell of changes
      _notifyShell();

      return true;
    } catch (e) {
      // Rethrow to allow proper error handling
      rethrow;
    }
  }

  /// Check if file associations are currently registered
  Future<bool> isRegistered() async {
    if (!Platform.isWindows) {
      return false;
    }

    try {
      final keyPath = 'Software\\Classes\\$progId';
      final hKey = calloc<HKEY>();

      try {
        final result = RegOpenKeyEx(
          HKEY_CURRENT_USER,
          keyPath.toNativeUtf16(),
          0,
          KEY_READ,
          hKey,
        );

        if (result == ERROR_SUCCESS) {
          RegCloseKey(hKey.value);
          return true;
        }
        return false;
      } finally {
        calloc.free(hKey);
      }
    } catch (e) {
      // Rethrow to allow proper error handling
      rethrow;
    }
  }

  void _createProgId(String exePath) {
    // Create main ProgID key
    _setRegistryValue(
      HKEY_CURRENT_USER,
      'Software\\Classes\\$progId',
      '',
      '$appName Video File',
    );

    // Set icon
    _setRegistryValue(
      HKEY_CURRENT_USER,
      'Software\\Classes\\$progId\\DefaultIcon',
      '',
      '"$exePath",0',
    );

    // Set open command
    _setRegistryValue(
      HKEY_CURRENT_USER,
      'Software\\Classes\\$progId\\shell\\open\\command',
      '',
      '"$exePath" "%1"',
    );
  }

  void _registerExtension(String ext) {
    // Add to OpenWithProgids
    _setRegistryValue(
      HKEY_CURRENT_USER,
      'Software\\Classes\\$ext\\OpenWithProgids',
      progId,
      '',
      valueType: REG_SZ,
    );
  }

  void _registerApplication(String exePath) {
    // Set friendly name
    _setRegistryValue(
      HKEY_CURRENT_USER,
      'Software\\Classes\\Applications\\framesketch_player.exe',
      'FriendlyAppName',
      appName,
    );

    // Register supported types
    for (final ext in videoExtensions) {
      _setRegistryValue(
        HKEY_CURRENT_USER,
        'Software\\Classes\\Applications\\framesketch_player.exe\\SupportedTypes',
        ext,
        '',
      );
    }

    // Set shell command
    _setRegistryValue(
      HKEY_CURRENT_USER,
      'Software\\Classes\\Applications\\framesketch_player.exe\\shell\\open\\command',
      '',
      '"$exePath" "%1"',
    );
  }

  void _removeExtensionAssociation(String ext) {
    try {
      // Remove from OpenWithProgids
      _deleteRegistryValue(
        HKEY_CURRENT_USER,
        'Software\\Classes\\$ext\\OpenWithProgids',
        progId,
      );
    } catch (e) {
      // Ignore errors - key might not exist
    }
  }

  void _setRegistryValue(
    int hKey,
    String keyPath,
    String valueName,
    String value, {
    int valueType = REG_SZ,
  }) {
    final hKeyResult = calloc<HKEY>();
    final lpSubKey = keyPath.toNativeUtf16();

    try {
      // Create or open the key
      final result = RegCreateKeyEx(
        hKey,
        lpSubKey,
        0,
        nullptr,
        REG_OPTION_NON_VOLATILE,
        KEY_WRITE,
        nullptr,
        hKeyResult,
        nullptr,
      );

      if (result == ERROR_SUCCESS) {
        final lpValueName = valueName.toNativeUtf16();
        final lpData = value.toNativeUtf16();

        RegSetValueEx(
          hKeyResult.value,
          lpValueName,
          0,
          valueType,
          lpData.cast<Uint8>(),
          (value.length + 1) * 2,
        );

        calloc.free(lpValueName);
        calloc.free(lpData);
        RegCloseKey(hKeyResult.value);
      }
    } finally {
      calloc.free(lpSubKey);
      calloc.free(hKeyResult);
    }
  }

  void _deleteRegistryKey(int hKey, String keyPath) {
    final lpSubKey = keyPath.toNativeUtf16();
    try {
      RegDeleteTree(hKey, lpSubKey);
    } finally {
      calloc.free(lpSubKey);
    }
  }

  void _deleteRegistryValue(int hKey, String keyPath, String valueName) {
    final hKeyResult = calloc<HKEY>();
    final lpSubKey = keyPath.toNativeUtf16();

    try {
      final result = RegOpenKeyEx(
        hKey,
        lpSubKey,
        0,
        KEY_WRITE,
        hKeyResult,
      );

      if (result == ERROR_SUCCESS) {
        final lpValueName = valueName.toNativeUtf16();
        RegDeleteValue(hKeyResult.value, lpValueName);
        calloc.free(lpValueName);
        RegCloseKey(hKeyResult.value);
      }
    } finally {
      calloc.free(lpSubKey);
      calloc.free(hKeyResult);
    }
  }

  void _notifyShell() {
    // Notify Windows that file associations have changed
    final shell32 = DynamicLibrary.open('shell32.dll');
    final shChangeNotify = shell32.lookupFunction<
        Void Function(Int32 wEventId, Uint32 uFlags, Pointer<Void> dwItem1, Pointer<Void> dwItem2),
        void Function(int wEventId, int uFlags, Pointer<Void> dwItem1, Pointer<Void> dwItem2)>('SHChangeNotify');

    const shcneAssocChanged = 0x08000000;
    const shcnfIdList = 0x0000;

    shChangeNotify(shcneAssocChanged, shcnfIdList, nullptr, nullptr);
  }
}
