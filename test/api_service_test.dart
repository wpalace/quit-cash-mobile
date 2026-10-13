// Phase 2 (02-01 Task 3): unit tests for the cloud HTTP client, against a
// mocked HTTP client (no emulator / local k8s stack required).
//
// These tests pin the client to the real API contract (D-17/D-18, CLO-01):
//   - GET  {base}/api/savings/total -> camelCase `total` (double)
//   - POST {base}/api/savings        -> {'amount': n, 'userId': 'mobile-user'}
//   - 2xx (incl. 201 Created) is success; non-2xx throws (D-20).
//
// The base URL is platform-selected at compile time (D-12): on an Android
// test target it is http://10.0.2.2:8080, on Linux http://127.0.0.1:8080.
// These tests assert on the request METHOD and PATH (port- and host-agnostic),
// so they pass on any test target.
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/src/mock_client.dart'; // http.MockClient

import '../lib/services/api_service.dart';

void main() {
  group('ApiService (02-01, CLO-01 cloud contract)', () {
    test(
        'getTotalSavings targets GET /api/savings/total and returns '
        'camelCase total as a double (D-17, CLO-01)',
        () async {
      final calls = <http.Request>[];
      final client = MockClient((http.Request request) async {
        calls.add(request);
        final isTotalGet =
            request.method == 'GET' &&
            request.url.path == '/api/savings/total';
        return http.Response(
          isTotalGet ? '{"total": 12.5}' : '{}',
          200,
          request: request,
          headers: {'content-type': 'application/json'},
        );
      });
      final api = ApiService(client: client);
      final total = await api.getTotalSavings();
      expect(calls.length, 1);
      final r = calls.first;
      expect(r.method, 'GET');
      expect(r.url.path, '/api/savings/total');
      expect(total, 12.5);
    });

    test(
        'getTotalSavings coerces an integral total to a double (D-17)',
        () async {
      final client = MockClient((http.Request request) async {
        return http.Response(
          request.method == 'GET' ? '{"total": 3}' : '{}',
          200,
          request: request,
          headers: {'content-type': 'application/json'},
        );
      });
      final api = ApiService(client: client);
      expect(await api.getTotalSavings(), 3.0);
    });

    test(
        'getTotalSavings throws when 200 body lacks a numeric total (D-20)',
        () async {
      final client = MockClient((http.Request request) async {
        return http.Response(
          '{"other": 1}',
          200,
          request: request,
          headers: {'content-type': 'application/json'},
        );
      });
      final api = ApiService(client: client);
      await expectLater(api.getTotalSavings(), throwsA(isA<Exception>()));
    });

    test('getTotalSavings throws on a non-2xx total (D-20)', () async {
      final client = MockClient((http.Request request) async {
        return http.Response(
          '{"total": 0}',
          500,
          request: request,
          headers: {'content-type': 'application/json'},
        );
      });
      final api = ApiService(client: client);
      await expectLater(api.getTotalSavings(), throwsA(isA<Exception>()));
    });

    test(
        'addSaving POSTs /api/savings with {amount, userId: mobile-user} and '
        'accepts a 201 Created response (D-18, CLO-01)',
        () async {
      http.Request? captured;
      final client = MockClient((http.Request request) async {
        captured = request;
        return http.Response(
          '{"id": 1}',
          201, // ASP.NET CreatedAtAction -> 201
          request: request,
          headers: {'content-type': 'application/json'},
        );
      });
      final api = ApiService(client: client);
      await api.addSaving(5.00);
      expect(captured!.method, 'POST');
      expect(captured!.url.path, '/api/savings');
      expect(captured!.headers['content-type'], 'application/json');
      final body = jsonDecode(utf8.decode(captured!.bodyBytes));
      expect(body['amount'], 5.0);
      expect(body['userId'], 'mobile-user');
    });

    test('addSaving throws on a non-2xx response (D-20)', () async {
      final client = MockClient((http.Request request) async {
        return http.Response(
          '{"error":"bad"}',
          400,
          request: request,
          headers: {'content-type': 'application/json'},
        );
      });
      final api = ApiService(client: client);
      await expectLater(api.addSaving(5.00), throwsA(isA<Exception>()));
    });
  });
}
