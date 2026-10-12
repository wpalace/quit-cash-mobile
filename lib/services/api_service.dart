import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Single source of truth for the API base URL (D-11): the port the API
/// already listens on (8080). The old per-platform `_baseUrl` hardcodes —
/// including the `8084` port bug — are gone; there is now one source for the
/// URL. The host is the local/dev default (127.0.0.1); per-platform dev hosts
/// (Android emulator, iOS simulator) live in [_cloudDevTargets] below.
const String apiBaseUrl = 'http://127.0.0.1:8080';

/// Per-platform dev targets (D-12). This const map lives exclusively in the
/// cloud branch — [ApiService] is imported only by [CloudSavingsRepository] —
/// so it and all the base-URL logic are tree-shaken out of the local AOT
/// binary. Only the HOST varies for local development (Android emulator reaches
/// the host machine via 10.0.2.2; iOS simulator via localhost); the port is
/// always 8080 (from [apiBaseUrl]).
const Map<TargetPlatform, String> _cloudDevTargets = {
  TargetPlatform.android: 'http://10.0.2.2:8080',
  TargetPlatform.iOS: 'http://localhost:8080',
};

/// HTTP service for the **cloud** configuration. Reachable only from the cloud
/// branch ([CloudSavingsRepository]); the local branch never instantiates it
/// (D-10). The cloud bug fixes (secrets CLO-02, exposure CLO-03) are Phase 2.
class ApiService {
  // Resolve the effective base URL once for this platform: a per-platform dev
  // target if present, else the single source at 8080 (D-12, D-11).
  final String _baseUrl = _cloudDevTargets[defaultTargetPlatform] ?? apiBaseUrl;

  Future<double> getTotalSavings() async {
    final uri = Uri.parse('$_baseUrl/total-savings');
    final response = await http.get(uri);
    if (!await _validateResponse(response)) {
      throw Exception('Failed to retrieve total savings');
    }
    final data = jsonDecode(response.body);
    return data['total_savings'];
  }

  Future<void> addSaving(double amount) async {
    final uri = Uri.parse('$_baseUrl/add-saving');
    final response = await http.post(
      uri,
      body: jsonEncode({'amount': amount}),
      headers: {'Content-Type': 'application/json'},
    );
    if (!await _validateResponse(response)) {
      throw Exception('Failed to add saving');
    }
  }

  Future<bool> _validateResponse(http.Response response) async {
    // http 1.x exposes `statusCode` as a plain int (no HttpStatus enum).
    return response.statusCode == 200;
  }
}
