import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:webview_flutter/webview_flutter.dart';

class UrbanDevelopmentWebView extends StatefulWidget {
  const UrbanDevelopmentWebView({super.key});

  @override
  State<UrbanDevelopmentWebView> createState() =>
      _UrbanDevelopmentWebViewState();
}

class _UrbanDevelopmentWebViewState
    extends State<UrbanDevelopmentWebView> {
  late final WebViewController _controller;

  bool _isLoading = true;

  static const _initialUrl = 'https://upulbots.in/';

  @override
  void initState() {
    super.initState();

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)

      // Allow website navigation
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) {
            if (mounted) {
              setState(() {
                _isLoading = true;
              });
            }
          },

          onPageFinished: (String url) {
            if (mounted) {
              setState(() {
                _isLoading = false;
              });
            }
          },

          // Allow all URLs
          onNavigationRequest: (NavigationRequest request) {
            return NavigationDecision.navigate;
          },

          onWebResourceError: (WebResourceError error) {
            // Network / SSL / resource error
          },
        ),
      )

      // Initial website
      ..loadRequest(Uri.parse(_initialUrl));
  }

  /// Handle Android back button and AppBar back button
  Future<void> _handleBack() async {
    final bool canGoBack = await _controller.canGoBack();

    if (canGoBack) {
      // First go back inside WebView history
      await _controller.goBack();
    } else {
      // WebView history finished -> go back to Dashboard
      if (mounted) {
        Navigator.of(context).pop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // Don't pop Flutter screen immediately.
      // First check WebView history.
      canPop: false,

      onPopInvokedWithResult: (bool didPop, dynamic result) async {
        if (didPop) {
          return;
        }

        await _handleBack();
      },

      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: _handleBack,
          ),

          title: Text(
            'Urban Development Department',
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.w600,
              fontSize: 16,
            ),
          ),

          backgroundColor: Colors.white,
          foregroundColor: const Color(0xFFE67514),
          elevation: 0,
          surfaceTintColor: Colors.white,
        ),

        body: Stack(
          children: [
            WebViewWidget(
              controller: _controller,
            ),

            // Loading indicator
            if (_isLoading)
              const Center(
                child: CircularProgressIndicator(
                  color: Color(0xFFE67514),
                ),
              ),
          ],
        ),
      ),
    );
  }
}