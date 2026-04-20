import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'services/api_service.dart';
import 'services/storage_service.dart';
import 'services/database_service.dart';
import 'package:payu_checkoutpro_flutter/payu_checkoutpro_flutter.dart';
import 'package:payu_checkoutpro_flutter/PayUConstantKeys.dart';
import 'payment_result_screen.dart';
import 'payment_grievance_screen.dart';
import 'payment_history_screen.dart';

class PaymentDetailsScreen extends StatefulWidget {
  final String propertyId;

  const PaymentDetailsScreen({super.key, required this.propertyId});

  @override
  State<PaymentDetailsScreen> createState() => _PaymentDetailsScreenState();
}

class _PayuDelegate implements PayUCheckoutProProtocol {
  final BuildContext context;
  PayUCheckoutProFlutter? _payu;
  _PayuDelegate(this.context);

  void setPayuInstance(PayUCheckoutProFlutter payu) {
    _payu = payu;
  }

  @override
  generateHash(Map response) async {
    if (kDebugMode) print('generateHash callback: $response');
    try {
      String? hashName;
      String? hashString;

      if (response.containsKey('hashName') && response.containsKey('hashString')) {
        hashName = response['hashName']?.toString();
        hashString = response['hashString']?.toString();
      } else {
        // Sometimes map is like {"payment_hash": null} or {hashName:..., hashString:...}
        for (final k in response.keys) {
          hashName = k?.toString();
          final v = response[k];
          hashString = v?.toString();
          break;
        }
      }

      if (hashName == null || hashString == null) {
        if (kDebugMode) print('generateHash: missing hashName/hashString');
        return;
      }

      final hashRes = await ApiService.generateHash(hashName, hashString);
      final hash = hashRes.data;
      if (kDebugMode) print('Server returned hash for $hashName: $hash');

      if (hash == null || hash.isEmpty) {
        if (kDebugMode) print('generateHash: empty hash from server');
        return;
      }

      // send back to native SDK via plugin
      await _payu?.hashGenerated(hash: {hashName: hash});
    } catch (e) {
      if (kDebugMode) print('generateHash error: $e');
    }
  }

  Map<String, String> _extractDetails(dynamic response) {
    final details = <String, String>{};
    try {
      Map? payuResp;
      if (response is Map) {
        final raw = response['payuResponse'];
        if (raw is Map) {
          payuResp = raw;
        } else if (raw is String && raw.isNotEmpty) {
          payuResp = jsonDecode(raw) as Map?;
        }
      }
      if (payuResp != null) {
        if (payuResp['txnid'] != null) details['Transaction ID'] = payuResp['txnid'].toString();
        if (payuResp['amount'] != null) details['Amount'] = '₹ ${payuResp['amount']}';
        if (payuResp['mode'] != null) details['Payment Mode'] = payuResp['mode'].toString();
        if (payuResp['status'] != null) details['Status'] = payuResp['status'].toString();
        if (payuResp['bank_ref_num'] != null && payuResp['bank_ref_num'].toString().isNotEmpty) {
          details['Bank Ref No'] = payuResp['bank_ref_num'].toString();
        }
        if (payuResp['mihpayid'] != null && payuResp['mihpayid'].toString().isNotEmpty) {
          details['PayU ID'] = payuResp['mihpayid'].toString();
        }
        if (payuResp['addedon'] != null) details['Date'] = payuResp['addedon'].toString();
      }
    } catch (e) {
      if (kDebugMode) print('Error extracting PayU details: $e');
    }
    return details;
  }

  String? _extractField(dynamic response, String field) {
    try {
      if (response is Map) {
        final raw = response['payuResponse'];
        Map? payuResp;
        if (raw is Map) {
          payuResp = raw;
        } else if (raw is String && raw.isNotEmpty) {
          payuResp = jsonDecode(raw) as Map?;
        }
        return payuResp?[field]?.toString();
      }
    } catch (_) {}
    return null;
  }

  @override
  onError(Map? response) {
    if (kDebugMode) print('PayU error: $response');
    final errorMsg = response?['errorMsg']?.toString() ?? 'Something went wrong';
    Navigator.of(context).pushReplacement(MaterialPageRoute(
      builder: (_) => PaymentResultScreen(
        status: PaymentStatus.failure,
        message: errorMsg,
      ),
    ));
  }

