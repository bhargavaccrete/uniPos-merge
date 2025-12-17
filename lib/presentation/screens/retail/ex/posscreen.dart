import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:unipos/presentation/screens/retail/ex/fullscreen.dart';

class RetailPosScreen extends StatefulWidget {
  const RetailPosScreen({super.key});

  @override
  State<RetailPosScreen> createState() => _RetailPosScreenState();
}

class _RetailPosScreenState extends State<RetailPosScreen> {
  /// Preview camera (MAIN SCREEN)
  final MobileScannerController previewController =
  MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    autoStart: true,
  );

  final List<BillItem> billItems = [];
  double total = 0;
  double discount = 0;
  String selectedPaymentMethod = 'Cash';
  String selectedBusinessType = 'Retail'; // Retail or Wholesale

  // ---------------- ADD PRODUCT ----------------
  void _addProduct(String barcode) {
    setState(() {
      final index =
      billItems.indexWhere((item) => item.barcode == barcode);

      if (index != -1) {
        billItems[index].qty++;
      } else {
        billItems.add(
          BillItem(
            name: "Sample Product",
            barcode: barcode,
            price: 80,
            qty: 1,
          ),
        );
      }
      _recalculateTotal();
    });
  }

  void _recalculateTotal() {
    total = billItems.fold(
      0,
          (sum, item) => sum + item.price * item.qty,
    );
  }

  @override
  void dispose() {
    previewController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      body: SafeArea(
        child: Column(
          children: [
            _header(),
            _totalCard(),
            _cameraPreview(),
            _billList(),
            _actionBar(),
            _searchBar(),
          ],
        ),
      ),
    );
  }

  // ================= HEADER =================
  Widget _header() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top row: Bill selector + Add button + Discount button
          Row(
            children: [
              // Bill chip
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E3A5F),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Text(
                      'Bill 1',
                      style: TextStyle(color: Colors.white, fontSize: 14),
                    ),
                    SizedBox(width: 4),
                    Icon(Icons.close, color: Colors.white, size: 16),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Add button
              InkWell(
                onTap: () {},
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E3A5F),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Icon(Icons.add, color: Colors.white, size: 20),
                ),
              ),
              const Spacer(),
              // Discount button
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E3A5F),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'Tap to add\ndiscount',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 11,
                    height: 1.2,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Customer + Payment method
          Row(
            children: [
              // Back button
              const Icon(Icons.chevron_left, size: 28),
              const SizedBox(width: 8),
              // Add customer button
              TextButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.person_add_outlined,
                    color: Colors.green, size: 18),
                label: const Text(
                  'Add Customer',
                  style: TextStyle(color: Colors.green, fontSize: 13),
                ),
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
              const Spacer(),
              // Payment method dropdown
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: DropdownButton<String>(
                  value: selectedPaymentMethod,
                  underline: const SizedBox(),
                  icon: const Icon(Icons.arrow_drop_down, size: 20),
                  items: ['Cash', 'Card', 'UPI', 'Other']
                      .map((method) => DropdownMenuItem(
                            value: method,
                            child: Text(method, style: const TextStyle(fontSize: 13)),
                          ))
                      .toList(),
                  onChanged: (value) {
                    setState(() {
                      selectedPaymentMethod = value!;
                    });
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ================= TOTAL =================
  Widget _totalCard() {
    final now = DateTime.now();
    final dateStr = '${now.day}/${now.month}/${now.year.toString().substring(2)} ${now.hour}:${now.minute.toString().padLeft(2, '0')} ${now.hour >= 12 ? 'PM' : 'AM'}';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF1E3A5F),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            // Retail/Wholesale toggle
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () {
                      setState(() {
                        selectedBusinessType = 'Retail';
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      decoration: BoxDecoration(
                        color: selectedBusinessType == 'Retail'
                            ? const Color(0xFF2D4A6F)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        'Retail',
                        style: TextStyle(
                          color: selectedBusinessType == 'Retail'
                              ? Colors.white
                              : Colors.white60,
                          fontSize: 13,
                          fontWeight: selectedBusinessType == 'Retail'
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: InkWell(
                    onTap: () {
                      setState(() {
                        selectedBusinessType = 'Wholesale';
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      decoration: BoxDecoration(
                        color: selectedBusinessType == 'Wholesale'
                            ? const Color(0xFF2D4A6F)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        'Wholesale',
                        style: TextStyle(
                          color: selectedBusinessType == 'Wholesale'
                              ? Colors.white
                              : Colors.white60,
                          fontSize: 13,
                          fontWeight: selectedBusinessType == 'Wholesale'
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Total
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Total',
                  style: TextStyle(color: Colors.white70, fontSize: 14),
                ),
                Text(
                  '₹${total.toStringAsFixed(0)}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Date
            Row(
              children: [
                const Icon(Icons.refresh, color: Colors.white70, size: 16),
                const SizedBox(width: 6),
                Text(
                  'Date: $dateStr',
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ================= CAMERA PREVIEW =================
  Widget _cameraPreview() {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Container(
          height: 180,
          color: Colors.black,
          child: Stack(
            children: [
              /// CAMERA PREVIEW ONLY
              MobileScanner(
                controller: previewController,
                onDetect: null, // IMPORTANT: preview only
              ),

              /// FRAME
              Center(
                child: Container(
                  width: 240,
                  height: 100,
                  decoration: BoxDecoration(
                    border:
                    Border.all(color: Colors.white70, width: 2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),

              const Positioned(
                bottom: 8,
                left: 0,
                right: 0,
                child: Text(
                  "Align barcode within frame",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white70),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ================= BILL LIST =================
  Widget _billList() {
    if (billItems.isEmpty) {
      return const Expanded(
        child: Center(
          child: Text(
            'No items added yet',
            style: TextStyle(color: Colors.grey, fontSize: 14),
          ),
        ),
      );
    }

    return Expanded(
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: billItems.length,
        itemBuilder: (_, index) {
          final item = billItems[index];
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                // Product image
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(8),
                    image: item.imageUrl != null
                        ? DecorationImage(
                            image: NetworkImage(item.imageUrl!),
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                  child: item.imageUrl == null
                      ? Icon(Icons.shopping_bag,
                          color: Colors.grey.shade400, size: 30)
                      : null,
                ),
                const SizedBox(width: 12),
                // Product details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Product number and name
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade200,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              '#${index + 1}',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              item.name,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      // MRP, SP, Profit
                      Row(
                        children: [
                          Text(
                            'MRP: ₹${item.mrp.toStringAsFixed(0)}',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'SP: ₹${item.price.toStringAsFixed(0)}',
                            style: const TextStyle(
                              fontSize: 11,
                              color: Colors.green,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Profit: ${item.profit.toStringAsFixed(0)}',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // Price and controls
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    // Total price for this item
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '₹${(item.price * item.qty).toStringAsFixed(0)}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (item.originalTotal != null &&
                            item.originalTotal != item.price * item.qty)
                          Padding(
                            padding: const EdgeInsets.only(left: 4),
                            child: Text(
                              '₹${item.originalTotal!.toStringAsFixed(0)}',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey.shade500,
                                decoration: TextDecoration.lineThrough,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // Quantity controls
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Delete button
                        InkWell(
                          onTap: () {
                            setState(() {
                              billItems.removeAt(index);
                              _recalculateTotal();
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.red.shade50,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: Colors.red.shade200),
                            ),
                            child: Icon(Icons.delete_outline,
                                size: 18, color: Colors.red.shade400),
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Edit button
                        InkWell(
                          onTap: () {
                            // TODO: Open edit dialog
                          },
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade50,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: Colors.blue.shade200),
                            ),
                            child: Icon(Icons.edit_outlined,
                                size: 18, color: Colors.blue.shade400),
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Minus button
                        InkWell(
                          onTap: () {
                            setState(() {
                              if (item.qty > 1) {
                                item.qty--;
                                _recalculateTotal();
                              }
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade200,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Icon(Icons.remove, size: 16),
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Quantity
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: Text(
                            '${item.qty}',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 2),
                        Text(
                          'Pc',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Plus button
                        InkWell(
                          onTap: () {
                            setState(() {
                              item.qty++;
                              _recalculateTotal();
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.green,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Icon(Icons.add,
                                size: 16, color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // ================= ACTION BAR =================
  Widget _actionBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          // Quick add button with voice icon
          Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF8B7355), Color(0xFF6B5744)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                minimumSize: const Size(140, 50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () {},
              icon: const Icon(Icons.mic, color: Colors.white, size: 20),
              label: const Text(
                '+ add',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Create bill button
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF4CAF50), Color(0xFF45A049)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () {},
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Total (${billItems.length})',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Create bill',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(Icons.arrow_forward, color: Colors.white, size: 20),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ================= SEARCH + SCAN =================
  Widget _searchBar() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search by name or barcode',
                hintStyle: TextStyle(
                  color: Colors.grey.shade500,
                  fontSize: 14,
                ),
                filled: true,
                fillColor: Colors.grey.shade100,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
                prefixIcon: Icon(
                  Icons.search,
                  color: Colors.grey.shade500,
                  size: 22,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Scan button
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFF1E3A5F),
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF1E3A5F).withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () async {
                  // 🔴 RELEASE PREVIEW CAMERA
                  await previewController.stop();

                  final barcode = await Navigator.push<String>(
                    context,
                    MaterialPageRoute(
                      fullscreenDialog: true,
                      builder: (_) => const FullScreenScanner(),
                    ),
                  );

                  // 🟢 RESUME PREVIEW CAMERA
                  await previewController.start();

                  if (barcode != null) {
                    _addProduct(barcode);
                  }
                },
                borderRadius: BorderRadius.circular(10),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Text(
                        'Scan',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(width: 8),
                      Icon(
                        Icons.qr_code_scanner,
                        color: Colors.white,
                        size: 20,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Add button (floating)
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  // TODO: Show add product dialog
                },
                borderRadius: BorderRadius.circular(10),
                child: const Icon(
                  Icons.add,
                  color: Colors.white,
                  size: 26,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ================= MODEL =================
class BillItem {
  final String name;
  final String barcode;
  final double price;
  final double mrp;
  final double profit;
  final String? imageUrl;
  final double? originalTotal;
  int qty;

  BillItem({
    required this.name,
    required this.barcode,
    required this.price,
    required this.qty,
    this.mrp = 100.0,
    this.profit = 0,
    this.imageUrl,
    this.originalTotal,
  });
}
