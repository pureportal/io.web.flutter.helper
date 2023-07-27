import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:universal_html/html.dart' as html;
import 'package:http/http.dart' as http;
import 'dart:convert';

import 'package:url_launcher/url_launcher.dart';

class Global {
  // Generel
  static final Global _singleton = Global._();
  final Future<SharedPreferences> prefs = SharedPreferences.getInstance();
  ValueNotifier<String?> locale = ValueNotifier<String?>(null);
  ValueNotifier<String?> title = ValueNotifier<String?>("");
  ValueNotifier<bool> loaded = ValueNotifier<bool>(false);
  ValueNotifier<String?> theme = ValueNotifier<String?>(null);
  ValueNotifier<Map<String, dynamic>?> userData = ValueNotifier<Map<String, dynamic>?>(null);
  ValueNotifier<String?> viewAs = ValueNotifier<String?>(null);
  ValueNotifier<Map<String, dynamic>?> additionalData = ValueNotifier<Map<String, dynamic>?>({});
  List<String> _additionalDataPersistent = [];
  String? appName;
  String? packageName;
  String? version;
  String? buildNumber;

  // Reg Exp
  static final RegExp validatorDouble = RegExp(r"^(?:\ ?[0-9]\ ?)*[0-9]+(?:(?:\.|\,)[0-9]*)?$");
  static final RegExp validatorInt = RegExp(r"^(?:\ ?[0-9]\ ?)*[0-9]+$");
  static final RegExp validatorName = RegExp(r"^(?:\ ?[0-9]\ ?)*[0-9]+$");

  // Authorization
  final String oauthAuthorize = dotenv.env['OAUTH_AUTHORIZE'] ?? '';
  final String oauthToken = dotenv.env['OAUTH_TOKEN'] ?? '';
  final String oauthClientId = dotenv.env['OAUTH_CLIENT_ID'] ?? '';
  final String oauthScopes = dotenv.env['OAUTH_SCOPES'] ?? '';
  final String apiBackendUrl = dotenv.env['API_BACKEND'] ?? '';
  final String oauthLogout = dotenv.env['OAUTH_LOGOUT'] ?? '';
  final String redirectUrl = Uri.encodeComponent("${html.window.location.protocol}//${html.window.location.hostname}:${html.window.location.protocol == 'https:' ? '' : html.window.location.port}");
  bool refreshTokenOngoing = false;
  ValueNotifier<String?> refreshToken = ValueNotifier<String?>(null);
  ValueNotifier<String?> accessToken = ValueNotifier<String?>(null);
  ValueNotifier<bool?> showOAuthWebView = ValueNotifier<bool?>(null);
  ValueNotifier<bool?> showLoginPage = ValueNotifier<bool?>(null);
  ValueNotifier<bool?> waitForValidation = ValueNotifier<bool?>(null);
  ValueNotifier<bool?> unableToOpenValidationPort = ValueNotifier<bool?>(null);
  HttpServer? httpServer;

  // Dio
  final Dio dioSecuredApi = Dio(BaseOptions(connectTimeout: 5000, sendTimeout: 5000, receiveTimeout: 5000));

  // Constructor
  Global._() {
    prefs.then((SharedPreferences prefs) async {
      // Load locale
      this.locale.value = prefs.getString("LOCALE");

      // Load theme
      this.theme.value = prefs.getString("THEME");

      // If path is "logout" -> Remove tokens and redirect to homepage or redirect url
      if (html.window.location.pathname?.startsWith("/logout") ?? false) {
        this.logout();
      } else {
        // Check if URI contains an code
        String? code = Uri.base.queryParameters["code"];

        // If no code is provided, try to receive first access_token...
        if (code == null) {
          // Try to load JWT from storage
          setRefreshToken(prefs.getString("REFRESH_TOKEN"));
          setAccessToken(prefs.getString("ACCESS_TOKEN"));
          if ((refreshToken.value == null || refreshToken.value!.isEmpty) && (accessToken.value == null || accessToken.value!.isEmpty)) {
            redirectToLogin();
          } else if (refreshToken.value != null && refreshToken.value!.isNotEmpty && (accessToken.value == null || accessToken.value!.isEmpty)) {
            bool success = await refreshTokens();
            if (!success) {
              setRefreshToken(null);
              setAccessToken(null);
              redirectToLogin();
            } else {
              // Start next step -> Load user data
              await loadUserData();
            }
          } else {
            // Start next step -> Load user data
            await loadUserData();
          }
        }
        // ...else unset tokens, to receive a new refresh_token and access_token pair
        else {
          setRefreshToken(null);
          setAccessToken(null);
          tryToExchangeCodeForToken(code);
        }
      }

      // Load user data interval
      Timer.periodic(Duration(seconds: 10), (Timer t) async {
        await loadUserData();
      });

      // Load package info
      PackageInfo packageInfo = await PackageInfo.fromPlatform();
      appName = packageInfo.appName;
      packageName = packageInfo.packageName;
      version = packageInfo.version;
      buildNumber = packageInfo.buildNumber;

      // Set loaded to true
      loaded.value = true;
    });
  }