  @override
  onPaymentCancel(Map? response) {
    if (kDebugMode) print('PayU cancelled: $response');
    final isTxnInitiated = response?['isTxnInitiated'] == true;
    Navigator.of(context).pushReplacement(MaterialPageRoute(
      builder: (_) => PaymentResultScreen(
        status: isTxnInitiated ? PaymentStatus.pending : PaymentStatus.failure,
        message: isTxnInitiated
            ? 'Payment was initiated but cancelled. It may still be processing.'
            : 'Payment was cancelled.',
      ),
    ));
  }

  @override
  onPaymentFailure(response) {
    if (kDebugMode) print('PayU failure: $response');
    final details = _extractDetails(response);
    final txnId = _extractField(response, 'txnid');
    final amount = _extractField(response, 'amount');
    final status = _extractField(response, 'status');
    
    final isPending = status?.toLowerCase() == 'pending';
    Navigator.of(context).pushReplacement(MaterialPageRoute(
      builder: (_) => PaymentResultScreen(
        status: isPending ? PaymentStatus.pending : PaymentStatus.failure,
        txnId: txnId,
        amount: amount,
        details: details,
      ),
    ));
  }

  @override
  onPaymentSuccess(response) {
    if (kDebugMode) print('PayU success: $response');
    final details = _extractDetails(response);
    final txnId = _extractField(response, 'txnid');
    final amount = _extractField(response, 'amount');
    Navigator.of(context).pushReplacement(MaterialPageRoute(
      builder: (_) => PaymentResultScreen(
        status: PaymentStatus.success,
        txnId: txnId,
        amount: amount,
        details: details,
      ),
    ));
  }
}

class _PaymentDetailsScreenState extends State<PaymentDetailsScreen> {
  bool _isLoading = true;
  PropertyDetailsData? _details;
  String? _errorMessage;
  bool _showPropertyDetails = false;

  @override
  void initState() {
    super.initState();
    _fetchDetails();
  }

  String _getCurrentTime() {
    final now = DateTime.now();
    return "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')} "
           "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}";
  }

