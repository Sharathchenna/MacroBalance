import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:macrotracker/theme/app_theme.dart';

class TermsScreen extends StatefulWidget {
  const TermsScreen({super.key});

  @override
  State<TermsScreen> createState() => _TermsScreenState();
}

class _TermsScreenState extends State<TermsScreen> {
  late final WebViewController _controller;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0x00000000))
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (String url) {
            setState(() {
              _isLoading = false;
            });
          },
        ),
      );

    _loadHtmlFromAssets();
  }

  Future<void> _loadHtmlFromAssets() async {
    String fileText = await rootBundle.loadString('assets/terms.html');
    _controller.loadHtmlString(fileText);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final customColors = theme.extension<CustomColors>();
    final isDarkMode = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Terms & Conditions'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        systemOverlayStyle:
            isDarkMode ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_isLoading)
            Center(
              child: CircularProgressIndicator(
                color: customColors?.textPrimary,
              ),
            ),
        ],
      ),
    );
  }
}
