// lib/screens/new_form.dart
import 'package:device_preview/device_preview.dart';
import 'package:flutter/material.dart';
import 'package:frappe_app/utils/constants.dart';
import 'package:get/get.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:frappe_app/services/sales_form_service.dart';
import 'package:frappe_app/views/desk/desk_view.dart';
import 'package:frappe_app/utils/SharedPreferenceHelper.dart';
import 'package:get_it/get_it.dart';
import 'dart:async';

class NewForm extends StatefulWidget {
  const NewForm({super.key});

  @override
  State<NewForm> createState() => _NewFormState();
}

class _NewFormState extends State<NewForm> {
  final _shared = GetIt.I.get<SharedPreferencesHelper>();
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

  // Cache for seller and warehouse data
  List<Map<String, dynamic>> _sellersCache = [];
  List<Map<String, dynamic>> _warehousesCache = [];

  /// ------------------ Reusable Widgets ------------------
  Widget buildDropdown({
    required String label,
    required List<Map<String, dynamic>> data,
    required String? value,
    required Function(String?) onChanged,
    bool isSearchable = false,
  }) {
    final uniqueData = {for (var e in data) e["id"]: e}.values.toList();

    String getDisplayText(Map<String, dynamic> item) {
      return item["name"]?.toString() ?? item["title"]?.toString() ?? "";
    }

    // Regular dropdown (original)
    Widget buildRegularDropdown() {
      return DropdownButtonFormField<String>(
        value:
            uniqueData.any((e) => e["id"].toString() == value) ? value : null,
        isExpanded: true,
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
        items: uniqueData
            .map((e) => DropdownMenuItem<String>(
                  value: e["id"].toString(),
                  child: Text(getDisplayText(e)),
                ))
            .toList(),
        onChanged: onChanged,
      );
    }

    // Searchable dropdown using built-in widgets with dynamic height
    Widget buildSearchableDropdown() {
      // Use a local key that gets reset when value is null
      return Autocomplete<String>(
        key: ValueKey(value ??
            'empty'), // This will force rebuild when value changes to null
        displayStringForOption: (option) {
          final item = uniqueData.firstWhere(
            (e) => e["id"].toString() == option,
            orElse: () => {},
          );
          return getDisplayText(item);
        },
        optionsBuilder: (TextEditingValue textEditingValue) {
          if (textEditingValue.text.isEmpty) {
            return uniqueData.map((e) => e["id"].toString());
          }
          return uniqueData
              .where((e) => getDisplayText(e)
                  .toLowerCase()
                  .contains(textEditingValue.text.toLowerCase()))
              .map((e) => e["id"].toString());
        },
        onSelected: onChanged,
        fieldViewBuilder:
            (context, textEditingController, focusNode, onFieldSubmitted) {
          // Clear the controller when value is null (when resetting)
          if (value == null) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              textEditingController.clear();
            });
          } else {
            // Set initial value text
            final selectedItem = uniqueData.firstWhere(
              (e) => e["id"].toString() == value,
              orElse: () => {},
            );
            if (selectedItem.isNotEmpty) {
              textEditingController.text = getDisplayText(selectedItem);
            }
          }

          return TextFormField(
            controller: textEditingController,
            focusNode: focusNode,
            onFieldSubmitted: (value) => onFieldSubmitted(),
            decoration: InputDecoration(
              labelText: label,
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              suffixIcon: const Icon(Icons.arrow_drop_down),
            ),
          );
        },
        optionsViewBuilder: (context, onSelected, options) {
          final itemCount = options.length;

          // Dynamic height calculation
          double getContainerHeight() {
            if (itemCount == 0) {
              return 80.0; // Height for "no results" message
            } else if (itemCount == 1) {
              return 60.0; // Smaller height for single item
            } else if (itemCount <= 3) {
              return itemCount * 56.0; // Compact height for few items
            } else {
              return 200.0; // Maximum height for many items
            }
          }

          return Align(
            alignment: Alignment.topRight,
            child: Material(
              elevation: 4,
              child: Container(
                height: getContainerHeight(), // Dynamic height applied here
                child: itemCount == 0
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Text(
                            'موردی یافت نشد',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 14,
                            ),
                          ),
                        ),
                      )
                    : ListView.builder(
                        padding: EdgeInsets.zero,
                        itemCount: itemCount,
                        itemBuilder: (context, index) {
                          final option = options.elementAt(index);
                          final item = uniqueData.firstWhere(
                            (e) => e["id"].toString() == option,
                          );
                          return ListTile(
                            title: Text(getDisplayText(item)),
                            onTap: () => onSelected(option),
                          );
                        },
                      ),
              ),
            ),
          );
        },
      );
    }

    return isSearchable ? buildSearchableDropdown() : buildRegularDropdown();
  }

  Widget buildStepWrapper({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(8),
      child: Container(
        decoration: BoxDecoration(
            border: Border.all(),
            color: Colors.white,
            borderRadius: BorderRadius.circular(10)),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: SingleChildScrollView(
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
            const Text("اطلاعات خریدار",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            buildStepWrapper(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _buildInfoRow("نام", buyerInfo?["name"]),
                    const Divider(),
                    _buildInfoRow("استان", buyerInfo?["province"]),
                    const Divider(),
                    _buildInfoRow("شهر", buyerInfo?["city"]),
                    const Divider(),
                    _buildInfoRow("کد ملی", buyerInfo?["national_id"]),
                    const Divider(),
                    _buildInfoRow("شماره مبایل", buyerInfo?["mobile"]),
                    const Divider(),
                    _buildInfoRow(
                        "باقیمانده اعتبار", buyerInfo?["credit"].toString()),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            buildNextButton(() => step.value++),
          ],
        ),
      );

  Widget _buildInfoRow(String label, String? value) {
    return Row(
      children: [
        Expanded(
          child: Text(label, style: TextStyle(fontSize: 14)),
        ),
        Expanded(
          child: Text(value ?? "نامشخص",
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
        ),
      ],
    );
  }

  Widget stepSellerSelection() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _salesFormService.fetchSellers(_shared.getString(USERNAME)),
      builder: (_, snapshot) {
        if (!snapshot.hasData) {
          return buildStepWrapper(
            child: const Center(child: CircularProgressIndicator()),
          );
        }

        final data = snapshot.data!;
        // Cache the sellers data
        _sellersCache = data;

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
      },
    );
  }

  Widget stepWarehouseSelection() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _salesFormService.fetchWarehouses(
          sellerId, _shared.getString(USERNAME)),
      builder: (_, snapshot) {
        // Show loading indicator
        if (snapshot.connectionState == ConnectionState.waiting) {
          return buildStepWrapper(
            child: const Center(child: CircularProgressIndicator()),
          );
        }

        // Show error state with back button
        if (snapshot.hasError) {
          return buildStepWrapper(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.error_outline,
                  size: 64,
                  color: Colors.red.shade300,
                ),
                const SizedBox(height: 16),
                Text(
                  "خطا در دریافت اطلاعات انبارها",
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.red.shade700,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                buildBackButton(() {
                  step.value--;
                }),
              ],
            ),
          );
        }

        // Show empty state with back button
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return buildStepWrapper(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.inventory_2_outlined,
                  size: 64,
                  color: Colors.grey.shade400,
                ),
                const SizedBox(height: 16),
                const Text(
                  "هیچ انباری یافت نشد",
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
                const SizedBox(height: 20),
                buildBackButton(() {
                  step.value--;
                }),
              ],
            ),
          );
        }

        // Data loaded successfully - NO back button
        final data = snapshot.data!;
        _warehousesCache = data;

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
              // Only next button when we have data
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

  Widget buildBackButton(VoidCallback onPressed) {
    return OutlinedButton(
      onPressed: onPressed,
      child: const Text("بازگشت"),
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
                  // انتخاب کالا - UPDATED
                  buildDropdown(
                    label: "انتخاب کالا",
                    data: items,
                    value: tempItemId,
                    isSearchable: true,
                    onChanged: (v) async {
                      setState(() {
                        tempItemId = v;
                        selectedDocForTemp = null;
                        tempQuantity = null;
                        tempQuantityController.clear();
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

                  const SizedBox(height: 16),

                  // تعداد
                  TextField(
                    controller: tempQuantityController,
                    decoration: InputDecoration(
                        labelText: "مقدار",
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12))),
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

                            // Reset the dropdown - ADD THIS LINE
                            _resetItemSelection();
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
            ...selectedItems.asMap().entries.map((entry) {
              final index = entry.key;
              final item = entry.value;
              return _buildSelectedItemCard(item, index);
            }).toList(),
            const SizedBox(height: 30),
            const Divider(),
          ],
          const SizedBox(height: 20),
          TextField(
            decoration: InputDecoration(
                labelText: "توضیحات (اختیاری)",
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12))),
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

  /// Add this method to reset the dropdown
  void _resetItemSelection() {
    // Reset all temporary variables
    setState(() {
      tempItemId = null;
      tempQuantity = null;
      tempQuantityController.clear();
      selectedDocForTemp = null;
      docsForTemp = [];
      isLoadingDocs = false;
    });
  }

  /// متغیرهای کمکی جدید
  List<Map<String, dynamic>> docsForTemp = [];
  String? selectedDocForTemp;
  bool isLoadingDocs = false;
  String? _getSalePrice(String uniqueKey, String? selectedDoc) {
    if (selectedDoc == null) return null;

    try {
      final documents = availableDocuments[uniqueKey];
      if (documents != null) {
        final document = documents.firstWhere(
          (doc) => doc['id'] == selectedDoc,
          orElse: () => {},
        );

        if (document.isNotEmpty) {
          final salePrice = document['details']?['saleprice']?.toString();
          return salePrice != null ? _formatPrice(salePrice) : null;
        }
      }
    } catch (e) {
      print('Error getting sale price: $e');
    }

    return null;
  }

  String _formatPrice(String price) {
    // Format price with commas for thousands
    final number = int.tryParse(price);
    if (number != null) {
      return number.toString().replaceAllMapped(
            RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
            (Match m) => '${m[1]},',
          );
    }
    return price;
  }

  /// کارت نمایش کالای انتخاب‌شده
  Widget _buildSelectedItemCard(Map<String, dynamic> item, int index) {
    // Use a unique key for each item to prevent issues
    final String uniqueKey = '${item['id']}_$index';
    final String? selectedDoc = selectedDocuments[uniqueKey];
    final controller = quantityControllers[uniqueKey];

    return buildStepWrapper(
      child: ListTile(
        title: Text(item['title'] ?? item['name'] ?? "کالا"),
        subtitle: Text(
            "تعداد: ${controller?.text ?? '-'}\nسند: ${selectedDoc ?? 'انتخاب نشده'} \nقیمت فروش: ${_getSalePrice(uniqueKey, selectedDoc) ?? 'نامشخص'}"),
        trailing: IconButton(
          icon: const Icon(Icons.delete, color: Colors.red),
          onPressed: () => _removeItem(uniqueKey, index),
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

    // Create a new map to avoid reference issues
    final newItem = Map<String, dynamic>.from(item);

    final controller = TextEditingController(text: quantity);

    // Use a unique key for each item (itemId + index)
    final uniqueKey = '${itemId}_${selectedItems.length}';

    setState(() {
      selectedItems.add(newItem);
      quantityControllers[uniqueKey] = controller;
      availableDocuments[uniqueKey] = List<Map<String, dynamic>>.from(docs);
      selectedDocuments[uniqueKey] = selectedDoc;
    });
  }

  void _removeItem(String uniqueKey, int index) {
    setState(() {
      // Remove the item at the specific index
      if (index >= 0 && index < selectedItems.length) {
        selectedItems.removeAt(index);
      }

      // Remove associated data using the unique key
      quantityControllers.remove(uniqueKey);
      selectedDocuments.remove(uniqueKey);
      availableDocuments.remove(uniqueKey);

      // Rebuild the keys for remaining items to maintain consistency
      _rebuildItemKeys();
    });
  }

  void _rebuildItemKeys() {
    // Create new maps for the remaining items
    final newQuantityControllers = <String, TextEditingController>{};
    final newSelectedDocuments = <String, String?>{};
    final newAvailableDocuments = <String, List<Map<String, dynamic>>>{};

    for (int i = 0; i < selectedItems.length; i++) {
      final item = selectedItems[i];
      final oldKey = '${item['id']}_$i'; // Try to reconstruct the old key
      final newKey = '${item['id']}_$i'; // New key with updated index

      // Transfer data to new maps with new keys
      if (quantityControllers.containsKey(oldKey)) {
        newQuantityControllers[newKey] = quantityControllers[oldKey]!;
      }

      if (selectedDocuments.containsKey(oldKey)) {
        newSelectedDocuments[newKey] = selectedDocuments[oldKey];
      }

      if (availableDocuments.containsKey(oldKey)) {
        newAvailableDocuments[newKey] = availableDocuments[oldKey]!;
      }
    }

    // Replace the old maps with new ones
    setState(() {
      quantityControllers = newQuantityControllers;
      selectedDocuments = newSelectedDocuments;
      availableDocuments = newAvailableDocuments;
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
            "تایید شماره موبایل",
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 📋 خلاصه اطلاعات
            const Text(
              "خلاصه اطلاعات فاکتور",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),

            // Buyer info
            buildStepWrapper(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("مشخصات خریدار",
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    _buildSummaryRow("کد ملی", buyerNationalId ?? "نامشخص"),
                    _buildSummaryRow("نام", buyerInfo?["name"] ?? "نامشخص"),
                    _buildSummaryRow(
                        "استان", buyerInfo?["province"] ?? "نامشخص"),
                    _buildSummaryRow("شهر", buyerInfo?["city"] ?? "نامشخص"),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 12),

            // Seller + warehouse
            buildStepWrapper(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("مشخصات فروش",
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    _buildSummaryRow("فروشنده", _getSellerName()),
                    _buildSummaryRow("انبار", _getWarehouseName()),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 12),

            // Items
            buildStepWrapper(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("کالاهای انتخابی",
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    ..._buildItemsSummary(),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 12),

            // Description
            if (description.isNotEmpty) ...[
              buildStepWrapper(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("توضیحات",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                          )),
                      const SizedBox(height: 8),
                      Text(description),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],

            const SizedBox(height: 2),

            // ✅ Final submit button OR loading
            isLoading
                ? const Padding(
                    padding: EdgeInsets.only(bottom: 16), // فاصله از پایین
                    child: Center(
                      child: CircularProgressIndicator(),
                    ),
                  )
                : buildNextButton(() async {
                    setState(() {
                      isLoading = true;
                    });

                    try {
                      // ساخت items
                      final List<Map<String, dynamic>> invoiceItems = [];

                      for (int i = 0; i < selectedItems.length; i++) {
                        final item = selectedItems[i];
                        final String itemId = item['id'];
                        final String uniqueKey = '${itemId}_$i';

                        final String? purchaseDoc =
                            selectedDocuments[uniqueKey];
                        final String quantity =
                            quantityControllers[uniqueKey]?.text ?? '';

                        if (purchaseDoc == null || quantity.isEmpty) {
                          Fluttertoast.showToast(
                              msg:
                                  "لطفا برای همه کالاها سند و تعداد مشخص کنید");
                          setState(() {
                            isLoading = false;
                          });
                          return;
                        }

                        final document = availableDocuments[uniqueKey]!
                            .firstWhere((doc) => doc['id'] == purchaseDoc);

                        invoiceItems.add({
                          "item_code": itemId,
                          "quantity": int.tryParse(quantity) ?? 0,
                          "saleprice": document['details']['saleprice'],
                          "discount": 0,
                          "purchase_doc": purchaseDoc,
                          "item_id":
                              document['details']['item_id']?.toString() ?? "",
                        });
                      }

                      // ارسال درخواست
                      final result = await _salesFormService.finalSubmitInvoice(
                        nationalId: buyerNationalId!,
                        supplierId: sellerId!,
                        warehouse: warehouseId!,
                        description: description,
                        items: invoiceItems,
                      );

                      if (result['code'] == '2000') {
                        Fluttertoast.showToast(msg: result['message']);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) => DesktopView()),
                        );
                      } else {
                        Fluttertoast.showToast(msg: result['message']);
                      }
                    } catch (e) {
                      Fluttertoast.showToast(
                          msg: "خطا در ثبت نهایی: ${e.toString()}");
                    } finally {
                      setState(() {
                        isLoading = false;
                      });
                    }
                  }, "ثبت نهایی"),
          ],
        ),
      );

// Helper method for summary rows
  Widget _buildSummaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child:
                Text("$label:", style: TextStyle(fontWeight: FontWeight.w500)),
          ),
          Expanded(
            flex: 3,
            child: Text(value),
          ),
        ],
      ),
    );
  }

// Helper method to build items summary
  List<Widget> _buildItemsSummary() {
    if (selectedItems.isEmpty) {
      return [const Text("هیچ کالایی انتخاب نشده")];
    }

    return selectedItems.asMap().entries.map((entry) {
      final index = entry.key;
      final item = entry.value;
      final String itemId = item['id'];
      final String uniqueKey = '${itemId}_$index';

      final String? purchaseDoc = selectedDocuments[uniqueKey];
      final String quantity = quantityControllers[uniqueKey]?.text ?? '0';
      final String itemName = item['title'] ?? item['name'] ?? "کالا";

      String docInfo = "سند نامشخص";
      if (purchaseDoc != null && availableDocuments[uniqueKey] != null) {
        try {
          final document = availableDocuments[uniqueKey]!
              .firstWhere((doc) => doc['id'] == purchaseDoc);
          docInfo = "سند: ${document['name'] ?? purchaseDoc}";
        } catch (e) {
          docInfo = "سند: $purchaseDoc";
        }
      }

      return Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.only(top: 5),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(itemName, style: TextStyle(fontWeight: FontWeight.w500)),
            const SizedBox(height: 4),
            Text("تعداد: $quantity"),
            Text(docInfo),
          ],
        ),
      );
    }).toList();
  }