  Future<void> _fetchDetails() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final response = await ApiService.getPropertyDetails(widget.propertyId);
      if (response.success == true && response.data != null) {
        setState(() {
          _details = response.data;
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = response.message ?? "Failed to load details";
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  void _handlePayTax() async {
    final mobileNo = _details?.ownerDetails?.mobileNo;
    if (mobileNo == null || mobileNo.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Mobile number not available for OTP')),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final otpRes = await ApiService.sendOtp(mobileNo, widget.propertyId);
      setState(() => _isLoading = false);

      if (otpRes.success == true) {
        _showOtpAndPaymentDialog(mobileNo);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(otpRes.message ?? 'Failed to send OTP')),
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
  }

  void _showOtpAndPaymentDialog(String mobileNo) {
    final otpController = TextEditingController();
    bool isVerifying = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            top: 24, left: 24, right: 24
          ),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Verification Required',
                style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'Enter the OTP sent to $mobileNo to proceed with payment.',
                style: GoogleFonts.poppins(color: Colors.grey.shade600),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: otpController,
                keyboardType: TextInputType.number,
                maxLength: 6,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 24, letterSpacing: 8, fontWeight: FontWeight.bold),
                decoration: InputDecoration(
                  hintText: '000000',
                  counterText: "",
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: isVerifying ? null : () async {
                  if (otpController.text.length < 4) return;
                  setModalState(() => isVerifying = true);
                  try {
                    final res = await ApiService.verifyOtp(mobileNo, otpController.text);
                    if (res.success == true) {
                      Navigator.pop(context); // Close OTP sheet
                      _handleCreateTransaction();
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(res.message ?? 'Invalid OTP')),
                      );
                    }
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
                  } finally {
                    setModalState(() => isVerifying = false);
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0E3B90),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: isVerifying 
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text('Verify & Proceed', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleCreateTransaction() async {
    setState(() => _isLoading = true);
    try {
      // 1. Get critical identifiers from Database for this property
      final propertyEntity = await DatabaseService.getPropertyById(widget.propertyId);
      
      final String ulbId = propertyEntity?.ulbId ?? "0";
      final String totalArvValue = propertyEntity?.arvValue ?? "0.0";
      final String userId = propertyEntity?.userId ?? "0";

      // 2. Get email from SharedPreferences
      final String? email = await StorageService.getEmailId();
      
      final bill = _details?.billDetails;
      final owner = _details?.ownerDetails;

      // Formatting timestamp and ID as requested
      final String mobileId = "MOBTXN${DateTime.now().millisecondsSinceEpoch}";
      final String timestamp = _getCurrentTime();
      
      final request = InitiateTransactionRequest(
        mobileTransactionId: mobileId,
        mobileTransactionTimestamp: timestamp,
        billNo: bill?.billNo ?? "",
        propertyId: widget.propertyId,
        ulbId: ulbId,
        financialYear: bill?.finYear ?? "",
        ownerName: owner?.ownerName ?? "",
        fatherName: owner?.fatherName ?? "",
        mobileNo: owner?.mobileNo ?? "",
        propertyTax: bill?.houseTaxNetAmount ?? "0",
        waterTax: bill?.waterTaxNetAmount ?? "0",
        sewerTax: bill?.sewerTaxNetAmount ?? "0",
        otherTax: bill?.othertaxNetAmount ?? "0",
        waterCharge: bill?.waterChargeNetAmount ?? "0",
        netDemand: bill?.netDemand ?? "0",
        netPayable: bill?.netPayble ?? "0",
        totalArv: totalArvValue,
        userId: userId,
        emailId: email ?? "",
      );

      // --- LOGGING THE REQUEST DATA ---
      if (kDebugMode) {
        print('--- API CALL: create_transaction ---');
        print('Payload: ${jsonEncode(request.toJson())}');
        print('-------------------------------------');
      }

      final response = await ApiService.initiateTransaction(request);
      
      if (kDebugMode) {
        print('--- API RESPONSE: create_transaction ---');
        print('Status: ${response.status}');
        print('Message: ${response.message}');
        if (response.data != null) {
          print('TxnID: ${response.data?.txnid}');
        }
        print('----------------------------------------');
      }

      setState(() => _isLoading = false);

      if (response.status == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Transaction Initiated: ${response.data?.txnid}'),
            backgroundColor: Colors.green,
          ),
        );
        _showPaymentOptions(response.data);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(response.message ?? 'Transaction failed')),
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
      if (kDebugMode) {
        print('--- TRANSACTION ERROR ---');
        print(e.toString());
        print('--------------------------');
      }
    }
  }

  void _showPaymentOptions(Transaction? transactionData) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Select Payment Gateway',
              style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Amount: ₹ ${transactionData?.amount ?? "0.0"}',
              style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey.shade700),
            ),
            const SizedBox(height: 24),
            _buildPaymentOptionCard('Pay with Pay', 'Safe & Secure', Icons.payment_rounded, () {
              Navigator.pop(context);
              _startPayuFlow(transactionData);
            }),
            const SizedBox(height: 12),
            _buildPaymentOptionCard('Pay with SBI', 'Official SBI Gateway', Icons.account_balance_rounded, () {
              Navigator.pop(context);
            }),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Future<void> _startPayuFlow(Transaction? txnData) async {
    if (txnData == null) return;
    setState(() => _isLoading = true);
    try {
      final key = txnData.key ?? '';
      final txnid = txnData.txnid ?? 'TXN${DateTime.now().millisecondsSinceEpoch}';
      final amount = txnData.amount ?? '0';
      final productinfo = txnData.productinfo ?? 'Property Tax';
      final firstname = txnData.firstname ?? '';
      final email = txnData.email ?? '';

      if (kDebugMode) print('Starting PayU flow for txnid=$txnid amount=$amount');

      String makeSafeUrl(String? url) {
        const defaultUrl = 'https://www.payu.in/txnstatus';
        if (url == null) return defaultUrl;
        final trimmed = url.trim();
        try {
          final uri = Uri.parse(trimmed);
          if ((uri.scheme == 'https' || uri.scheme == 'http') && trimmed.isNotEmpty) {
            final host = uri.host.toLowerCase();
            // Only allow PayU domains; otherwise return default to satisfy SDK validation
            if (host.contains('payu')) return trimmed;
          }
        } catch (_) {}
        return defaultUrl;
      }

      final surl = makeSafeUrl(txnData.surl);
      final furl = makeSafeUrl(txnData.furl);

      if (kDebugMode) print('Starting PayU with txnid=$txnid, amount=$amount, key=$key');

      try {
        // Use the PayU plugin's actual API: PayUCheckoutProFlutter with a delegate.
        final delegate = _PayuDelegate(context);
        final payu = PayUCheckoutProFlutter(delegate);
        delegate.setPayuInstance(payu);

        final payUPaymentParams = <String, dynamic>{
          PayUPaymentParamKey.key: key,
          PayUPaymentParamKey.amount: amount,
          PayUPaymentParamKey.transactionId: txnid,
          PayUPaymentParamKey.productInfo: productinfo,
          PayUPaymentParamKey.firstName: firstname,
          PayUPaymentParamKey.email: email,
          PayUPaymentParamKey.phone: txnData.phone ?? '',
          PayUPaymentParamKey.android_surl: surl,
          PayUPaymentParamKey.android_furl: furl,
          PayUPaymentParamKey.ios_surl: surl,
          PayUPaymentParamKey.ios_furl: furl,
          PayUPaymentParamKey.environment: '1', // 0 = production, 1 = test/sandbox
          PayUPaymentParamKey.userCredential: '$key:$email',
        };

        final payUCheckoutProConfig = <String, dynamic>{
          PayUCheckoutProConfigKeys.merchantName: 'eNagarSewa',
        };

        final result = await payu.openCheckoutScreen(
          payUPaymentParams: payUPaymentParams,
          payUCheckoutProConfig: payUCheckoutProConfig,
        );

        if (kDebugMode) print('PayU openCheckoutScreen returned: $result');
      } catch (e) {
        if (kDebugMode) print('PayU plugin error: $e');
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to start PayU payment: $e')));
      }
    } catch (e) {
      if (kDebugMode) print('Payment error: $e');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Widget _buildPaymentOptionCard(String title, String subtitle, IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon, color: const Color(0xFF0E3B90), size: 28),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.bold)),
                Text(subtitle, style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey)),
              ],
            ),
            const Spacer(),
            const Icon(Icons.arrow_forward_ios_rounded, size: 16, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  void _showPaymentHistory() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PaymentHistoryScreen(
          propertyId: widget.propertyId,
          currReceiptDetails: _details?.currReceiptDetails ?? [],
          prevReceiptDetails: _details?.prevReceiptDetails ?? [],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        toolbarHeight: 70,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF333333), size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        centerTitle: false,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Payment Details',
              style: GoogleFonts.poppins(
                color: const Color(0xFF333333),
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              'PID: ${widget.propertyId}',
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(height: 1, color: Colors.grey.shade200),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFE67514)))
          : _errorMessage != null
              ? _buildErrorState()
              : _buildContent(),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline_rounded, color: Colors.red, size: 60),
            const SizedBox(height: 16),
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(color: Colors.black87),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _fetchDetails,
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE67514)),
              child: const Text('Retry', style: TextStyle(color: Colors.white)),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    final bill = _details?.billDetails;
    final prop = _details?.propertyDetailsInfo;
    final owner = _details?.ownerDetails;

    final houseTaxAdvance = double.tryParse(bill?.houseTaxAdvance ?? '0') ?? 0.0;
    final waterTaxAdvance = double.tryParse(bill?.waterTaxAdvance ?? '0') ?? 0.0;
    final sewerTaxAdvance = double.tryParse(bill?.sewerTaxAdvance ?? '0') ?? 0.0;
    final otherTaxAdvance = double.tryParse(bill?.otherTaxAdvance ?? '0') ?? 0.0;
    final waterChargeAdvance = double.tryParse(bill?.waterChargeAdvance ?? '0') ?? 0.0;
    final totalAdvancePay = (houseTaxAdvance + waterTaxAdvance + sewerTaxAdvance + otherTaxAdvance + waterChargeAdvance).toStringAsFixed(2);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // 1. Tax Summary Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE8F0FE),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.receipt_long_rounded, color: Color(0xFF0E3B90), size: 20),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Tax Summary',
                      style: GoogleFonts.poppins(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF333333),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                _buildSummaryRow('Bill Date', bill?.billDate),
                _buildSummaryRow('Bill Number', bill?.billNo),
                _buildSummaryRow('Financial Year', bill?.finYear),
                FutureBuilder<PropertyEntity?>(
                  future: DatabaseService.getPropertyById(widget.propertyId),
                  builder: (context, snapshot) {
                    return _buildSummaryRow('Total Arv', snapshot.data?.arvValue ?? '0.0');
                  },
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Divider(height: 1, thickness: 0.8),
                ),
                _buildSummaryRow('House Tax Net Amount', bill?.houseTaxNetAmount),
                _buildSummaryRow('Water Tax Net Amount', bill?.waterTaxNetAmount),
                _buildSummaryRow('Sewer Tax Net Amount', bill?.sewerTaxNetAmount),
                _buildSummaryRow('Other Tax Net Amount', bill?.othertaxNetAmount),
                _buildSummaryRow('Water Charge Net Amount', bill?.waterChargeNetAmount),
                _buildSummaryRow('Net Demand', bill?.netDemand),
                _buildSummaryRow('Total Advance Tax Pay', totalAdvancePay),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEDF3FF),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFD1E1FF), width: 1),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Net Payable',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF1A3B8E),
                        ),
                      ),
                      Text(
                        '₹ ${bill?.netPayble ?? "0.0"}',
                        style: GoogleFonts.poppins(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF0E3B90),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 20),

          // 2. Main Action Buttons (Moved inside scroll view)
          _buildPrimaryButton('Pay Your Tax Online', _handlePayTax),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _buildSecondaryButton('Print Property', Icons.print_outlined, () {})),
              const SizedBox(width: 12),
              Expanded(child: _buildSecondaryButton('Add Grievance', Icons.add_comment_outlined, () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => PaymentGrievanceScreen(
                      propertyId: widget.propertyId,
                      propertyDetails: _details,
                    ),
                  ),
                );
              })),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _buildSecondaryButton('ARV History', Icons.history_rounded, () {})),
              const SizedBox(width: 12),
              Expanded(child: _buildSecondaryButton('Payment History', Icons.payment_rounded, _showPaymentHistory)),
            ],
          ),

          const SizedBox(height: 20),

          // 3. Property Details Card (Moved below buttons)
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              children: [
                ListTile(
                  onTap: () => setState(() => _showPropertyDetails = !_showPropertyDetails),
                  title: Text(
                    'Property Details',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF333333),
                    ),
                  ),
                  trailing: Icon(
                    _showPropertyDetails ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                    color: const Color(0xFF0E3B90),
                  ),
                ),
                if (_showPropertyDetails)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: Column(
                      children: [
                        const Divider(height: 1),
                        const SizedBox(height: 12),
                        _buildSummaryRow('Property/House Id', widget.propertyId),
                        _buildSummaryRow('Zone Name', prop?.zoneName),
                        _buildSummaryRow('Ward Name', prop?.wardName),
                        _buildSummaryRow('Mohalla Name', prop?.mohallaName),
                        _buildSummaryRow('House No.', prop?.houseNo),
                        _buildSummaryRow('Property Address', prop?.address),
                        _buildSummaryRow('Owner/Occupier Name', owner?.ownerName),
                        _buildSummaryRow('Owner Mobile Number', owner?.mobileNo),
                        _buildSummaryRow('Owner Father Name', owner?.fatherName),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, String? value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 3,
            child: Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 13,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 4,
            child: Text(
              value ?? "N/A",
              textAlign: TextAlign.right,
              style: GoogleFonts.poppins(
                fontSize: 13,
                color: const Color(0xFF444444),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPrimaryButton(String text, VoidCallback onTap) {
    return Container(
      width: double.infinity,
      height: 56,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(
          colors: [Color(0xFFE67514), Color(0xFFF0852D)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFE67514).withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        child: Text(
          text,
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  Widget _buildSecondaryButton(String text, IconData icon, VoidCallback onTap) {
    return SizedBox(
      height: 50,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFE67514),
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          padding: EdgeInsets.zero,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: Colors.white),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                text,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
