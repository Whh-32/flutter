// lib/services/sales_form_service.dart
import 'package:dio/dio.dart';
import 'package:frappe_app/services/http_service.dart';
import 'package:get_it/get_it.dart';
import 'package:logger/logger.dart';

class SalesFormService {
  final HttpService _httpService = GetIt.I.get<HttpService>();
  final Logger _logger = Logger();
  final String credential = "username=chopoo&password=AqJ_Te";

  Future<Map<String, dynamic>> fetchBuyerInfo(String nationalId) async {
    try {
      final response = await _httpService.get(
          "/api/method/get_buyer_info_chopoo?national_id=$nationalId&$credential");

      _logger.i("Buyer info response: $response");

      // Access the .data property of the Response object
      final responseData = response?.data;

      if (responseData == null) {
        throw Exception("پاسخ سرور خالی است");
      }

      if (responseData is Map) {
        _logger.i("Response data keys: ${responseData.keys.toList()}");
      }

      // Check if 'message' key exists in response data
      if (!responseData.containsKey('message')) {
        _logger.e("Response doesn't contain 'message' key");
        throw Exception("پاسخ سرور نامعتبر است - کلید 'message' یافت نشد");
      }

      final Map<String, dynamic> message = responseData['message'];

      if (message['code'] == 2000) {
        final buyerData = message['data'][0];
        return {
          "name": buyerData['full_name'],
          "province": buyerData['province'],
          "city": buyerData['city'],
          "national_id": buyerData['national_id'],
          "credit": buyerData['custom_remain_loan']
        };
      } else if (message['code'] == 5000) {
        throw Exception("اطلاعاتی برای این کد ملی یافت نشد");
      } else if (message['code'] == 4000) {
        throw Exception("نام کاربری یا رمز عبور اشتباه است");
      } else {
        throw Exception("خطای ناشناخته: ${message['message']}");
      }
    } catch (e) {
      _logger.e("Error fetching buyer info: $e");
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> fetchSellers(String? nationalId) async {
    try {
      final response = await _httpService
          .get("/api/method/get_store?seller=$nationalId&$credential");

      _logger.i("Sellers response: $response");

      // Access the .data property of the Response object
      final responseData = response?.data;

      if (responseData == null) {
        throw Exception("پاسخ سرور خالی است");
      }

      // For sellers endpoint, the response uses 'result' instead of 'message'
      final Map<String, dynamic> result = responseData['result'];

      if (result['code'] == 2000) {
        // Success case - map the API response to our expected format
        final List<dynamic> sellersData = result['data'];
        return sellersData.map((seller) {
          return {"id": seller['id'].toString(), "name": seller['store_name']};
        }).toList();
      } else if (result['code'] == 5000) {
        throw Exception("اطلاعاتی برای فروشندگان یافت نشد");
      } else if (result['code'] == 4000) {
        throw Exception("نام کاربری یا رمز عبور اشتباه است");
      } else {
        throw Exception("خطای ناشناخته: ${result['message']}");
      }
    } catch (e) {
      _logger.e("Error fetching sellers: $e");
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> fetchDocuments() async {
    try {
      // Replace with actual API call
      await Future.delayed(const Duration(seconds: 1));
      return [
        {"id": "d1", "title": "سند ۱"},
        {"id": "d2", "title": "سند ۲"},
      ];
    } catch (e) {
      _logger.e("Error fetching documents: $e");
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> fetchItems() async {
    try {
      // Replace with actual API call
      await Future.delayed(const Duration(seconds: 1));
      return [
        {"id": "i1", "title": "کالا ۱"},
        {"id": "i2", "title": "کالا ۲"},
      ];
    } catch (e) {
      _logger.e("Error fetching items: $e");
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> fetchWarehouses() async {
    try {
      // Replace with actual API call
      await Future.delayed(const Duration(seconds: 1));
      return [
        {"id": "w1", "title": "انبار ۱"},
        {"id": "w2", "title": "انبار ۲"},
      ];
    } catch (e) {
      _logger.e("Error fetching warehouses: $e");
      rethrow;
    }
  }

  Future<bool> sendSmsCode() async {
    try {
      // Replace with actual API call
      await Future.delayed(const Duration(seconds: 1));
      return true;
    } catch (e) {
      _logger.e("Error sending SMS: $e");
      rethrow;
    }
  }

  Future<bool> verifySmsCode(String code) async {
    try {
      // Replace with actual API call
      await Future.delayed(const Duration(seconds: 1));
      return code == "1234";
    } catch (e) {
      _logger.e("Error verifying SMS: $e");
      rethrow;
    }
  }

  Future<bool> finalSubmit() async {
    try {
      // Replace with actual API call
      await Future.delayed(const Duration(seconds: 1));
      return true;
    } catch (e) {
      _logger.e("Error in final submit: $e");
      rethrow;
    }
  }
}
