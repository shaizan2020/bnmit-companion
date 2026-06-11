class AppException implements Exception {
  final String message;
  final String? code;
  AppException(this.message, {this.code});

  @override
  String toString() => 'AppException($code): $message';
}

class AuthException extends AppException {
  AuthException(super.message, {super.code});
}

class SessionExpiredException extends AuthException {
  SessionExpiredException() : super('Session expired. Please login again.', code: 'SESSION_EXPIRED');
}

class InvalidCredentialsException extends AuthException {
  InvalidCredentialsException() : super('Invalid USN or Date of Birth.', code: 'INVALID_CREDENTIALS');
}

class VerificationFailedException extends AuthException {
  VerificationFailedException() : super('Verification failed. Check your 4-digit code.', code: 'VERIFICATION_FAILED');
}

class ScrapingException extends AppException {
  ScrapingException(super.message, {super.code});
}

class NetworkException extends AppException {
  NetworkException(super.message, {super.code});
}

class NoInternetException extends NetworkException {
  NoInternetException() : super('No internet connection.', code: 'NO_INTERNET');
}