// Helper methods to get seller and warehouse names
  String _getSellerName() {
    if (sellerId == null) return "نامشخص";

    // Search in cached sellers data
    try {
      final seller = _sellersCache.firstWhere(
        (seller) => seller['id'].toString() == sellerId,
        orElse: () => {},
      );

      if (seller.isNotEmpty) {
        return seller['name']?.toString() ??
            seller['store_name']?.toString() ??
            "نامشخص";
      }
    } catch (e) {
      // If there's an error, fall back to ID
    }

    return sellerId ?? "نامشخص";
  }

  String _getWarehouseName() {
    if (warehouseId == null) return "نامشخص";

    // Search in cached warehouses data
    try {
      final warehouse = _warehousesCache.firstWhere(
        (warehouse) => warehouse['id'].toString() == warehouseId,
        orElse: () => {},
      );

      if (warehouse.isNotEmpty) {
        return warehouse['name']?.toString() ??
            warehouse['title']?.toString() ??
            "نامشخص";
      }
    } catch (e) {
      // If there's an error, fall back to ID
    }

    return warehouseId ?? "نامشخص";
  }

  /// ------------------ Build ------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false, // غیرفعال کردن دکمه پیشفرض بک
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              "فرآیند فروش",
              style: TextStyle(fontSize: 17),
            ),
            Obx(() {
              if (step.value > 0) {
                return TextButton(
                  onPressed: () {
                    if (step.value > 0) step.value--;
                  },
                  child: const Text(
                    "مرحله قبل",
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 14,
                    ),
                  ),
                );
              }
              return const SizedBox();
            }),
          ],
        ),
      ),
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