  // Functions
  static Global instance() {
    return _singleton;
  }

  void logout() {
    // Unset token
    setRefreshToken(null);
    setAccessToken(null);

    // Redirect to homepage
    if (!kIsWeb) {
      this.showLoginPage.value = true;
    } else {
      // Check if redirect url exists in environment as OAUTH_LOGOUT
      if (dotenv.env['OAUTH_LOGOUT'] != null && dotenv.env['OAUTH_LOGOUT'] != '') {
        html.window.location.href = dotenv.env['OAUTH_LOGOUT']!;
      } else {
        html.window.location.href = "https://beewatec.de";
      }
    }
  }

  Future<Response<dynamic>> retryDio(Dio dio, RequestOptions requestOptions) async {
    print('Retry path: ${requestOptions.path}');
    final Options options = Options(
      method: requestOptions.method,
      headers: requestOptions.headers,
    );
    options.headers!['Authorization'] = 'Bearer ${this.accessToken.value}';
    //isRetryCall = true;
    //return dio.request<dynamic>(requestOptions.path, data: requestOptions.data, queryParameters: requestOptions.queryParameters, options: options).whenComplete(() => isRetryCall = false);
    return dio.request<dynamic>(requestOptions.path, data: requestOptions.data, queryParameters: requestOptions.queryParameters, options: options);
  }

  void setRefreshToken(String? jwt) {
    if (kDebugMode) print("Refresh-Token: " + jwt.toString());

    // Set new refresh token
    prefs.then((SharedPreferences prefs) => jwt == null ? prefs.remove("REFRESH_TOKEN") : prefs.setString("REFRESH_TOKEN", jwt));
    this.refreshToken.value = jwt;

    // Check for permissions if access token exists
    //setInterceptor();
  }

  void setAccessToken(String? jwt) async {
    if (kDebugMode) print("Access-Token: " + jwt.toString());

    // Set new access token
    prefs.then((SharedPreferences prefs) => jwt == null ? prefs.remove("ACCESS_TOKEN") : prefs.setString("ACCESS_TOKEN", jwt));
    this.accessToken.value = jwt;

    // Set interceptor with new access token
    setInterceptor();
  }

  setInterceptor() {
    // Remove old interceptors
    if (dioSecuredApi.interceptors.length > 0) dioSecuredApi.interceptors.removeAt(0);

    // Set new interceptor
    print("Add dio interceptor");
    dioSecuredApi.interceptors.add(
      QueuedInterceptorsWrapper(
        onRequest: (RequestOptions options, RequestInterceptorHandler requestInterceptorHandler) async {
          // Add access token to header, if valid
          if (this.accessToken.value != null) {
            options.headers['Authorization'] = 'Bearer ${this.accessToken.value}';
          }

          // Add access token to header, if valid
          if (this.viewAs.value != null && this.userData.value?["is_admin"] == true) {
            options.headers['ViewAs'] = '${this.viewAs.value}';
          }

          // Set additional header informations
          options.headers['Accept'] = 'application/json';

          // Return new options
          requestInterceptorHandler.next(options);
        },
        onResponse: (Response response, ResponseInterceptorHandler responseInterceptorHandler) async {
          // Get the statu code
          /*final int statusCode = response.statusCode;
          var results = {};
          if (statusCode == 200 || statusCode == 201 || statusCode == 204) {
          final dynamic decodeResponse = this.decodeResponse(response);
          bool responseIsList = decodeResponse is List;

          if (!responseIsList && decodeResponse['token'] != null) {
            final token = decodeResponse['token'];
            //setAuthorizationToken(token['access_token'], token['refresh_token']);
          }

          if (responseIsList) {
            return decodeResponse;
          } else {
            final resultToAdd = decodeResponse;

            results.addAll(resultToAdd);

            return results;
          }
        }*/
          responseInterceptorHandler.next(response);
        },
        onError: (DioError error, ErrorInterceptorHandler errorInterceptorHandler) async {
          final response = error.response;
          if (response != null && response.statusCode == 401) {
            print("401 Error");

            // Try to get new access token
            bool success = await this.refreshTokens();

            if (success) {
              // Retry the last
              await retryDio(dioSecuredApi, response.requestOptions);
            } else {
              errorInterceptorHandler.reject(error);
            }
          }
          errorInterceptorHandler.reject(error);
        },
      ),
    );
  }

