import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'services/api_service.dart';
import 'services/storage_service.dart';
import 'payment_result_screen.dart';

/// SBI ePay payment screen.
///
/// Flow:
///  1. Loads the server-generated [SbiTransactionData.paymentPageHtml] in a
///     WebView (falls back to [SbiTransactionData.sbiPostUrl] if HTML is empty).
///  2. Intercepts every URL that leaves the SBI gateway domain – this is the
///     server's success / failure callback redirect.
///  3. Calls `api/Payment/getSbiTransactionDetails` to cross-verify the actual
///     payment status before navigation.
///  4. Navigates to [PaymentResultScreen] with full details.
class SbiPaymentScreen extends StatefulWidget {
  final SbiTransactionData sbiData;

  const SbiPaymentScreen({super.key, required this.sbiData});

  @override
  State<SbiPaymentScreen> createState() => _SbiPaymentScreenState();
}

enum _PaymentPhase { loading, processing, verifying }

class _SbiPaymentScreenState extends State<SbiPaymentScreen> {
  late final WebViewController _webViewController;

  _PaymentPhase _phase = _PaymentPhase.loading;
  String? _verifyError;

  /// Guard – prevent duplicate verification if the WebView fires multiple
  /// redirects before we block navigation.
  bool _callbackHandled = false;

  // SBI gateway host suffixes – all navigation to these is allowed.
  static const _sbiHosts = [
    'sbi.co.in',
    'sbi.in',
    'sbiuat.bank.in',
  ];

  /// The exact server-side callback path SBI redirects the browser to after
  /// payment.  Intercepting this URL is the standard/correct way to detect
  /// SBI ePAY payment completion.
  static const _sbiCallbackFragment = '/api/Payu_redirect/sbi_redirect';

