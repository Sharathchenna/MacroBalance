import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:macrotracker/widgets/shimmer_loading.dart';

class BarcodeResults extends StatefulWidget {
  final String barcode;

  const BarcodeResults({
    super.key,
    required this.barcode,
  });

  @override
  State<BarcodeResults> createState() => _BarcodeResultsState();
}

class _BarcodeResultsState extends State<BarcodeResults> {
  bool _isLoading = true;
  Map<String, dynamic>? _productData;
  String? _error;

  // Enhanced color scheme
  final primaryColor = Color(0xFF4CAF50); // Fresh green
  final accentColor = Color(0xFF81C784); // Light green
  final backgroundColor = Color(0xFFF5F7FA); // Cool gray
  final cardColor = Colors.white;
  final textColor = Color(0xFF2C3E50); // Dark blue-gray

  // UI constants
  final borderRadius = 20.0;
  final cardElevation = 3.0;
  final cardMargin = EdgeInsets.symmetric(vertical: 8, horizontal: 4);
  final cardPadding = EdgeInsets.all(16.0);

  // Animation durations
  final fadeInDuration = Duration(milliseconds: 300);

  @override
  void initState() {
    super.initState();
    _searchBarcode(widget.barcode);
  }

  Future<void> _searchBarcode(String barcode) async {
    if (barcode.isEmpty) return;

    try {
      final response = await http.get(
        Uri.parse(
          'https://world.openfoodfacts.org/api/v0/product/$barcode.json',
        ),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 1) {
          setState(() {
            _productData = data['product'];
            _isLoading = false;
          });
        } else {
          setState(() {
            _error = 'Product not found';
            _isLoading = false;
          });
        }
      } else {
        setState(() {
          _error = 'Failed to fetch product data';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Error: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        leading: CupertinoNavigationBarBackButton(
          color: primaryColor,
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Product Details',
          style: TextStyle(
            color: textColor,
            fontWeight: FontWeight.w600,
            fontSize: 24,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: AnimatedSwitcher(
        duration: fadeInDuration,
        child: _isLoading
            ? ShimmerLoading()
            : _error != null
                ? _buildErrorState()
                : _buildProductDetails(),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Container(
        padding: EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline_rounded,
              size: 64,
              color: primaryColor,
            ),
            SizedBox(height: 24),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: textColor,
                fontSize: 18,
                height: 1.5,
              ),
            ),
            SizedBox(height: 32),
            ElevatedButton(
              onPressed: () => _searchBarcode(widget.barcode),
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(borderRadius),
                ),
                padding: EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              ),
              child: Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProductDetails() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Product Image Card
          if (_productData?['image_url'] != null)
            Card(
              elevation: cardElevation,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(borderRadius),
              ),
              color: cardColor,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(borderRadius),
                child: Image.network(
                  _productData!['image_url'],
                  height: 250,
                  width: double.infinity,
                  fit: BoxFit.contain,
                ),
              ),
            ),
          SizedBox(height: 24),

          // Product Name Card
          Card(
            elevation: cardElevation,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(borderRadius),
            ),
            color: cardColor,
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                _productData?['product_name'] ?? 'Unknown Product',
                style: TextStyle(
                  color: primaryColor,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          SizedBox(height: 24),

          // Nutritional Information Card
          Card(
            elevation: cardElevation,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(borderRadius),
            ),
            color: cardColor,
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.restaurant_menu, color: primaryColor),
                      SizedBox(width: 8),
                      Text(
                        'Nutritional Information',
                        style: TextStyle(
                          color: primaryColor,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  Divider(height: 24, color: primaryColor.withValues(alpha: 0.2)),
                  _buildNutritionRow('Calories', 'energy-kcal_100g'),
                  _buildNutritionRow('Protein', 'proteins_100g'),
                  _buildNutritionRow('Carbohydrates', 'carbohydrates_100g'),
                  _buildNutritionRow('Fat', 'fat_100g'),
                  _buildNutritionRow('Fiber', 'fiber_100g'),
                  _buildNutritionRow('Sugar', 'sugars_100g'),
                  _buildNutritionRow('Salt', 'salt_100g'),
                ],
              ),
            ),
          ),

          // Ingredients Card
          if (_productData?['ingredients_text'] != null) ...[
            SizedBox(height: 24),
            Card(
              elevation: cardElevation,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(borderRadius),
              ),
              color: cardColor,
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info_outline, color: primaryColor),
                        SizedBox(width: 8),
                        Text(
                          'Ingredients',
                          style: TextStyle(
                            color: primaryColor,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    Divider(height: 24, color: primaryColor.withValues(alpha: 0.2)),
                    Text(
                      _productData!['ingredients_text'],
                      style: TextStyle(
                        color: primaryColor.withValues(alpha: 0.8),
                        fontSize: 16,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildNutritionRow(String label, String key) {
    final value = _productData?['nutriments']?[key];
    if (value == null) return SizedBox.shrink();

    return Container(
      padding: EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: primaryColor.withValues(alpha: 0.1),
            width: 1,
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: textColor.withValues(alpha: 0.8),
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: primaryColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '${value.toStringAsFixed(1)}${_getNutritionUnit(key)}',
              style: TextStyle(
                color: primaryColor,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getNutritionUnit(String key) {
    if (key.contains('energy')) return ' kcal';
    return ' g';
  }
}
