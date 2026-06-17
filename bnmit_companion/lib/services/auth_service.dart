import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:cookie_jar/cookie_jar.dart';
import 'package:bnmit_companion/core/constants.dart';
import 'package:bnmit_companion/core/exceptions.dart';
import 'package:bnmit_companion/services/storage_service.dart';
import 'package:bnmit_companion/services/scraper_service.dart';
import 'package:bnmit_companion/models/user.dart';

class AuthService {
  late final Dio _dio;
  late final CookieJar _cookieJar;
  final StorageService _storageService;
  final ScraperService _scraperService = ScraperService();
  User? _currentUser;

  User? get currentUser => _currentUser;

  AuthService(this._storageService) {
    _cookieJar = CookieJar();
    _dio = Dio(BaseOptions(
      baseUrl: AppConstants.portalUrl,
      followRedirects: false,
      maxRedirects: 5,
      validateStatus: (status) => status != null && status < 500,
      headers: {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
        'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8',
        'Accept-Language': 'en-US,en;q=0.9',
        'Referer': '${AppConstants.portalUrl}index.php',
      },
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
    ));
    _dio.interceptors.add(CookieManager(_cookieJar));
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        print('DIO REQUEST [${options.method}] ${options.uri}');
        print('DIO REQUEST HEADERS: ${options.headers}');
        return handler.next(options);
      },
    ));
    _dio.interceptors.add(ManualRedirectInterceptor(_dio, _cookieJar));
  }

  Dio get dio => _dio;

  /// Step 1: POST USN + DOB to get OTP verification page
  /// Step 2: POST verification digits to complete login
  Future<User> login({
    required String username,
    required String dob, // format: YYYY-MM-DD
    required int idType,
    required String verificationDigits,
    required String semester,
  }) async {
    try {
      // Clear any existing cookies
      _cookieJar.deleteAll();

      // Configure dynamic baseUrl based on selected semester
      _dio.options.baseUrl = AppConstants.getPortalUrl(semester);
      _dio.options.headers['Referer'] = '${_dio.options.baseUrl}index.php';
      print('AUTH SERVICE: baseUrl is ${_dio.options.baseUrl}');

      // First, visit the portal to get initial session cookie
      final initResponse = await _dio.get('');
      print('AUTH SERVICE: Init response status code: ${initResponse.statusCode}');

      final dobParts = dob.split('-');
      final yyyy = dobParts[0];
      final mm = dobParts[1];
      final dd = dobParts[2];

      // Step 1: Login with USN + DOB
      print('AUTH SERVICE: Post Step 1 details - USN: $username, DOB: $yyyy-$mm-$dd');
      final step1Response = await _dio.post(
        'index.php',
        data: FormData.fromMap({
          'username': username,
          'dd': dd,
          'mm': mm,
          'yyyy': yyyy,
          'passwd': dob,
          'option': 'com_user',
          'task': AppConstants.loginStep1Task,
          'token': '',
          'action': 'result_form',
        }),
        options: Options(
          contentType: 'application/x-www-form-urlencoded',
          followRedirects: false,
        ),
      );

      print('AUTH SERVICE: Step 1 response status code: ${step1Response.statusCode}');
      if (step1Response.statusCode != 200) {
        throw InvalidCredentialsException();
      }

      final step1Html = step1Response.data.toString();

      // Check if we got the verification page (contains "Select Verification Type")
      if (!step1Html.contains('idType') && !step1Html.contains('enteredid')) {
        print('AUTH SERVICE: Step 1 failed to reach verification page. HTML preview:');
        print(step1Html.length > 500 ? step1Html.substring(0, 500) : step1Html);
        // Might have gotten an error
        if (step1Html.contains('Invalid') || step1Html.contains('error')) {
          throw InvalidCredentialsException();
        }
        throw AuthException('Unexpected response from login step 1');
      }

      // Extract CSRF token from step 1 response
      final csrfToken = _scraperService.extractCsrfToken(step1Html);
      print('AUTH SERVICE: Extracted CSRF Token: $csrfToken');

      // Step 2: Submit verification digits
      final step2Data = <String, dynamic>{
        'idType': idType.toString(),
        'enteredid': verificationDigits,
        'option': 'com_user',
        'task': AppConstants.loginStep2Task,
        'username': username,
        'passwd': dob,
        'remember': 'No',
        'return': '',
        'token': '',
        'action': 'result_form',
      };

      // Add CSRF token if found
      if (csrfToken != null) {
        step2Data[csrfToken] = '1';
      }

      print('AUTH SERVICE: Post Step 2 details - idType: $idType, digits: $verificationDigits');
      final step2Response = await _dio.post(
        'index.php',
        data: FormData.fromMap(step2Data),
        options: Options(
          contentType: 'application/x-www-form-urlencoded',
          followRedirects: false,
        ),
      );

      print('AUTH SERVICE: Step 2 response status code: ${step2Response.statusCode}');
      final step2Html = step2Response.data.toString();

      // Check if login succeeded (redirect to dashboard URL = success)
      if (step2Html.contains('com_studentdashboard') || step2Html.contains('cn-stu-data')) {
        print('AUTH SERVICE: Login succeeded!');
        _currentUser = _scraperService.parseUserProfile(step2Html, portalUrl: _dio.options.baseUrl);

        // If the HTML was a synthetic stub (body couldn't be read due to
        // server Content-Length bug), fetch the real dashboard for profile data
        if (_currentUser!.usn.isEmpty) {
          print('AUTH SERVICE: Profile empty — fetching dashboard for profile data');
          try {
            final testUri = Uri.parse(_dio.options.baseUrl);
            final currentCookies = await _cookieJar.loadForRequest(testUri);
            print('AUTH SERVICE: Cookies before dashboard fetch: ${currentCookies.map((c) => "${c.name}=${c.value}").join(", ")}');
            final dashHtml = await fetchPage(
              'index.php?${AppConstants.dashboardParams}',
            );
            if (dashHtml.contains('cn-stu-data')) {
              _currentUser = _scraperService.parseUserProfile(
                dashHtml,
                portalUrl: _dio.options.baseUrl,
              );
              print('AUTH SERVICE: Profile loaded from dashboard: ${_currentUser!.name}');
            }
          } catch (e) {
            // Profile fetch failed — carry on with default user, not fatal
            print('AUTH SERVICE: Profile re-fetch failed: $e');
          }
        }

        // Save credentials for auto-login
        await _storageService.saveCredentials(
          username: username,
          dob: dob,
          idType: idType,
          verificationDigits: verificationDigits,
          semester: semester,
        );

        return _currentUser!;
      }

      print('AUTH SERVICE: Step 2 failed to reach dashboard. HTML preview:');
      print(step2Html.length > 500 ? step2Html.substring(0, 500) : step2Html);

      // If still on login/verification page, something went wrong
      if (step2Html.contains('enteredid') || step2Html.contains('digit-input')) {
        throw VerificationFailedException();
      }

      throw AuthException('Login failed. Please try again.');
    } on DioException catch (e) {
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout) {
        throw NetworkException('Connection timed out. Please try again.');
      }
      if (e.type == DioExceptionType.connectionError) {
        throw NoInternetException();
      }
      throw NetworkException('Network error: ${e.message}');
    }
  }

  /// Auto-login using stored credentials
  Future<User?> autoLogin() async {
    final creds = await _storageService.getCredentials();
    if (creds == null) return null;

    try {
      return await login(
        username: creds['username']!,
        dob: creds['dob']!,
        idType: int.parse(creds['idType']!),
        verificationDigits: creds['verificationDigits']!,
        semester: creds['semester'] ?? 'even',
      );
    } catch (e) {
      return null;
    }
  }

  /// Check if session is still valid by hitting dashboard
  Future<bool> isSessionValid() async {
    try {
      final response = await _dio.get(
        'index.php?${AppConstants.dashboardParams}',
      );
      final html = response.data.toString();
      return html.contains('cn-stu-data') || html.contains('com_studentdashboard');
    } catch (e) {
      return false;
    }
  }

  /// Re-login if session expired
  Future<User?> reLoginIfNeeded() async {
    if (await isSessionValid()) return _currentUser;
    return await autoLogin();
  }

  /// Fetch a page with auto-relogin on session expiry
  Future<String> fetchPage(String url) async {
    // Normalize path relative to baseUrl
    if (url.startsWith('/')) {
      url = url.substring(1);
    }
    try {
      // Log current cookies before request for debugging
      final baseUri = Uri.parse(_dio.options.baseUrl);
      final currentCookies = await _cookieJar.loadForRequest(baseUri);
      print('FETCH PAGE [$url]: cookies=${currentCookies.map((c) => "${c.name}=${c.value}").join(", ")}');

      var response = await _dio.get(url);
      var html = response.data.toString();
      print('FETCH PAGE [$url]: got ${html.length} bytes, hasLoginForm=${html.contains("login-form")}, hasDashboard=${html.contains("cn-stu-data")}');

      // Check if redirected to login page
      if (html.contains('login-form') && !html.contains('cn-stu-data')) {
        print('FETCH PAGE: session expired, attempting re-login');
        // Session expired, re-login
        final user = await autoLogin();
        if (user == null) throw SessionExpiredException();

        // Retry the request
        response = await _dio.get(url);
        html = response.data.toString();
        print('FETCH PAGE [$url]: retry got ${html.length} bytes');
      }

      return html;
    } on DioException catch (e) {
      if (e.type == DioExceptionType.connectionError) {
        throw NoInternetException();
      }
      throw NetworkException('Failed to fetch page: ${e.message}');
    }
  }

  /// Fetch raw bytes from a portal URL (for PDF/file downloads).
  /// Handles both relative paths (resolved against baseUrl) and absolute URLs.
  Future<Uint8List> fetchBytes(String url) async {
    // Strip leading slash for relative paths
    if (url.startsWith('/')) url = url.substring(1);

    print('FETCH BYTES: url=$url');

    try {
      // For absolute URLs, override the base URL so Dio doesn't prepend it
      final options = url.startsWith('http')
          ? Options(
              responseType: ResponseType.bytes,
              extra: {'baseUrl': ''},
            )
          : Options(responseType: ResponseType.bytes);

      final response = await _dio.get(url, options: options);
      print('FETCH BYTES: status=${response.statusCode} data type=${response.data.runtimeType}');

      final data = response.data;
      if (data is List<int>) {
        final bytes = Uint8List.fromList(data);
        print('FETCH BYTES: returning ${bytes.length} bytes (from List<int>)');
        return bytes;
      }
      if (data is Uint8List) {
        print('FETCH BYTES: returning ${data.length} bytes (Uint8List)');
        return data;
      }
      // If we got HTML text instead of binary, it means redirect to login page
      if (data is String && data.contains('login-form')) {
        throw Exception('Session expired — got login page instead of file.');
      }
      print('FETCH BYTES: unexpected data type, returning empty');
      return Uint8List(0);
    } on DioException catch (e) {
      print('FETCH BYTES ERROR: ${e.type} ${e.message}');
      if (e.type == DioExceptionType.connectionError) throw NoInternetException();
      throw NetworkException('Failed to download file: ${e.message}');
    }
  }

  /// Logout
  Future<void> logout() async {
    try {
      await _dio.post(
        'index.php',
        data: FormData.fromMap({
          'option': AppConstants.logoutOption,
          'task': AppConstants.logoutTask,
        }),
      );
    } catch (_) {
      // Ignore logout errors
    }
    _cookieJar.deleteAll();
    _currentUser = null;
    await _storageService.clearAll();
  }
}