  Future<bool> refreshTokens() async {
    try {
      if (refreshTokenOngoing)
        return false;
      else
        refreshTokenOngoing = true;

      if (refreshToken.value == null) throw ("No refresh_token exists...");
      print("Try to exchange refresh_token for new access_token");
      final response = await http.post(Uri.parse("${Global.instance().oauthToken}"), headers: {"Content-Type": "application/json"}, body: jsonEncode({"grant_type": "refresh_token", "refresh_token": refreshToken.value}));
      if (response.statusCode == 200) {
        Map data = jsonDecode(response.body);
        if (data["success"] == true) {
          if (data.containsKey("access_token")) {
            data.containsKey("refresh_token") ? print("Access token AND refresh token received!") : print("Access token received!");
            if (data.containsKey("refresh_token")) Global.instance().setRefreshToken(data["refresh_token"]);
            Global.instance().setAccessToken(data["access_token"]);
            return true;
          } else {
            throw ("Internal error: Invalid response from server");
          }
        } else {
          throw ("Server reply: ${data["message"]}; Error Code: ${data["error_code"]};");
        }
      } else if (response.statusCode == 401) {
        throw ("Unauthorized - Redirect to login form");
      } else {
        throw ("Invalid status code: " + response.statusCode.toString());
      }
    } catch (error) {
      print(error);
      redirectToLogin();
      return false;
    } finally {
      refreshTokenOngoing = false;
    }
  }

  Future<bool> tryToExchangeCodeForToken(String code) async {
    try {
      print("Try to exchange code for token using: ${Global.instance().oauthToken}");
      final response = await http.post(Uri.parse("${Global.instance().oauthToken}"), headers: {"Content-Type": "application/json"}, body: jsonEncode({"code": code}));
      if (response.statusCode == 200) {
        Map data = jsonDecode(response.body);
        if (data["success"] == true) {
          if (data.containsKey("refresh_token") || data.containsKey("access_token")) {
            print("Yeah. refresh_token and access_token received!");

            // Save refresh_token and access_token
            Global.instance().setRefreshToken(data["refresh_token"]);
            Global.instance().setAccessToken(data["access_token"]);

            // Redirect to URL without code in URL
            //window.top.location.href = '/' + window.location.pathname;
            if (kIsWeb) {
              html.window.top?.location.href = '/';
            }

            return true;
          } else {
            throw ("Internal error: Invalid response from server");
          }
        } else {
          throw ("Server reply: ${data["message"]}; Error Code: ${data["error_code"]};");
        }
      } else {
        throw ("Invalid status code: " + response.statusCode.toString());
      }
    } catch (error) {
      print(error);
      redirectToLogin();
    }
    return true;
  }

  Future verifyJWT() async {
    /*try {
      final response = await http.post("${window.location.protocol}//${window.location.hostname}:${window.location.protocol == 'https:' ? '' : 8080}/api/verify-jwt", body: {"token": this.jwt.value});
      if (response.statusCode == 200) {
        Map data = jsonDecode(response.body);
        if (data!["result"] == "success") {
          this.jwtValidated.value = true;
        } else {
          throw ("Server reply: Invalid JWT");
        }
      } else {
        throw ("Invalid status code");
      }
    } catch (error) {
      print("Failed to verify token:" + error.toString());
      setJwt(null);
    }*/
  }

  Future loadUserData() async {
    try {
      print("ASDASDSD");
      final response = await Global.instance().dioSecuredApi.get("$apiBackendUrl/users/me");
      if (response.statusCode == 200) {
        Map data = response.data;
        if (data["success"] == true) {
          this.userData.value = data["data"];
          print("User data loaded");
        } else {
          throw ("Server reply: Invalid JWT");
        }
      } else {
        throw ("Invalid status code");
      }
    } catch (error) {
      print("Failed to load user data:" + error.toString());
    }
  }

  void setAdditionalData(String namespace, dynamic data) async {
    this.additionalData.value![namespace] = data;
    // ignore: invalid_use_of_visible_for_testing_member, invalid_use_of_protected_member
    this.additionalData.notifyListeners();

    // Save to preferences if in persistent list
    if (_additionalDataPersistent.contains(namespace)) {
      print("Saving additional data to preferences");
      // Load persistent data
      await prefs.then((SharedPreferences prefs) {
        Map<String, dynamic> savedData = {};
        // Check if additional data is saved in preferences
        if (prefs.containsKey("additionalData")) {
          savedData = jsonDecode(prefs.getString("additionalData")!);
        }
        savedData[namespace] = data;
        prefs.setString("additionalData", jsonEncode(savedData));
      });
    }
  }

