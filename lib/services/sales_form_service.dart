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

      final responseData = response?.data;
      if (responseData == null) throw Exception("پاسخ سرور خالی است");

      if (responseData is Map) {
        _logger.i("Response data keys: ${responseData.keys.toList()}");
      }

      if (!responseData.containsKey('message')) {
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
      final responseData = response?.data;
      if (responseData == null) throw Exception("پاسخ سرور خالی است");

      final Map<String, dynamic> result = responseData['result'];
      if (result['code'] == 2000) {
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

  Future<List<Map<String, dynamic>>> fetchItems() async {
    try {
      final response =
          await _httpService.get("/api/method/get_item?$credential");
      _logger.i("Items response: $response");
      final responseData = response?.data;
      if (responseData == null) throw Exception("پاسخ سرور خالی است");

      if (responseData.containsKey('errorcode')) {
        final int errorCode = responseData['errorcode'];
        final String errorMessage = responseData['message'] ?? "خطای ناشناخته";
        if (errorCode == 4000)
          throw Exception("نام کاربری یا رمز عبور اشتباه است");
        throw Exception("خطا: $errorMessage (کد: $errorCode)");
      }

      if (responseData.containsKey('res')) {
        final List<dynamic> itemsData = responseData['res'];
        return itemsData.map((item) {
          return {
            "id": item['item_name'] ?? "نامشخص",
            "title":
                "${item['item_name'] ?? 'نامشخص'} - ${item['uom'] ?? 'واحد نامشخص'}",
            "details": {
              "uom": item['uom'],
              "minprice": item['minprice'],
              "maxprice": item['maxprice']
            }
          };
        }).toList();
      }
      throw Exception("ساختار پاسخ سرور نامعتبر است");
    } catch (e) {
      _logger.e("Error fetching items: $e");
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> fetchWarehouses(String? supplierId) async {
    try {
      final response = await _httpService.get(
          "/api/method/get_warehouse_supplier?supplier_id=$supplierId&$credential");
      _logger.i("Warehouses response: $response");
      final responseData = response?.data;
      if (responseData == null) throw Exception("پاسخ سرور خالی است");

      if (responseData.containsKey('message')) {
        final Map<String, dynamic> message = responseData['message'];
        if (message['code'] == 2000) {
          final List<dynamic> warehousesData = message['data'];
          return warehousesData.map((warehouse) {
            return {
              "id": warehouse['name'].toString(),
              "title": warehouse['warehouse_name'] ??
                  warehouse['title'] ??
                  warehouse['name'] ??
                  "نامشخص"
            };
          }).toList();
        } else
          throw Exception("خطا در دریافت انبارها: ${message['message']}");
      } else if (responseData.containsKey('result')) {
        final Map<String, dynamic> result = responseData['result'];
        if (result['code'] == 2000) {
          final List<dynamic> warehousesData = result['data'];
          return warehousesData.map((warehouse) {
            return {
              "id": warehouse['name'].toString(),
              "title": warehouse['warehouse_name'] ??
                  warehouse['title'] ??
                  warehouse['name'] ??
                  "نامشخص"
            };
          }).toList();
        } else
          throw Exception("خطا در دریافت انبارها: ${result['message']}");
      } else if (responseData.containsKey('data')) {
        final List<dynamic> warehousesData = responseData['data'];
        return warehousesData.map((warehouse) {
          return {
            "id": warehouse['name'].toString(),
            "title": warehouse['warehouse_name'] ??
                warehouse['title'] ??
                warehouse['name'] ??
                "نامشخص"
          };
        }).toList();
      }
      throw Exception("ساختار پاسخ سرور نامعتبر است");
    } catch (e) {
      _logger.e("Error fetching warehouses: $e");
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> fetchPurchaseDocuments(
      String itemCode, String warehouse) async {
    try {
      final response = await _httpService.get(
          "/api/method/purchase_list?item_code=$itemCode&warehouse=$warehouse&$credential");
      _logger.i(
          "Purchase documents response: $itemCode&warehouse=$warehouse&$credential");
      _logger.i("data: $response");
      final responseData = response?.data;
      if (responseData == null) throw Exception("پاسخ سرور خالی است");

      if (responseData.containsKey('errorcode')) {
        final int errorCode = responseData['errorcode'];
        final String errorMessage = responseData['message'] ?? "خطای ناشناخته";
        if (errorCode == 4000)
          throw Exception("نام کاربری یا رمز عبور اشتباه است");
        throw Exception("خطا: $errorMessage (کد: $errorCode)");
      }

      if (responseData.containsKey('message') &&
          responseData['message'].containsKey('purchase_list')) {
        final List<dynamic> documentsData =
            responseData['message']['purchase_list'];

        if (documentsData.length == 0)
          throw Exception("سند خریدی برای این کالا وجود ندارد.");
        return documentsData.map((doc) {
          return {
            "id": doc['purchase_doc'].toString(),
            "title":
                "سند: ${doc['purchase_doc']} - موجودی: ${doc['remain_quantity']}",
            "details": {
              "purchase_doc": doc['purchase_doc'],
              "saleprice": doc['saleprice'],
              "quantity": doc['quantity'],
              "rate": doc['rate'],
              "item_code": doc['item_code'],
              "item_id": doc['item_id'],
              "purchase_date": doc['purchase_date'],
              "remain_quantity": doc['remain_quantity'],
            }
          };
        }).toList();
      }
      throw Exception("ساختار پاسخ سرور نامعتبر است");
    } catch (e) {
      _logger.e("Error fetching purchase documents: $e");
      rethrow;
    }
  }

  Future<Map<String, dynamic>> finalSubmitInvoice({
    required String nationalId,
    required String supplierId,
    required String warehouse,
    required String description,
    required List<Map<String, dynamic>> items,
  }) async {
    try {
      final Map<String, dynamic> requestData = {
        "username": "chopoo",
        "password": "AqJ_Te",
        "national_id": nationalId,
        "supplier_id": supplierId,
        "warehouse": warehouse,
        "description": description,
        "items": items,
      };
      _logger.i("Final submit request: $requestData");

      final response = await _httpService.post(
          "/api/method/create_invoice?$credential",
          FormData.fromMap(requestData));
      final responseData = response?.data;
      if (responseData == null) throw Exception("پاسخ سرور خالی است");

      if (responseData.containsKey('errorcode')) {
        final errorCode = responseData['errorcode'];
        final errorMessage = responseData['message'] ?? "خطای ناشناخته";
        throw Exception("$errorMessage (کد: $errorCode)");
      }

      if (responseData.containsKey('code') && responseData['code'] != '2000') {
        throw Exception(responseData['message'] ?? "خطا در ایجاد فاکتور");
      }

      return {
        "invoice_id": responseData['invoice_id'],
        "message": responseData['message'] ?? "صورتحساب با موفقیت ایجاد شد",
        "code": responseData['code'] ?? "2000",
      };
    } catch (e) {
      _logger.e("Error in final submit: $e");
      rethrow;
    }
  }

  Future<bool> sendSmsCode(String nationalId) async {
    try {
      final response = await _httpService.get(
          "/api/method/send_verification_chopoo?national_id=$nationalId&$credential");

      _logger.i("Send SMS response: $response");
      final responseData = response?.data;
      if (responseData == null) throw Exception("پاسخ سرور خالی است");

      // در این API نتیجه مستقیم داخل body است
      if (responseData['code'] == 2000) {
        return true;
      } else if (responseData['errorcode'] == 5000) {
        throw Exception("شماره موبایل برای این خریدار یافت نشد");
      } else if (responseData['errorcode'] == 4000) {
        throw Exception("نام کاربری یا رمز عبور اشتباه است");
      } else {
        throw Exception("خطای ناشناخته: ${responseData['message']}");
      }
    } catch (e) {
      _logger.e("Error sending SMS: $e");
      rethrow;
    }
  }

  Future<bool> verifySmsCode(String code, String nationalId) async {
    //for test
    return true;
    // try {
    //   final response = await _httpService.get(
    //       "/api/method/confirm_buyer_chopoo?verify_code=$code&national_id=$nationalId&$credential");

    //   _logger.i("Verify SMS response: $response");

    //   final responseData = response?.data;
    //   if (responseData == null) throw Exception("پاسخ سرور خالی است");

    //   final Map<String, dynamic> result = responseData;

    //   if (result['code'] == 2000) {
    //     // ✅ verification successful
    //     final buyerData = result['data'];
    //     _logger.i("Buyer confirmed: $buyerData");
    //     return true;
    //   } else if (result['code'] == 5000) {
    //     throw Exception("کد اشتباه است. لطفا کد صحیح را وارد کنید");
    //   } else if (result['code'] == 5300) {
    //     throw Exception("شماره موبایل برای این خریدار یافت نشد");
    //   } else if (result['code'] == 5100) {
    //     throw Exception("برای کاربری با این شماره موبایل کدی ارسال نشده است");
    //   } else if (result['errorcode'] == 4000) {
    //     throw Exception("نام کاربری یا رمز عبور اشتباه است");
    //   } else {
    //     throw Exception("خطای ناشناخته: ${result['message']}");
    //   }
    // } catch (e) {
    //   _logger.e("Error verifying SMS: $e");
    //   rethrow;
    // }
  }
}
