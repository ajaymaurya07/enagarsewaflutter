import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'services/api_service.dart';
import 'payment_result_screen.dart';

class SbiPaymentScreen extends StatefulWidget {
  final SbiTransactionData sbiData;

  const SbiPaymentScreen({super.key, required this.sbiData});

  @override
  State<SbiPaymentScreen> createState() => _SbiPaymentScreenState();
}

class _SbiPaymentScreenState extends State<SbiPaymentScreen> {
  late final WebViewController _controller;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) => setState(() => _isLoading = true),
          onPageFinished: (_) => setState(() => _isLoading = false),
          onNavigationRequest: (request) {
            final url = request.url.toLowerCase();
            // Detect SBI success/failure redirects
            if (url.contains('success') || url.contains('txn_status=success')) {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (_) => const PaymentResultScreen(
                    status: PaymentStatus.success,
                    txnId: null,
                    amount: null,
                    details: {},
                  ),
                ),
              );
              return NavigationDecision.prevent;
            }
            if (url.contains('failure') ||
                url.contains('failed') ||
                url.contains('txn_status=fail')) {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (_) => const PaymentResultScreen(
                    status: PaymentStatus.failure,
                    txnId: null,
                    amount: null,
                    details: {},
                  ),
                ),
              );
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
          onWebResourceError: (error) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Page load error: ${error.description}',
                  ),
                ),
              );
            }
          },
        ),
      );

    final html = widget.sbiData.paymentPageHtml;
    if (html != null && html.isNotEmpty) {
      _controller.loadHtmlString(html);
    } else if (widget.sbiData.sbiPostUrl != null) {
      _controller.loadRequest(Uri.parse(widget.sbiData.sbiPostUrl!));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'SBI Payment',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        backgroundColor: const Color(0xFFE67514),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_isLoading)
            const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFE67514)),
              ),
            ),
        ],
      ),
    );
  }
}