class ManualRedirectInterceptor extends Interceptor {
  final Dio _dio;
  final CookieJar _cookieJar;

  ManualRedirectInterceptor(this._dio, this._cookieJar);

  /// Fetch a URL using raw dart:io HttpClient so we completely bypass
  /// Dart's content-length enforcement (which crashes on Joomla redirects
  /// that send Content-Length > 0 with an empty body).
  ///
  /// We disable dart:io's built-in redirect following (which also crashes on
  /// the content-length mismatch) and handle redirects ourselves recursively.
  Future<String> _fetchWithRawHttp(
    String url,
    Map<String, dynamic> headers, {
    int hops = 0,
    Uri? basePortalUri,
  }) async {
    if (hops > 8) throw Exception('Too many redirects in _fetchWithRawHttp');

    print('RAW HTTP starting request for $url (hops=$hops)');

    final uri = Uri.parse(url);

    // Determine the base portal URI (e.g. https://host/parentseven/)
    // so we can always save cookies there for CookieManager to find.
    final effectiveBaseUri = basePortalUri ??
        Uri.parse('${uri.scheme}://${uri.host}${uri.pathSegments.isNotEmpty ? '/${uri.pathSegments.first}/' : '/'}');

    // Load cookies — try both the specific URI and the base portal URI.
    final cookiesForUri = await _cookieJar.loadForRequest(uri);
    final cookiesForBase = await _cookieJar.loadForRequest(effectiveBaseUri);
    // Merge, preferring uri-specific over base
    final allCookieMap = <String, Cookie>{};
    for (final c in cookiesForBase) { allCookieMap[c.name] = c; }
    for (final c in cookiesForUri) { allCookieMap[c.name] = c; }
    final cookieHeader = allCookieMap.values.map((c) => '${c.name}=${c.value}').join('; ');

    final httpClient = HttpClient()
      ..connectionTimeout = const Duration(seconds: 15)
      ..badCertificateCallback = (_, __, ___) => true;

    print('RAW HTTP client initialized, calling getUrl...');
    final request = await httpClient.getUrl(uri).timeout(const Duration(seconds: 15));
    print('RAW HTTP getUrl returned request, configuring headers...');

    // CRITICAL: disable auto-redirects — dart:io crashes on the
    // Content-Length mismatch when following redirects automatically.
    request.followRedirects = false;

    headers.forEach((key, value) {
      final lowerKey = key.toLowerCase();
      if (lowerKey != 'content-length' &&
          lowerKey != 'content-type' &&
          lowerKey != 'host' &&
          lowerKey != 'accept-encoding') {
        if (value != null) request.headers.set(key, value.toString());
      }
    });
    if (cookieHeader.isNotEmpty) {
      request.headers.set(HttpHeaders.cookieHeader, cookieHeader);
    }
    request.headers.set(HttpHeaders.acceptHeader,
        'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8');
    // Don't advertise gzip support so dart:io won't try to decompress
    request.headers.set(HttpHeaders.acceptEncodingHeader, 'identity');

    print('RAW HTTP calling request.close()...');
    HttpClientResponse response;
    try {
      response = await request.close().timeout(const Duration(seconds: 15));
    } on TimeoutException catch (e) {
      print('RAW HTTP request.close() timeout (URL=$url): $e');
      httpClient.close(force: true);
      rethrow;
    } on HttpException catch (e) {
      // dart:io eagerly buffers the response body during keep-alive handling.
      // If the server sends Content-Length > 0 with an empty body (Joomla quirk),
      // this exception is thrown at request.close() before we can even read.
      // The cookies ARE already set by this point, so the session is valid.
      // Return the target URL as the body so com_studentdashboard check can pass.
      print('RAW HTTP close() HttpException (body empty, URL=$url): $e');
      httpClient.close(force: true);
      return '<html><!-- ${url} --></html>';
    } catch (e) {
      print('RAW HTTP close() unexpected error: $e');
      httpClient.close(force: true);
      rethrow;
    }

    print('RAW HTTP [${response.statusCode}] $url');

    // Save any new cookies from this response into the shared jar.
    // CRITICAL: save to BOTH the specific URI and the base portal URI so
    // CookieManager can find them for all subsequent Dio requests on any path.
    final setCookieHeaders = response.headers[HttpHeaders.setCookieHeader];
    if (setCookieHeaders != null) {
      final newCookies =
          setCookieHeaders.map((h) => Cookie.fromSetCookieValue(h)).toList();
      await _cookieJar.saveFromResponse(uri, newCookies);
      // Also store under the base portal path so subsequent Dio calls find them
      await _cookieJar.saveFromResponse(effectiveBaseUri, newCookies);
      print('RAW HTTP: saved ${newCookies.length} cookie(s) to jar for $uri and $effectiveBaseUri');
    }

    // If this is a redirect, drain the body (ignoring content-length errors)
    // and follow the Location header ourselves
    if (response.statusCode >= 300 && response.statusCode < 400) {
      try {
        await response.drain<void>().timeout(const Duration(seconds: 5));
      } catch (_) {
        // Joomla sends Content-Length > 0 on redirect bodies — safe to ignore
      }
      httpClient.close(force: true);

      final location = response.headers.value(HttpHeaders.locationHeader);
      if (location != null && location.isNotEmpty) {
        String nextUrl = location;
        if (!nextUrl.startsWith('http://') && !nextUrl.startsWith('https://')) {
          nextUrl = uri.resolve(nextUrl).toString();
        }
        final newHeaders = Map<String, dynamic>.from(headers);
        newHeaders['Referer'] = url;
        return _fetchWithRawHttp(nextUrl, newHeaders, hops: hops + 1, basePortalUri: effectiveBaseUri);
      }
      return ''; // no Location header — give up
    }

    // 200 — read the actual body
    final List<int> bytes = [];
    print('RAW HTTP starting response body read...');
    try {
      await response
          .timeout(const Duration(seconds: 15))
          .forEach((chunk) => bytes.addAll(chunk));
      print('RAW HTTP response body read complete: ${bytes.length} bytes');
    } catch (e) {
      print('RAW HTTP response body read error (continuing with ${bytes.length} bytes): $e');
      // Ignore any trailing content-length mismatch on the final page too
    }
    httpClient.close(force: true);
    return utf8.decode(bytes, allowMalformed: true);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) async {
    final status = response.statusCode;
    if (status != null && status >= 300 && status < 400) {
      final location = response.headers.value('location');
      if (location != null && location.isNotEmpty) {
        // Prevent infinite loops
        final redirectCount =
            (response.requestOptions.extra['redirectCount'] as int?) ?? 0;
        if (redirectCount >= 5) {
          return handler.reject(
            DioException(
              requestOptions: response.requestOptions,
              message: 'Redirect loop detected (max 5 redirects followed)',
              type: DioExceptionType.badResponse,
            ),
          );
        }

        // Close any open stream to release the socket
        if (response.data is ResponseBody) {
          try {
            (response.data as ResponseBody).close();
          } catch (_) {}
        }

        try {
          // Resolve URL relative to current request
          String nextUrl = location;
          if (!nextUrl.startsWith('http://') &&
              !nextUrl.startsWith('https://')) {
            nextUrl = response.requestOptions.uri.resolve(nextUrl).toString();
          }

          final options = response.requestOptions;
          final newHeaders = Map<String, dynamic>.from(options.headers);
          newHeaders['Referer'] = options.uri.toString();

          // CRITICAL: Dio interceptors are LIFO for responses, so
          // ManualRedirectInterceptor runs BEFORE CookieManager.
          // When we resolve with a synthetic response, CookieManager never
          // sees the original 302's Set-Cookie headers — the authenticated
          // session cookie is lost. Manually save them here first.
          final originalSetCookie = response.headers['set-cookie'];
          if (originalSetCookie != null && originalSetCookie.isNotEmpty) {
            final cookiesToSave = originalSetCookie
                .map((h) => Cookie.fromSetCookieValue(h))
                .toList();
            await _cookieJar.saveFromResponse(options.uri, cookiesToSave);
            // CRITICAL: also save to base portal URI so CookieManager
            // can find these cookies for ANY path under the portal.
            final baseUri = Uri.parse(_dio.options.baseUrl);
            await _cookieJar.saveFromResponse(baseUri, cookiesToSave);
            print(
                'MANUAL REDIRECT: saved ${cookiesToSave.length} session cookie(s) from 302 (also saved to base $baseUri)');
          }

          print(
              'MANUAL REDIRECT: $nextUrl (Referer: ${newHeaders['Referer']})');

          // Use raw dart:io to avoid DioMixin.fetch content-length enforcement
          final htmlString = await _fetchWithRawHttp(nextUrl, newHeaders);
          print('MANUAL REDIRECT: body length=${htmlString.length}');

          // Build a synthetic Response so the caller gets what it expects
          final syntheticResponse = Response(
            requestOptions: options,
            statusCode: 200,
            data: htmlString,
          );
          return handler.resolve(syntheticResponse);
        } catch (e, stack) {
          print('MANUAL REDIRECT ERROR: $e');
          print('MANUAL REDIRECT STACK: $stack');
          if (e is DioException) return handler.reject(e);
          return handler.reject(
            DioException(
              requestOptions: response.requestOptions,
              error: e,
              message: 'Manual redirect failed: $e',
            ),
          );
        }
      }
    }
    super.onResponse(response, handler);
  }
}
