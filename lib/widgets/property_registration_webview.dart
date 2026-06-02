import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:webview_flutter/webview_flutter.dart';

class PropertyRegistrationWebView extends StatefulWidget {
  const PropertyRegistrationWebView({super.key});

  @override
  State<PropertyRegistrationWebView> createState() =>
      _PropertyRegistrationWebViewState();
}

class _PropertyRegistrationWebViewState
    extends State<PropertyRegistrationWebView> {
  late final WebViewController _controller;
  bool _isLoading = true;

  static const _allowedHost = 'e-nagarsewaup.gov.in';

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) => setState(() => _isLoading = true),
          onPageFinished: (_) => setState(() => _isLoading = false),
          onNavigationRequest: (NavigationRequest request) {
            final uri = Uri.tryParse(request.url);
            // Only HTTPS to the trusted government domain is permitted
            if (uri != null &&
                uri.scheme == 'https' &&
                (uri.host == _allowedHost ||
                    uri.host.endsWith('.$_allowedHost'))) {
              return NavigationDecision.navigate;
            }
            return NavigationDecision.prevent;
          },
          onWebResourceError: (WebResourceError error) {
            // SSL / network errors are surfaced; no silent proceed
          },
        ),
      )
      ..loadRequest(
          Uri.parse('https://e-nagarsewaup.gov.in/onlinepay/newRegistration'));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Register Property',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 16),
        ),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFFE67514),
        elevation: 0,
        surfaceTintColor: Colors.white,
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_isLoading)
            const Center(
              child: CircularProgressIndicator(color: Color(0xFFE67514)),
            ),
        ],
      ),
    );
  }
}
