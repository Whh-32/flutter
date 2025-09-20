// lib/screens/new_form.dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:frappe_app/services/sales_form_service.dart';
import 'package:get_it/get_it.dart';

class NewForm extends StatefulWidget {
  const NewForm({super.key});

  @override
  State<NewForm> createState() => _NewFormState();
}

class _NewFormState extends State<NewForm> {
  final step = 0.obs;
  final TextEditingController nationalIdController = TextEditingController();
  final SalesFormService _salesFormService = SalesFormService();
  bool isLoading = false;

  String? buyerNationalId;
  Map<String, dynamic>? buyerInfo;
  String? sellerId;
  String? documentId;
  String? itemId;
  String? warehouseId;
  String? smsCode;

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
          child: child,
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
            onChanged: (value) {
              setState(() {
                buyerNationalId = value;
              });
            },
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
            // Header
            const Text(
              "📋 اطلاعات خریدار",
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),

            // Info Card
            Card(
              elevation: 3,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: Colors.blue.shade100, width: 1),
              ),
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
                      isHighlighted: true,
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 32),

            // Next Button with shadow
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.blue.shade100,
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: buildNextButton(() => step.value++),
            ),
          ],
        ),
      );

  Widget _buildInfoRow(String emoji, String label, String? value,
      {bool isHighlighted = false}) {
    return Row(
      children: [
        Text(
          emoji,
          style: const TextStyle(fontSize: 20),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value ?? "نامشخص",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: isHighlighted ? Colors.green.shade700 : Colors.black87,
                ),
              ),
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
        // Handle loading state
        if (snapshot.connectionState == ConnectionState.waiting) {
          return buildStepWrapper(
            child: const Center(child: CircularProgressIndicator()),
          );
        }

        // Handle error state
        if (snapshot.hasError) {
          // Show error toast
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
                  onPressed: () {
                    setState(() {}); // Retry by rebuilding
                  },
                  child: const Text("تلاش مجدد"),
                ),
              ],
            ),
          );
        }

        // Handle data state
        if (snapshot.hasData) {
          final data = snapshot.data!;

          // Check if data is empty
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
                  onChanged: (v) => setState(() => sellerId = v),
                ),
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

        // Fallback - should not reach here
        return buildStepWrapper(
          child: const Center(child: Text("وضعیت نامعلوم")),
        );
      },
    );
  }

  Widget stepDocumentSelection() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _salesFormService.fetchDocuments(),
      builder: (_, snapshot) {
        if (!snapshot.hasData) {
          return buildStepWrapper(
            child: const Center(child: CircularProgressIndicator()),
          );
        }
        final data = snapshot.data!;
        return buildStepWrapper(
          child: Column(
            children: [
              buildDropdown(
                label: "انتخاب سند",
                data: data,
                value: documentId,
                onChanged: (v) => setState(() => documentId = v),
              ),
              const SizedBox(height: 20),
              buildNextButton(() {
                if (documentId == null || documentId!.isEmpty) {
                  Fluttertoast.showToast(msg: "لطفا یک سند انتخاب کنید");
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

  Widget stepItemSelection() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _salesFormService.fetchItems(),
      builder: (_, snapshot) {
        if (!snapshot.hasData) {
          return buildStepWrapper(
            child: const Center(child: CircularProgressIndicator()),
          );
        }
        final data = snapshot.data!;
        return buildStepWrapper(
          child: Column(
            children: [
              buildDropdown(
                label: "انتخاب کالا",
                data: data,
                value: itemId,
                onChanged: (v) => setState(() => itemId = v),
              ),
              const SizedBox(height: 20),
              buildNextButton(() {
                if (itemId == null || itemId!.isEmpty) {
                  Fluttertoast.showToast(msg: "لطفا یک کالا انتخاب کنید");
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

  Widget stepWarehouseSelection() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _salesFormService.fetchWarehouses(),
      builder: (_, snapshot) {
        if (!snapshot.hasData) {
          return buildStepWrapper(
            child: const Center(child: CircularProgressIndicator()),
          );
        }
        final data = snapshot.data!;
        return buildStepWrapper(
          child: Column(
            children: [
              buildDropdown(
                label: "انتخاب انبار",
                data: data,
                value: warehouseId,
                onChanged: (v) => setState(() => warehouseId = v),
              ),
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

  Widget stepSmsVerification() => buildStepWrapper(
        child: Column(
          children: [
            buildNextButton(() async {
              final ok = await _salesFormService.sendSmsCode();
              if (ok) Fluttertoast.showToast(msg: "کد ارسال شد");
            }, "ارسال کد"),
            const SizedBox(height: 16),
            TextField(
              decoration: const InputDecoration(
                labelText: "کد تایید",
                border: OutlineInputBorder(),
              ),
              onChanged: (v) => smsCode = v,
            ),
            const SizedBox(height: 16),
            buildNextButton(() async {
              if (smsCode == null || smsCode!.isEmpty) {
                Fluttertoast.showToast(msg: "کد تایید وارد نشده");
                return;
              }
              final ok = await _salesFormService.verifySmsCode(smsCode!);
              if (ok) {
                step.value++;
              } else {
                Fluttertoast.showToast(msg: "کد اشتباه است");
              }
            }, "تایید"),
          ],
        ),
      );

  Widget stepFinalSubmit() => buildStepWrapper(
        child: buildNextButton(() async {
          final ok = await _salesFormService.finalSubmit();
          if (ok) {
            Fluttertoast.showToast(msg: "ثبت نهایی انجام شد");
            step.value++;
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
            return stepDocumentSelection();
          case 4:
            return stepItemSelection();
          case 5:
            return stepWarehouseSelection();
          case 6:
            return stepSmsVerification();
          case 7:
            return stepFinalSubmit();
          default:
            return const Center(
              child: Text("پایان 🎉", style: TextStyle(fontSize: 20)),
            );
        }
      }),
    );
  }
}