  void removeAdditionalData(String namespace) async {
    this.additionalData.value!.remove(namespace);
    // ignore: invalid_use_of_visible_for_testing_member, invalid_use_of_protected_member
    this.additionalData.notifyListeners();

    // Save to preferences if in persistent list
    if (_additionalDataPersistent.contains(namespace)) {
      print("Saving additional data to preferences");
      // Load persistent data
      await prefs.then((SharedPreferences prefs) {
        Map<String, dynamic> savedData = {};
        // Check if additional data is saved in preferences
        if (prefs.containsKey("additionalData")) {
          savedData = jsonDecode(prefs.getString("additionalData")!);
        }
        savedData.remove(namespace);
        prefs.setString("additionalData", jsonEncode(savedData));
      });
    }
  }

  dynamic getAdditionalData(String namespace, dynamic fallback) {
    // Check if namespace exists
    if (this.additionalData.value!.containsKey(namespace)) {
      return this.additionalData.value![namespace];
    } else {
      return fallback;
    }
  }

  void setAdditionalDataPersistent(List<String> namespaces) {
    this._additionalDataPersistent = namespaces;

    // Load persistent data
    prefs.then((SharedPreferences prefs) {
      // Check if additional data is saved in preferences
      if (prefs.containsKey("additionalData")) {
        Map<String, dynamic> data = jsonDecode(prefs.getString("additionalData")!);
        for (String namespace in namespaces) {
          if (data.containsKey(namespace)) {
            this.additionalData.value![namespace] = data[namespace];
          }
        }
      }
    });
  }

  void redirectToLogin() async {
    if (!kIsWeb) {
      try {
        this.httpServer = await HttpServer.bind(InternetAddress.anyIPv4, 34450);
        this.httpServer?.listen((HttpRequest request) async {
          await tryToExchangeCodeForToken(request.requestedUri.queryParameters["code"] ?? '');
          request.response.write('Hello, world!');
          request.response.close();
          this.showOAuthWebView.value = true;
        });
        if (Platform.isAndroid || Platform.isIOS) {
          this.showOAuthWebView.value = true;
        } else {
          launch("${Global.instance().oauthAuthorize}?client_id=${Uri.encodeComponent(oauthClientId)}&redirect_uri=${Uri.encodeComponent('http://localhost:34450')}&response_type=code");
        }
        this.unableToOpenValidationPort.value = false;
      } catch (e) {
        this.unableToOpenValidationPort.value = true;
      }
    } else {
      print("Redirect to OAuth-Server: " + Global.instance().oauthAuthorize);
      print(oauthClientId);
      //html.window.location.href = "${Global.instance().oauthAuthorize}";
      html.window.location.href = "${Global.instance().oauthAuthorize}?client_id=${Uri.encodeComponent(oauthClientId)}&redirect_uri=$redirectUrl&response_type=code&scope=${Uri.encodeComponent(oauthScopes)}";
    }
  }

  void changeTitle(String title) {
    this.title.value = title;
  }

  void changeLocale(String? locale) {
    prefs.then((SharedPreferences prefs) => locale == null ? prefs.remove("LOCALE") : prefs.setString("LOCALE", locale));
    this.locale.value = locale;
  }

  void changeTheme(String? theme) {
    print(theme);
    if (theme != null && theme != "dark" && theme != "light") return;
    prefs.then((SharedPreferences prefs) => theme == null ? prefs.remove("THEME") : prefs.setString("THEME", theme));
    this.theme.value = theme;
  }

  String getRandomLoadingScreenMessage() {
    switch (new Random().nextInt(4) + 1) {
      case 1:
        return "Locating the required gigapixels to render...";
      case 2:
        return "Shovelling coal into the server...";
      case 3:
        return "Warming up the processors...";
      case 4:
        return "Reconfiguring the office coffee machine...";
      case 5:
        return "So, do you come here often?";
    }
    return "";
  }

  static String intToString(int value) {
    return value.toString();
  }

  static String? doubleToString(var value, {int precision = 2}) {
    if (value == null) return null;
    if (value is String) value = double.parse(value);
    if (!(value is double)) return null;

    String? locale = Global.instance().locale.value;
    if (locale == null || locale == "en") {
      return value.toStringAsFixed(precision);
    } else if (locale == "de") {
      return value.toStringAsFixed(precision).replaceAll(".", ",");
    } else {
      return value.toStringAsFixed(precision);
    }
  }

  static String secondsToTimeFormat(int seconds, {bool showSeconds = true}) {
    var _hours = (seconds / 3600).floor();
    var _minutes = ((seconds - (_hours * 3600)) / 60).floor();
    var _seconds = seconds - (_hours * 3600) - (_minutes * 60);

    return "${_hours < 10 ? "0$_hours" : _hours}:${_minutes < 10 ? "0$_minutes" : _minutes}${showSeconds ? ":${_seconds < 10 ? "0$_seconds" : _seconds}" : ""}";
  }

  static timeOverlap(int start1, int end1, int start2, int end2) {
    return ((start1) < (end2) && (start2) < (end1) ? true : false);
  }
}