  // ── Lifecycle ──────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _initWebView();
  }

  void _initWebView() {
    _webViewController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: _onPageStarted,
          onPageFinished: _onPageFinished,
          onNavigationRequest: _onNavigationRequest,
          // onUrlChange fires for ALL URL transitions including server-side
          // 302 redirects. This is the single interception point for the
          // SBI payment callback (sbi_redirect).
          onUrlChange: _onUrlChange,
          onWebResourceError: _onWebResourceError,
        ),
      );

    final html = widget.sbiData.paymentPageHtml;
    if (html != null && html.isNotEmpty) {
      _webViewController.loadHtmlString(
        html,
        baseUrl: widget.sbiData.sbiPostUrl,
      );
    } else if (widget.sbiData.sbiPostUrl != null) {
      _webViewController.loadRequest(Uri.parse(widget.sbiData.sbiPostUrl!));
    }
  }

  // ── WebView Callbacks ──────────────────────────────────────────────────────

  void _onPageStarted(String url) {
    if (!mounted) return;
    if (_phase == _PaymentPhase.loading && !_isPassiveUrl(url)) {
      setState(() => _phase = _PaymentPhase.processing);
    }
  }

  void _onPageFinished(String url) {
    if (!mounted) return;
    if (_phase == _PaymentPhase.loading) {
      setState(() => _phase = _PaymentPhase.processing);
    }
  }

  /// Fired for ALL URL transitions including server-side 302 redirects.
  /// This is the single interception point: when SBI redirects to
  /// [_sbiCallbackFragment] after payment, we stop WebView and cross-verify.
  void _onUrlChange(UrlChange change) {
    final url = change.url;
    if (url == null || !mounted || _callbackHandled) return;
    if (url.contains(_sbiCallbackFragment)) {
      _callbackHandled = true;
      final prelim = _extractStatusFromUrl(url);
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _verifySbiPayment(preliminaryStatus: prelim),
      );
    }
  }

  NavigationDecision _onNavigationRequest(NavigationRequest request) {
    final url = request.url;

    // Let passive URLs through (initial HTML load, inline assets).
    if (_isPassiveUrl(url)) return NavigationDecision.navigate;

    // Block plain HTTP — HTTPS only during payment.
    final uri = Uri.tryParse(url);
    if (uri != null && uri.scheme == 'http') {
      return NavigationDecision.prevent;
    }

    // Update phase when leaving the initial load state.
    if (_isSbiGatewayUrl(url) && _phase == _PaymentPhase.loading) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _phase = _PaymentPhase.processing);
      });
    }

    // Allow all HTTPS navigation — SBI ePay flow goes through 3D Secure pages,
    // bank OTP pages, and card network ACS pages on various domains that cannot
    // be enumerated in advance. Security is already ensured by HTTPS + cert
    // pinning on our own server endpoint.
    return NavigationDecision.navigate;
  }

  void _onWebResourceError(WebResourceError error) {
    if (!mounted) return;
    if ((error.isForMainFrame ?? false) &&
        (_phase == _PaymentPhase.loading ||
            _phase == _PaymentPhase.processing)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Payment page error: ${error.description}',
            style: GoogleFonts.poppins(fontSize: 13),
          ),
          backgroundColor: Colors.red.shade700,
        ),
      );
    }
  }

  // ── URL Helpers ────────────────────────────────────────────────────────────

  bool _isPassiveUrl(String url) =>
      url.startsWith('about:') ||
      url.startsWith('data:') ||
      url.startsWith('blob:');

  bool _isSbiGatewayUrl(String url) {
    final host = Uri.tryParse(url)?.host.toLowerCase() ?? '';
    return host.isEmpty || _sbiHosts.any((h) => host.endsWith(h));
  }

  /// Extract a preliminary payment status from the callback URL params/path
  /// so we have a fallback if the verification API call fails.
  PaymentStatus? _extractStatusFromUrl(String url) {
    try {
      final uri = Uri.parse(url);
      final params = uri.queryParameters;
      final raw = (params['txn_status'] ??
              params['status'] ??
              params['payment_status'] ??
              uri.path)
          .toLowerCase();

      if (raw.contains('success')) return PaymentStatus.success;
      if (raw.contains('fail') ||
          raw.contains('error') ||
          raw.contains('cancel') ||
          raw.contains('decline')) {
        return PaymentStatus.failure;
      }
      if (raw.contains('pending') || raw.contains('process')) {
        return PaymentStatus.pending;
      }
    } catch (_) {}
    return null;
  }

  // ── Cross-Verification ─────────────────────────────────────────────────────

  Future<void> _verifySbiPayment({PaymentStatus? preliminaryStatus}) async {
    if (!mounted) return;
    setState(() {
      _phase = _PaymentPhase.verifying;
      _verifyError = null;
    });

    final mobileTxnId = await StorageService.getSbiMobileTransactionId();
    if (mobileTxnId == null || mobileTxnId.isEmpty) {
      _navigateFromPrelim(preliminaryStatus);
      return;
    }

    try {
      final response = await ApiService.getSbiTransactionDetails(mobileTxnId);
      if (!mounted) return;

      if (response.status == true && response.data != null) {
        await StorageService.clearSbiMobileTransactionId();
        _navigateToResult(response.data!);
      } else {
        setState(() {
          _verifyError =
              response.message ?? 'Verification failed. Please retry.';
        });
      }
    } catch (e) {
      if (!mounted) return;
      if (preliminaryStatus != null) {
        _navigateFromPrelim(preliminaryStatus);
      } else {
        setState(() {
          _verifyError = ApiService.getUserFriendlyErrorMessage(
            e,
            fallbackMessage:
                'Unable to verify your payment. Please retry or contact support.',
          );
        });
      }
    }
  }

  // ── Navigation Helpers ─────────────────────────────────────────────────────

  void _navigateToResult(SbiPaymentDetails data) {
    final statusStr = data.paymentStatus?.toUpperCase() ?? '';
    final PaymentStatus paymentStatus;
    if (statusStr == 'SUCCESS') {
      paymentStatus = PaymentStatus.success;
    } else if (statusStr == 'PENDING' ||
        statusStr == 'PROCESSING' ||
        statusStr == 'INITIATED') {
      paymentStatus = PaymentStatus.pending;
    } else {
      paymentStatus = PaymentStatus.failure;
    }

    final details = <String, String>{};
    _addDetail(details, 'Bill No', data.billNo);
    _addDetail(details, 'Property ID', data.propertyId);
    _addDetail(details, 'Financial Year', data.financialYear);
    _addDetail(details, 'Payment Mode', data.paymentMode);
    _addDetail(details, 'Owner Name', data.ownerName);
    _addDetail(details, 'Mobile', data.mobileNo);
    _addAmountDetail(details, 'Property Tax', data.propertyTaxPaid);
    _addAmountDetail(details, 'Water Tax', data.waterTaxPaid);
    _addAmountDetail(details, 'Sewer Tax', data.sewerTaxPaid);
    _addAmountDetail(details, 'Other Tax', data.otherTaxPaid);
    _addAmountDetail(details, 'Water Charge', data.waterChargePaid);
    _addDetail(details, 'Payment Time', data.sbiPaymentTime);

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => PaymentResultScreen(
          status: paymentStatus,
          txnId: data.txnid ?? widget.sbiData.txnid,
          amount: data.netPayable,
          details: details,
        ),
      ),
    );
  }

  void _navigateFromPrelim(PaymentStatus? status) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => PaymentResultScreen(
          status: status ?? PaymentStatus.pending,
          txnId: widget.sbiData.txnid,
          details: const {},
        ),
      ),
    );
  }

  void _addDetail(Map<String, String> map, String key, String? value) {
    if (value != null && value.isNotEmpty) map[key] = value;
  }

  void _addAmountDetail(Map<String, String> map, String key, String? value) {
    if (value != null && value != '0.00' && value != '0' && value.isNotEmpty) {
      map[key] = '₹ $value';
    }
  }

  // ── Back Button ────────────────────────────────────────────────────────────

  Future<bool> _handleBackAttempt() async {
    if (_phase == _PaymentPhase.verifying) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Please wait while we verify your payment.',
            style: GoogleFonts.poppins(fontSize: 13),
          ),
        ),
      );
      return false;
    }

    if (_phase == _PaymentPhase.processing) {
      final confirmed = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            'Cancel Payment?',
            style:
                GoogleFonts.poppins(fontSize: 17, fontWeight: FontWeight.w700),
          ),
          content: Text(
            'Your payment is in progress. Going back may cause your transaction '
            'to fail or stay in a pending state. Are you sure?',
            style: GoogleFonts.poppins(fontSize: 14, height: 1.5),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(
                'Stay',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFFE67514),
                ),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(
                'Go Back',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600,
                  color: Colors.red.shade600,
                ),
              ),
            ),
          ],
        ),
      );
      return confirmed ?? false;
    }

    return true;
  }

  // ── UI ─────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final nav = Navigator.of(context);
        final allow = await _handleBackAttempt();
        if (allow && mounted) nav.pop();
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: _phase == _PaymentPhase.verifying
            ? null
            : AppBar(
                title: Text(
                  'SBI Payment',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                ),
                backgroundColor: const Color(0xFFE67514),
                foregroundColor: Colors.white,
                elevation: 0,
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back_rounded),
                  onPressed: () async {
                    final nav = Navigator.of(context);
                    final allow = await _handleBackAttempt();
                    if (allow && mounted) nav.pop();
                  },
                ),
              ),
        body: Stack(
          children: [
            // ── WebView ──────────────────────────────────────────────────────
            if (_phase != _PaymentPhase.verifying)
              WebViewWidget(controller: _webViewController),

            // ── Initial loading overlay ───────────────────────────────────
            if (_phase == _PaymentPhase.loading) _buildLoadingOverlay(),

            // ── Verifying overlay ─────────────────────────────────────────
            if (_phase == _PaymentPhase.verifying) _buildVerifyingOverlay(),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingOverlay() {
    return Container(
      color: Colors.white,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFE67514)),
            ),
            const SizedBox(height: 16),
            Text(
              'Loading SBI Payment Gateway…',
              style:
                  GoogleFonts.poppins(fontSize: 14, color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVerifyingOverlay() {
    final hasError = _verifyError != null;

    return Container(
      color: Colors.white,
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ── Icon circle ────────────────────────────────────────────
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: hasError
                        ? const Color(0xFFFDE8E8)
                        : const Color(0xFFFFF3E8),
                    boxShadow: [
                      BoxShadow(
                        color: (hasError
                                ? Colors.red
                                : const Color(0xFFE67514))
                            .withValues(alpha: 0.2),
                        blurRadius: 30,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Center(
                    child: hasError
                        ? Icon(Icons.error_outline_rounded,
                            color: Colors.red.shade600, size: 44)
                        : const CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(
                                Color(0xFFE67514)),
                            strokeWidth: 3,
                          ),
                  ),
                ),
                const SizedBox(height: 28),

                // ── Title ──────────────────────────────────────────────────
                Text(
                  hasError ? 'Verification Issue' : 'Verifying Payment…',
                  style: GoogleFonts.poppins(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF333333),
                  ),
                ),
                const SizedBox(height: 10),

                // ── Subtitle ───────────────────────────────────────────────
                Text(
                  hasError
                      ? _verifyError!
                      : 'Please wait while we confirm\nyour payment with SBI.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                    height: 1.6,
                  ),
                ),

                // ── Action buttons (error state only) ──────────────────────
                if (hasError) ...[
                  const SizedBox(height: 32),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.of(context).pop(),
                          style: OutlinedButton.styleFrom(
                            padding:
                                const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                            side: BorderSide(color: Colors.grey.shade300),
                          ),
                          child: Text(
                            'Go Back',
                            style: GoogleFonts.poppins(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey.shade700,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            setState(() => _verifyError = null);
                            _verifySbiPayment();
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFE67514),
                            padding:
                                const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                            elevation: 0,
                          ),
                          child: Text(
                            'Retry',
                            style: GoogleFonts.poppins(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
