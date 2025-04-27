import 'dart:convert';
import 'dart:io'; // For HttpClient and badCertificateCallback (if needed, use with caution)
import 'package:http/http.dart' as http;
import '../models/process_info.dart';

class ApiService {
  // Base URL (adjust if needed) - Note: Avoid hardcoding sensitive parts
  final String _baseUrl = "https://api.ecsc.gov.sy:8443"; 
  String? _authToken; // Store auth token if login provides one (adapt as needed)

  // --- IMPORTANT SECURITY NOTE ---
  // The Python code uses `verify=False`, which disables SSL verification.
  // Doing this in Flutter is generally NOT recommended. 
  // If the server has certificate issues, it's better to fix the server 
  // or use proper certificate pinning. Disabling verification globally is risky.
  // http.Client _createHttpClient() {
  //   // Example of how to bypass verification (USE WITH EXTREME CAUTION):
  //   HttpClient httpClient = HttpClient()
  //     ..badCertificateCallback =
  //         ((X509Certificate cert, String host, int port) => true);
  //   return http.IOClient(httpClient);
  // }
  // For this example, we'll use the default http client which performs verification.
  final http.Client _client = http.Client();

  // Generates basic headers, mimicking the Python script
  Map<String, String> _getHeaders({String? alias, bool includeAuth = false}) {
    final headers = {
      "User-Agent": "Mozilla/5.0 (Linux; Android 12; SM-G998B) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/102.0.5005.61 Mobile Safari/537.36", // Example UA
      "Host": "api.ecsc.gov.sy:8443",
      "Accept": "application/json, text/plain, */*",
      "Accept-Language": "ar,en-US;q=0.7,en;q=0.3",
      "Referer": "https://ecsc.gov.sy/", // Adjusted Referer
      "Content-Type": "application/json",
      "Source": "WEB", // Keep Source as WEB?
      "Origin": "https://ecsc.gov.sy",
      "Connection": "keep-alive",
      "Sec-Fetch-Dest": "empty",
      "Sec-Fetch-Mode": "cors",
      "Sec-Fetch-Site": "same-site",
      "Priority": "u=1", // May not be needed/settable in http package
    };
    if (alias != null) {
      headers["Alias"] = alias;
    }
    // Add Authorization header if we have a token (adjust based on actual API)
    if (includeAuth && _authToken != null) {
      headers['Authorization'] = 'Bearer $_authToken'; // Example: Bearer token
    }
    return headers;
  }

  // Login function
  Future<bool> login(String username, String password) async {
    final url = Uri.parse('$_baseUrl/secure/auth/login');
    try {
      final response = await _client.post(
        url,
        headers: _getHeaders(),
        body: jsonEncode({'username': username, 'password': password}),
      );

      if (response.statusCode == 200) {
        // Parse response if it contains a token or session info
        // Example: final data = jsonDecode(response.body);
        // _authToken = data['token']; // Store the token if provided
        print('Login successful for $username');
        return true;
      } else {
        print('Login failed for $username: ${response.statusCode} ${response.body}');
        _authToken = null; // Clear token on failure
        return false;
      }
    } catch (e) {
      print('Login error for $username: $e');
      _authToken = null;
      return false;
    }
  }

  // Fetch process IDs for a logged-in user
  Future<List<ProcessInfo>> fetchProcessIds(String username) async {
    // Note: The Python code uses 'P_USERNAME': 'WebSite'. Confirm if this is correct
    // or if the actual logged-in username should be used. Using 'WebSite' for now.
    final url = Uri.parse('$_baseUrl/dbm/db/execute');
    final payload = {
      "ALIAS": "OPkUVkYsyq",
      "P_USERNAME": "WebSite", // Or use the provided 'username'?
      "P_PAGE_INDEX": 0,
      "P_PAGE_SIZE": 100
    };

    try {
      // Assuming login sets _authToken if required
      final response = await _client.post(
        url,
        headers: _getHeaders(alias: "OPkUVkYsyq", includeAuth: true), // Include Auth if needed
        body: jsonEncode(payload),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List<dynamic>? results = data['P_RESULT'];
        if (results != null) {
          return results.map((json) => ProcessInfo.fromJson(json)).toList();
        } else {
          print('Fetch Process IDs: P_RESULT is null or not a list');
          return [];
        }
      } else {
        print('Fetch Process IDs failed: ${response.statusCode} ${response.body}');
        // Handle potential re-login if status is 401/403?
        return [];
      }
    } catch (e) {
      print('Error fetching Process IDs: $e');
      return [];
    }
  }

  // Get Captcha image data (Base64 string)
  Future<String?> getCaptcha(String processId) async {
    final url = Uri.parse('$_baseUrl/captcha/get/$processId');
    int retries = 0;
    const maxRetries = 5; // Limit retries for 429

    while (retries < maxRetries) {
       try {
         // Assuming login sets _authToken if required
        final response = await _client.get(
          url, 
          headers: _getHeaders(includeAuth: true) // Include Auth if needed
        );

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          // Expecting {"file": "data:image/gif;base64,..."}
          return data['file']; 
        } else if (response.statusCode == 429) {
          retries++;
          print('Captcha fetch rate limited (429), retrying ($retries/$maxRetries)...');
          await Future.delayed(const Duration(milliseconds: 200)); // Wait before retry
        } else if (response.statusCode == 401 || response.statusCode == 403) {
            print('Captcha fetch unauthorized (${response.statusCode}). Need re-login?');
            // Implement re-login logic if necessary here
            return null; // Indicate failure requiring re-auth
        } 
        else {
          print('Failed to get Captcha: ${response.statusCode} ${response.body}');
          return null;
        }
      } catch (e) {
        print('Error getting Captcha: $e');
        return null;
      }
    }
     print('Failed to get Captcha after $maxRetries retries (rate limited).');
    return null;
  }

  // Submit Captcha solution
  Future<Map<String, dynamic>> submitCaptcha(String processId, String solution) async {
    final url = Uri.parse('$_baseUrl/rs/reserve?id=$processId&captcha=$solution');
    try {
       // Assuming login sets _authToken if required
      final response = await _client.get(
        url, 
        headers: _getHeaders(includeAuth: true) // Include Auth if needed
      );
      
      // Try decoding JSON, otherwise return raw text
      dynamic responseBody;
      try {
        responseBody = jsonDecode(response.body);
      } catch (_) {
        responseBody = response.body; // Keep as text if not JSON
      }

      return {
        'statusCode': response.statusCode,
        'body': responseBody,
        'success': response.statusCode == 200,
      };
    } catch (e) {
      print('Error submitting Captcha: $e');
      return {
        'statusCode': -1, // Indicate connection error
        'body': 'Connection error: $e',
        'success': false,
      };
    }
  }
  
  // Dispose the client when the service is no longer needed
  void dispose() {
    _client.close();
  }
}
