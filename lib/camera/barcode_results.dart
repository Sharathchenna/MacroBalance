import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

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
      appBar: AppBar(
        title: Text('Product Details'),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : SingleChildScrollView(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Product Image
                      if (_productData?['image_url'] != null)
                        Center(
                          child: Image.network(
                            _productData!['image_url'],
                            height: 200,
                            fit: BoxFit.contain,
                          ),
                        ),
                      SizedBox(height: 16),

                      // Product Name
                      Text(
                        _productData?['product_name'] ?? 'Unknown Product',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      SizedBox(height: 16),

                      // Nutritional Information
                      Card(
                        child: Padding(
                          padding: EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Nutritional Information',
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                              SizedBox(height: 8),
                              _buildNutritionRow(
                                  'Calories', 'energy-kcal_100g'),
                              _buildNutritionRow('Protein', 'proteins_100g'),
                              _buildNutritionRow(
                                  'Carbohydrates', 'carbohydrates_100g'),
                              _buildNutritionRow('Fat', 'fat_100g'),
                              _buildNutritionRow('Fiber', 'fiber_100g'),
                              _buildNutritionRow('Sugar', 'sugars_100g'),
                              _buildNutritionRow('Salt', 'salt_100g'),
                            ],
                          ),
                        ),
                      ),

                      // Additional Information
                      if (_productData?['ingredients_text'] != null) ...[
                        SizedBox(height: 16),
                        Card(
                          child: Padding(
                            padding: EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Ingredients',
                                  style: Theme.of(context).textTheme.titleLarge,
                                ),
                                SizedBox(height: 8),
                                Text(_productData!['ingredients_text']),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
    );
  }

  Widget _buildNutritionRow(String label, String key) {
    final value = _productData?['nutriments']?[key];
    if (value == null) return SizedBox.shrink();

    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text('${value.toStringAsFixed(1)}${_getNutritionUnit(key)}'),
        ],
      ),
    );
  }

  String _getNutritionUnit(String key) {
    if (key.contains('energy')) return ' kcal';
    return ' g';
  }
}
