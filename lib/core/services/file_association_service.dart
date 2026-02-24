import 'dart:ffi';
import 'dart:io';
import 'package:ffi/ffi.dart';
import 'package:win32/win32.dart' hide DocumentProperties;

/// Service for managing Windows file associations
class FileAssociationService {
  static const String videoProgId = 'FrameSketchPlayer.VideoFile';
  static const String annotationProgId = 'FrameSketchPlayer.AnnotationFile';
  static const String appName = 'FrameSketch Player';
  static const String annotationExtension = '.framesketch';
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

      // Create ProgIDs
      _createVideoProgId(exePath);
      _createAnnotationProgId(exePath);

      // Register each extension
      for (final ext in videoExtensions) {
        _registerVideoExtension(ext);
      }
      _registerAnnotationExtension();

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
      _deleteRegistryKey(HKEY_CURRENT_USER, 'Software\\Classes\\$videoProgId');
      _deleteRegistryKey(
        HKEY_CURRENT_USER,
        'Software\\Classes\\$annotationProgId',
      );

      // Remove from each extension
      for (final ext in videoExtensions) {
        _removeVideoExtensionAssociation(ext);
      }
      _removeAnnotationExtensionAssociation();

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
      final hasVideoProgId = _registryKeyExists(
        HKEY_CURRENT_USER,
        'Software\\Classes\\$videoProgId',
      );
      final hasAnnotationProgId = _registryKeyExists(
        HKEY_CURRENT_USER,
        'Software\\Classes\\$annotationProgId',
      );
      return hasVideoProgId && hasAnnotationProgId;
    } catch (e) {
      // Rethrow to allow proper error handling
      rethrow;
    }
  }

  void _createVideoProgId(String exePath) {
    // Create main ProgID key
    _setRegistryValue(
      HKEY_CURRENT_USER,
      'Software\\Classes\\$videoProgId',
      '',
      '$appName Video File',
    );

    // Set icon
    _setRegistryValue(
      HKEY_CURRENT_USER,
      'Software\\Classes\\$videoProgId\\DefaultIcon',
      '',
      '"$exePath",0',
    );

    // Set open command
    _setRegistryValue(
      HKEY_CURRENT_USER,
      'Software\\Classes\\$videoProgId\\shell\\open\\command',
      '',
      '"$exePath" "%1"',
    );
  }

  void _createAnnotationProgId(String exePath) {
    _setRegistryValue(
      HKEY_CURRENT_USER,
      'Software\\Classes\\$annotationProgId',
      '',
      '$appName Annotation File',
    );

    _setRegistryValue(
      HKEY_CURRENT_USER,
      'Software\\Classes\\$annotationProgId\\DefaultIcon',
      '',
      '"$exePath",0',
    );

    _setRegistryValue(
      HKEY_CURRENT_USER,
      'Software\\Classes\\$annotationProgId\\shell\\open\\command',
      '',
      '"$exePath" "%1"',
    );
  }

  void _registerVideoExtension(String ext) {
    // Add to OpenWithProgids
    _setRegistryValue(
      HKEY_CURRENT_USER,
      'Software\\Classes\\$ext\\OpenWithProgids',
      videoProgId,
      '',
      valueType: REG_SZ,
    );
  }

  void _registerAnnotationExtension() {
    // Make the app the default handler for the app-specific annotation format.
    _setRegistryValue(
      HKEY_CURRENT_USER,
      'Software\\Classes\\$annotationExtension',
      '',
      annotationProgId,
    );
    _setRegistryValue(
      HKEY_CURRENT_USER,
      'Software\\Classes\\$annotationExtension',
      'PerceivedType',
      'text',
    );
    _setRegistryValue(
      HKEY_CURRENT_USER,
      'Software\\Classes\\$annotationExtension\\OpenWithProgids',
      annotationProgId,
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
    _setRegistryValue(
      HKEY_CURRENT_USER,
      'Software\\Classes\\Applications\\framesketch_player.exe\\SupportedTypes',
      annotationExtension,
      '',
    );

    // Set shell command
    _setRegistryValue(
      HKEY_CURRENT_USER,
      'Software\\Classes\\Applications\\framesketch_player.exe\\shell\\open\\command',
      '',
      '"$exePath" "%1"',
    );
  }

  void _removeVideoExtensionAssociation(String ext) {
    try {
      // Remove from OpenWithProgids
      _deleteRegistryValue(
        HKEY_CURRENT_USER,
        'Software\\Classes\\$ext\\OpenWithProgids',
        videoProgId,
      );
    } catch (e) {
      // Ignore errors - key might not exist
    }
  }

  void _removeAnnotationExtensionAssociation() {
    try {
      _deleteRegistryKey(
        HKEY_CURRENT_USER,
        'Software\\Classes\\$annotationExtension',
      );
    } catch (_) {}
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

  bool _registryKeyExists(int hKeyRoot, String keyPath) {
    final hKey = calloc<HKEY>();
    final keyPathPtr = keyPath.toNativeUtf16();
    try {
      final result = RegOpenKeyEx(hKeyRoot, keyPathPtr, 0, KEY_READ, hKey);
      if (result == ERROR_SUCCESS) {
        RegCloseKey(hKey.value);
        return true;
      }
      return false;
    } finally {
      calloc.free(keyPathPtr);
      calloc.free(hKey);
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
