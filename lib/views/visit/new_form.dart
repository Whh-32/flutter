// lib/screens/new_form.dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:frappe_app/services/sales_form_service.dart';
import 'dart:async';

class NewForm extends StatefulWidget {
  const NewForm({super.key});

  @override
  State<NewForm> createState() => _NewFormState();
}

class _NewFormState extends State<NewForm> {
  final step = 0.obs;
  RxBool canResend = true.obs;
  RxInt countdown = 60.obs;
  Timer? _timer;
  final TextEditingController nationalIdController = TextEditingController();
  final SalesFormService _salesFormService = SalesFormService();
  bool isLoading = false;

  String? buyerNationalId;
  Map<String, dynamic>? buyerInfo;
  String? sellerId;
  String? warehouseId;
  String? smsCode;
  String? tempItemId;
  String? tempQuantity;
  String description = "";

  // Multi-item selection variables
  List<Map<String, dynamic>> selectedItems = [];
  Map<String, TextEditingController> quantityControllers = {};
  Map<String, String?> selectedDocuments = {};
  Map<String, List<Map<String, dynamic>>> availableDocuments = {};
  Map<String, bool> loadingDocuments = {};

  /// ------------------ Reusable Widgets ------------------
  Widget buildDropdown({
    required String label,
    required List<Map<String, dynamic>> data,
    required String? value,
    required Function(String?) onChanged,
  }) {
    final uniqueData = {for (var e in data) e["id"]: e}.values.toList();
    return DropdownButtonFormField<String>(
      value: uniqueData.any((e) => e["id"].toString() == value) ? value : null,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
      items: uniqueData
          .map((e) => DropdownMenuItem<String>(
                value: e["id"].toString(),
                child:
                    Text(e["name"]?.toString() ?? e["title"]?.toString() ?? ""),
              ))
          .toList(),
      onChanged: onChanged,
    );
  }

