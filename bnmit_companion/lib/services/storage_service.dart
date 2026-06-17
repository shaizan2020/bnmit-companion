import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:bnmit_companion/core/constants.dart';

class StorageService {
  final FlutterSecureStorage _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: false,
      resetOnError: true,
    ),
  );

  // Credentials
  Future<void> saveCredentials({
    required String username,
    required String dob,
    required int idType,
    required String verificationDigits,
    required String semester,
  }) async {
    await _storage.write(key: AppConstants.keyUsername, value: username);
    await _storage.write(key: AppConstants.keyDob, value: dob);
    await _storage.write(key: AppConstants.keyIdType, value: idType.toString());
    await _storage.write(key: AppConstants.keyVerificationDigits, value: verificationDigits);
    await _storage.write(key: AppConstants.keySemester, value: semester);
    await _storage.write(key: AppConstants.keyIsLoggedIn, value: 'true');
  }

  Future<Map<String, String>?> getCredentials() async {
    final username = await _storage.read(key: AppConstants.keyUsername);
    final dob = await _storage.read(key: AppConstants.keyDob);
    final idType = await _storage.read(key: AppConstants.keyIdType);
    final verificationDigits = await _storage.read(key: AppConstants.keyVerificationDigits);
    final semester = await _storage.read(key: AppConstants.keySemester);

    if (username == null || dob == null || idType == null || verificationDigits == null) {
      return null;
    }

    return {
      'username': username,
      'dob': dob,
      'idType': idType,
      'verificationDigits': verificationDigits,
      'semester': semester ?? 'even',
    };
  }

  Future<String?> getDob() async {
    return await _storage.read(key: AppConstants.keyDob);
  }

  Future<bool> isLoggedIn() async {
    final value = await _storage.read(key: AppConstants.keyIsLoggedIn);
    return value == 'true';
  }

  // Session
  Future<void> saveSessionCookie(String cookie) async {
    await _storage.write(key: AppConstants.keySessionCookie, value: cookie);
  }

  Future<String?> getSessionCookie() async {
    return await _storage.read(key: AppConstants.keySessionCookie);
  }

  // Theme
  Future<void> saveThemeMode(String mode) async {
    await _storage.write(key: AppConstants.keyThemeMode, value: mode);
  }

  Future<String?> getThemeMode() async {
    return await _storage.read(key: AppConstants.keyThemeMode);
  }

  // Clear all
  Future<void> clearAll() async {
    await _storage.deleteAll();
  }

  Future<void> clearSession() async {
    await _storage.delete(key: AppConstants.keySessionCookie);
  }
}
