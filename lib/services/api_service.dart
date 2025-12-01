import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import '../models/saving.dart';

class ApiService {
  // Use 10.0.2.2 for Android Emulator, localhost for iOS/Web
  String get _baseUrl {
    if (kIsWeb) return 'http://localhost:8084';
    if (Platform.isAndroid) return 'http://10.0.2.2:8084';
    return 'http://localhost:8084';
  }

  Future<double> getTotalSavings() async {
    try {
      final response = await http.get(Uri.parse('$_baseUrl/api/savings/total'));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return (data['total'] as num).toDouble();
      }
      throw Exception('Failed to load total savings');
    } catch (e) {
      print('Error getting total savings: $e');
      return 0.0; // Fallback
    }
  }

  Future<Saving> addSaving(double amount) async {
    try {
      final saving = Saving(amount: amount, userId: 'mobile-user');
      final response = await http.post(
        Uri.parse('$_baseUrl/api/savings'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(saving.toJson()),
      );

      if (response.statusCode == 201) {
        return Saving.fromJson(jsonDecode(response.body));
      }
      throw Exception('Failed to add saving');
    } catch (e) {
      print('Error adding saving: $e');
      rethrow;
    }
  }
}