  Widget buildStepWrapper({required Widget child}) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Card(
        elevation: 3,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: SingleChildScrollView(
            // ✅ added scroll
            child: child,
          ),
        ),
      ),
    );
  }

  Widget buildNextButton(VoidCallback onPressed, [String text = "ادامه"]) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(vertical: 14),
        ),
        onPressed: onPressed,
        child: Text(text, style: const TextStyle(fontSize: 16)),
      ),
    );
  }

  /// ------------------ Steps ------------------
  Widget stepBuyerNationalId() {
    return buildStepWrapper(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            controller: nationalIdController,
            decoration: InputDecoration(
              labelText: "کد ملی خریدار",
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
            keyboardType: TextInputType.number,
            onChanged: (value) => setState(() => buyerNationalId = value),
          ),
          const SizedBox(height: 16),
          isLoading
              ? const Center(child: CircularProgressIndicator())
              : buildNextButton(() async {
                  if (buyerNationalId == null || buyerNationalId!.isEmpty) {
                    Fluttertoast.showToast(msg: "لطفا کد ملی را وارد کنید");
                    return;
                  }
                  if (buyerNationalId!.length != 10 ||
                      !RegExp(r'^[0-9]+$').hasMatch(buyerNationalId!)) {
                    Fluttertoast.showToast(
                        msg: "کد ملی باید 10 رقمی و فقط شامل اعداد باشد");
                    return;
                  }
                  setState(() => isLoading = true);
                  try {
                    buyerInfo = await _salesFormService
                        .fetchBuyerInfo(buyerNationalId!);
                    step.value++;
                  } catch (e) {
                    Fluttertoast.showToast(msg: e.toString());
                  } finally {
                    setState(() => isLoading = false);
                  }
                }, "استعلام خریدار"),
        ],
      ),
    );
  }

  Widget stepBuyerInfo() => buildStepWrapper(
        child: Column(
          children: [
            const Text("📋 اطلاعات خریدار",
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 24),
            Card(
              elevation: 3,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: Colors.blue.shade100, width: 1)),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    _buildInfoRow("👤", "نام", buyerInfo?["name"]),
                    const Divider(height: 24),
                    _buildInfoRow("🏛️", "استان", buyerInfo?["province"]),
                    const Divider(height: 24),
                    _buildInfoRow("🏙️", "شهر", buyerInfo?["city"]),
                    const Divider(height: 24),
                    _buildInfoRow("🆔", "کد ملی", buyerInfo?["national_id"]),
                    const Divider(height: 24),
                    _buildInfoRow(
                        "💰",
                        "اعتبار",
                        buyerInfo?["credit"] != null
                            ? "${buyerInfo!["credit"]} تومان"
                            : null,
                        isHighlighted: true),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),
            Container(
              decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.blue.shade100,
                        blurRadius: 8,
                        offset: const Offset(0, 4))
                  ]),
              child: buildNextButton(() => step.value++),
            ),
          ],
        ),
      );

  Widget _buildInfoRow(String emoji, String label, String? value,
      {bool isHighlighted = false}) {
    return Row(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 20)),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: TextStyle(fontSize: 14, color: Colors.grey.shade600)),
              const SizedBox(height: 4),
              Text(value ?? "نامشخص",
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: isHighlighted
                          ? Colors.green.shade700
                          : Colors.black87)),
            ],
          ),
        ),
      ],
    );
  }

  Widget stepSellerSelection() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _salesFormService.fetchSellers(buyerNationalId),
      builder: (_, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return buildStepWrapper(
              child: const Center(child: CircularProgressIndicator()));
        }
        if (snapshot.hasError) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            Fluttertoast.showToast(
                msg:
                    "خطا در دریافت لیست فروشندگان: ${snapshot.error.toString().replaceFirst('Exception: ', '')}");
          });
          return buildStepWrapper(
            child: Column(
              children: [
                const Icon(Icons.error_outline, color: Colors.red, size: 50),
                const SizedBox(height: 16),
                Text(
                    "خطا در دریافت اطلاعات: ${snapshot.error.toString().replaceFirst('Exception: ', '')}",
                    textAlign: TextAlign.center),
                const SizedBox(height: 20),
                ElevatedButton(
                    onPressed: () => setState(() {}),
                    child: const Text("تلاش مجدد")),
              ],
            ),
          );
        }
        if (snapshot.hasData) {
          final data = snapshot.data!;
          if (data.isEmpty) {
            return buildStepWrapper(
              child: const Column(
                children: [
                  Icon(Icons.warning_amber, color: Colors.orange, size: 50),
                  SizedBox(height: 16),
                  Text("هیچ فروشنده‌ای یافت نشد", textAlign: TextAlign.center),
                ],
              ),
            );
          }
          return buildStepWrapper(
            child: Column(
              children: [
                buildDropdown(
                    label: "انتخاب فروشنده",
                    data: data,
                    value: sellerId,
                    onChanged: (v) => setState(() => sellerId = v)),
                const SizedBox(height: 20),
                buildNextButton(() {
                  if (sellerId == null || sellerId!.isEmpty) {
                    Fluttertoast.showToast(msg: "لطفا یک فروشنده انتخاب کنید");
                    return;
                  }
                  step.value++;
                }),
              ],
            ),
          );
        }
        return buildStepWrapper(
            child: const Center(child: Text("وضعیت نامعلوم")));
      },
    );
  }

  Widget stepWarehouseSelection() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _salesFormService.fetchWarehouses(sellerId),
      builder: (_, snapshot) {
        if (!snapshot.hasData)
          return buildStepWrapper(
              child: const Center(child: CircularProgressIndicator()));
        final data = snapshot.data!;
        return buildStepWrapper(
          child: Column(
            children: [
              buildDropdown(
                  label: "انتخاب انبار",
                  data: data,
                  value: warehouseId,
                  onChanged: (v) => setState(() => warehouseId = v)),
              const SizedBox(height: 20),
              buildNextButton(() {
                if (warehouseId == null || warehouseId!.isEmpty) {
                  Fluttertoast.showToast(msg: "لطفا یک انبار انتخاب کنید");
                  return;
                }
                step.value++;
              }),
            ],
          ),
        );
      },
    );
  }

  final TextEditingController tempQuantityController = TextEditingController();
  Widget stepItemAndDocumentSelection() {
    return buildStepWrapper(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text("افزودن کالاها",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center),
          const SizedBox(height: 20),
          const Divider(),
          const SizedBox(height: 20),
          FutureBuilder<List<Map<String, dynamic>>>(
            future: _salesFormService.fetchItems(),
            builder: (_, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final items = snapshot.data!;
              return Column(
                children: [
                  // انتخاب کالا
                  buildDropdown(
                    label: "انتخاب کالا",
                    data: items,
                    value: tempItemId,
                    onChanged: (v) async {
                      setState(() {
                        tempItemId = v;
                        selectedDocForTemp = null;
                        tempQuantity = null;
                        tempQuantityController.clear(); // ✅ ریست کردن ورودی
                        docsForTemp = [];
                        isLoadingDocs = true;
                      });
                      if (v != null && warehouseId != null) {
                        try {
                          final docs = await _salesFormService
                              .fetchPurchaseDocuments(v, warehouseId!);
                          setState(() {
                            docsForTemp = docs;
                            isLoadingDocs = false;
                          });
                        } catch (e) {
                          setState(() => isLoadingDocs = false);
                          Fluttertoast.showToast(
                              msg:
                                  "خطا در گرفتن اسناد خرید: ${e.toString().replaceFirst('Exception: ', '')}");
                        }
                      } else {
                        setState(() => isLoadingDocs = false);
                      }
                    },
                  ),
                  const SizedBox(height: 16),

                  if (isLoadingDocs) ...[
                    const Center(child: CircularProgressIndicator()),
                    const SizedBox(height: 16),
                  ],

                  if (docsForTemp.isNotEmpty)
                    buildDropdown(
                      label: "انتخاب سند خرید",
                      data: docsForTemp,
                      value: selectedDocForTemp,
                      onChanged: (v) => setState(() => selectedDocForTemp = v),
                    ),

                  if (selectedDocForTemp != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      "موجودی: ${docsForTemp.firstWhere((d) => d['id'] == selectedDocForTemp)['details']['remain_quantity']}",
                      style: const TextStyle(color: Colors.green),
                    ),
                  ],

                  const SizedBox(height: 16),

                  // تعداد
                  TextField(
                    controller: tempQuantityController, // ✅ کنترلر اضافه شد
                    decoration: const InputDecoration(
                        labelText: "مقدار", border: OutlineInputBorder()),
                    keyboardType: TextInputType.number,
                    onChanged: (value) => setState(() => tempQuantity = value),
                  ),
                  const SizedBox(height: 16),

                  ElevatedButton(
                    onPressed: tempItemId == null ||
                            selectedDocForTemp == null ||
                            tempQuantity == null
                        ? null
                        : () {
                            final remain = docsForTemp.firstWhere((d) =>
                                    d['id'] == selectedDocForTemp)['details']
                                ['remain_quantity'];
                            final q = int.tryParse(tempQuantity ?? "0") ?? 0;

                            if (q <= 0) {
                              Fluttertoast.showToast(
                                  msg: "تعداد باید بیشتر از صفر باشد");
                              return;
                            }

                            if (q > remain) {
                              Fluttertoast.showToast(
                                  msg:
                                      "تعداد وارد شده بیشتر از موجودی سند است");
                              return;
                            }

                            _addItemWithDoc(
                              tempItemId!,
                              tempQuantity!,
                              items,
                              docsForTemp,
                              selectedDocForTemp!,
                            );

                            /// ✅ بعد از اضافه کردن، ورودی ریست بشه
                            tempQuantityController.clear();
                            tempQuantity = null;
                          },
                    child: const Text("افزودن کالا"),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 30),
          const Divider(),
          const SizedBox(height: 20),
          if (selectedItems.isNotEmpty) ...[
            const Text("کالاهای انتخاب شده:",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            ...selectedItems
                .map((item) => _buildSelectedItemCard(item))
                .toList(),
          ],
          const SizedBox(height: 30),
          const Divider(),
          const SizedBox(height: 20),
          TextField(
            decoration: const InputDecoration(
                labelText: "توضیحات (اختیاری)", border: OutlineInputBorder()),
            maxLines: 3,
            onChanged: (value) => setState(() => description = value),
          ),
          const SizedBox(height: 30),
          buildNextButton(() {
            if (selectedItems.isEmpty) {
              Fluttertoast.showToast(msg: "لطفا حداقل یک کالا اضافه کنید");
              return;
            }
            step.value++;
          }),
        ],
      ),
    );
  }

  /// متغیرهای کمکی جدید
  List<Map<String, dynamic>> docsForTemp = [];
  String? selectedDocForTemp;
  bool isLoadingDocs = false;

  /// کارت نمایش کالای انتخاب‌شده
  Widget _buildSelectedItemCard(Map<String, dynamic> item) {
    final String itemId = item['id'];
    final String? selectedDoc = selectedDocuments[itemId];
    final controller = quantityControllers[itemId];
    return Card(
      child: ListTile(
        title: Text(item['title'] ?? "کالا"),
        subtitle: Text(
            "تعداد: ${controller?.text ?? '-'}\nسند: ${selectedDoc ?? 'انتخاب نشده'}"),
        trailing: IconButton(
          icon: const Icon(Icons.delete, color: Colors.red),
          onPressed: () => _removeItem(itemId),
        ),
      ),
    );
  }

  /// اضافه کردن کالا همراه سند انتخابی
  void _addItemWithDoc(
      String itemId,
      String quantity,
      List<Map<String, dynamic>> items,
      List<Map<String, dynamic>> docs,
      String selectedDoc) {
    final item = items.firstWhere((element) => element['id'] == itemId);
    final controller = TextEditingController(text: quantity);
    setState(() {
      selectedItems.add(item);
      quantityControllers[itemId] = controller;
      availableDocuments[itemId] = docs;
      selectedDocuments[itemId] = selectedDoc;
      tempItemId = null;
      tempQuantity = null;
      selectedDocForTemp = null;
      docsForTemp = [];
    });
  }

  void _removeItem(String itemId) {
    setState(() {
      selectedItems.removeWhere((e) => e['id'] == itemId);
      quantityControllers.remove(itemId);
      selectedDocuments.remove(itemId);
      availableDocuments.remove(itemId);
    });
  }

  Widget stepSmsVerification() {
    void startCountdown() {
      canResend.value = false;
      countdown.value = 60;

      Timer.periodic(const Duration(seconds: 1), (timer) {
        if (countdown.value == 0) {
          canResend.value = true;
          timer.cancel(); // stop the timer
        } else {
          countdown.value--; // update countdown
        }
      });
    }

    return buildStepWrapper(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            "📲 تایید شماره موبایل",
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          TextField(
            decoration: const InputDecoration(
              labelText: "کد تایید",
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.number,
            onChanged: (v) => setState(() => smsCode = v),
          ),
          const SizedBox(height: 24),
          Obx(() => ElevatedButton(
                style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12))),
                onPressed: canResend.value
                    ? () async {
                        try {
                          final ok = await _salesFormService
                              .sendSmsCode(buyerNationalId!);
                          if (ok) {
                            Fluttertoast.showToast(msg: "کد ارسال شد");
                            startCountdown();
                          }
                        } catch (e) {
                          Fluttertoast.showToast(msg: e.toString());
                        }
                      }
                    : null,
                child: Text(canResend.value
                    ? "ارسال کد"
                    : "ارسال مجدد در ${countdown.value} ثانیه"),
              )),
          const SizedBox(height: 20),
          buildNextButton(() async {
            if (smsCode == null || smsCode!.isEmpty) {
              Fluttertoast.showToast(msg: "کد تایید وارد نشده");
              return;
            }
            try {
              final ok = await _salesFormService.verifySmsCode(
                  smsCode!, buyerNationalId!);
              if (ok)
                step.value++;
              else
                Fluttertoast.showToast(msg: "کد اشتباه است");
            } catch (e) {
              Fluttertoast.showToast(msg: e.toString());
            }
          }, "تایید"),
        ],
      ),
    );
  }

  Widget stepFinalSubmit() => buildStepWrapper(
        child: buildNextButton(() async {
          try {
            final List<Map<String, dynamic>> invoiceItems = [];
            for (final item in selectedItems) {
              final String itemId = item['id'];
              final String? purchaseDoc = selectedDocuments[itemId];
              final String quantity = quantityControllers[itemId]?.text ?? '';
              if (purchaseDoc == null || quantity.isEmpty) {
                Fluttertoast.showToast(
                    msg: "لطفا برای همه کالاها سند و تعداد مشخص کنید");
                return;
              }
              final document = availableDocuments[itemId]!
                  .firstWhere((doc) => doc['id'] == purchaseDoc);
              invoiceItems.add({
                "item_code": itemId,
                "quantity": quantity,
                "saleprice": document['details']['saleprice'],
                "discount": 0,
                "purchase_doc": purchaseDoc,
                "item_id": document['details']['item_id'],
              });
            }
            final result = await _salesFormService.finalSubmitInvoice(
              nationalId: buyerNationalId!,
              supplierId: sellerId!,
              warehouse: warehouseId!,
              description: description,
              items: invoiceItems,
            );
            if (result['code'] == '2000') {
              Fluttertoast.showToast(msg: result['message']);
              step.value++;
            } else {
              Fluttertoast.showToast(msg: result['message']);
            }
          } catch (e) {
            Fluttertoast.showToast(msg: "خطا در ثبت نهایی: ${e.toString()}");
          }
        }, "ثبت نهایی"),
      );

  /// ------------------ Build ------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("فرآیند فروش")),
      body: Obx(() {
        switch (step.value) {
          case 0:
            return stepBuyerNationalId();
          case 1:
            return stepBuyerInfo();
          case 2:
            return stepSellerSelection();
          case 3:
            return stepWarehouseSelection();
          case 4:
            return stepItemAndDocumentSelection();
          case 5:
            return stepSmsVerification();
          case 6:
            return stepFinalSubmit();
          default:
            return const Center(
                child: Text("پایان 🎉", style: TextStyle(fontSize: 20)));
        }
      }),
    );
  }
}
