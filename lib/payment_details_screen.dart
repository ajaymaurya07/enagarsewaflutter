import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'services/api_service.dart';
import 'services/storage_service.dart';
import 'services/database_service.dart';
import 'package:payu_checkoutpro_flutter/payu_checkoutpro_flutter.dart';
import 'package:payu_checkoutpro_flutter/PayUConstantKeys.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';
import 'payment_result_screen.dart';
import 'payment_grievance_screen.dart';
import 'payment_history_screen.dart';
import 'tour_guides/payment_details_tour.dart';

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
        return;
      }

      final hashRes = await ApiService.generateHash(hashName, hashString);
      final hash = hashRes.data;

      if (hash == null || hash.isEmpty) {
        return;
      }

      // send back to native SDK via plugin
      await _payu?.hashGenerated(hash: {hashName: hash});
    } catch (_) {}
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
    } catch (_) {}
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
  final _keyPayTaxButton = GlobalKey();
  final _keyPrintPropertyButton = GlobalKey();
  final _keyAddGrievanceButton = GlobalKey();
  final _keyArvHistoryButton = GlobalKey();
  final _keyPaymentHistoryButton = GlobalKey();

  bool _isLoading = true;
  PropertyDetailsData? _details;
  String? _errorMessage;
  bool _showPropertyDetails = false;
  TutorialCoachMark? _tutorialCoachMark;

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
        if (!mounted) return;

        setState(() {
          _details = response.data;
          _isLoading = false;
        });

        await WidgetsBinding.instance.endOfFrame;
        await _autoStartTourIfFirstVisit();
      } else {
        if (!mounted) return;

        setState(() {
          _errorMessage = response.message ?? "Failed to load details";
          _isLoading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _errorMessage = ApiService.getUserFriendlyErrorMessage(
          e,
          fallbackMessage:
              'Unable to load payment details right now. Please try again.',
        );
        _isLoading = false;
      });
    }
  }

  Future<void> _autoStartTourIfFirstVisit() async {
    if (_details == null) return;

    final prefs = await SharedPreferences.getInstance();
    final seen = prefs.getBool('tour_payment_details') ?? false;
    if (!seen && mounted) {
      await prefs.setBool('tour_payment_details', true);
      await _startTour();
    }
  }

  void _showTourSegment({
    required TargetFocus target,
    VoidCallback? onFinish,
  }) {
    _tutorialCoachMark = PaymentDetailsTourGuide.createCoachMark(
      targets: [target],
      onAdvance: () => _tutorialCoachMark?.next(),
      onFinish: onFinish,
    )..show(context: context);
  }

  Future<void> _scrollToTourTarget(GlobalKey keyTarget) async {
    final targetContext = keyTarget.currentContext;
    if (targetContext == null) {
      return;
    }

    await Scrollable.ensureVisible(
      targetContext,
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeInOut,
      alignment: 0.18,
    );
    await WidgetsBinding.instance.endOfFrame;
  }

  Future<void> _showTourStep(
    List<PaymentDetailsTourStep> steps,
    int index,
  ) async {
    if (!mounted || index >= steps.length) {
      return;
    }

    final step = steps[index];
    await _scrollToTourTarget(step.keyTarget);
    if (!mounted) {
      return;
    }

    _showTourSegment(
      target: step.target,
      onFinish: () {
        _showTourStep(steps, index + 1);
      },
    );
  }

  Future<void> _startTour() async {
    if (_isLoading || _details == null || !mounted) return;

    final steps = PaymentDetailsTourGuide.buildSteps(
      payTaxButtonKey: _keyPayTaxButton,
      printPropertyButtonKey: _keyPrintPropertyButton,
      addGrievanceButtonKey: _keyAddGrievanceButton,
      arvHistoryButtonKey: _keyArvHistoryButton,
      paymentHistoryButtonKey: _keyPaymentHistoryButton,
    );

    await _showTourStep(steps, 0);
  }

  void _handleTourTap() {
    if (_isLoading) {
      _showSnackBar('Tour will be available after payment details are loaded.');
      return;
    }

    if (_details == null) {
      _showSnackBar('Payment details are not available right now.');
      return;
    }

    _startTour();
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message, style: GoogleFonts.poppins())),
    );
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
      if (!mounted) return;

      setState(() => _isLoading = false);

      if (otpRes.success == true) {
        _showOtpAndPaymentDialog(mobileNo);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(otpRes.message ?? 'Failed to send OTP')),
        );
      }
    } catch (e) {
      if (!mounted) return;

      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            ApiService.getUserFriendlyErrorMessage(
              e,
              fallbackMessage:
                  'Unable to send OTP right now. Please try again.',
            ),
          ),
        ),
      );
    }
  }

  void _showOtpAndPaymentDialog(String mobileNo) {
    final otpController = TextEditingController();
    bool isVerifying = false;
    String? sheetError;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Container(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Verification Required',
                  style: GoogleFonts.poppins(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF333333),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Enter the OTP sent to $mobileNo to proceed with payment.',
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    color: Colors.grey.shade500,
                  ),
                ),
                const SizedBox(height: 16),
                if (sheetError != null) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.error_outline, color: Colors.red.shade600, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            sheetError!,
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: Colors.red.shade700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                Text(
                  'Enter OTP',
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade700,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: otpController,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  style: GoogleFonts.poppins(fontSize: 14, letterSpacing: 4),
                  decoration: InputDecoration(
                    hintText: '------',
                    hintStyle: GoogleFonts.poppins(fontSize: 13, color: Colors.grey.shade400),
                    prefixIcon: const Icon(Icons.pin_outlined, color: Color(0xFFE67514), size: 20),
                    counterText: '',
                    filled: true,
                    fillColor: const Color(0xFFF8F9FB),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade200),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFE67514), width: 1.5),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: isVerifying ? null : () async {
                      if (otpController.text.trim().isEmpty) {
                        setModalState(() => sheetError = 'Please enter OTP');
                        return;
                      }
                      if (otpController.text.length < 4) {
                        setModalState(() => sheetError = 'Please enter valid OTP');
                        return;
                      }
                      final sheetNavigator = Navigator.of(context);
                      setModalState(() {
                        isVerifying = true;
                        sheetError = null;
                      });
                      try {
                        final res = await ApiService.verifyOtp(mobileNo, otpController.text);
                        if (res.success == true) {
                          sheetNavigator.pop();
                          _handleCreateTransaction();
                        } else {
                          setModalState(() => sheetError = res.message ?? 'Invalid OTP');
                        }
                      } catch (e) {
                        setModalState(
                          () =>
                              sheetError = ApiService.getUserFriendlyErrorMessage(
                            e,
                            fallbackMessage:
                                'Unable to verify OTP right now. Please try again.',
                          ),
                        );
                      } finally {
                        if (mounted) setModalState(() => isVerifying = false);
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFE67514),
                      disabledBackgroundColor: const Color(0xFFE67514).withValues(alpha: 0.6),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: isVerifying
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : Text(
                            'Verify & Proceed',
                            style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700),
                          ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: isVerifying ? null : () => Navigator.pop(context),
                    child: Text(
                      'Cancel',
                      style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey.shade600),
                    ),
                  ),
                ),
              ],
            ),
            ),
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

      final response = await ApiService.initiateTransaction(request);
      if (!mounted) return;

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
        SnackBar(
          content: Text(
            ApiService.getUserFriendlyErrorMessage(
              e,
              fallbackMessage:
                  'Unable to create transaction right now. Please try again.',
            ),
          ),
        ),
      );
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
            _buildPaymentOptionCard('Pay with PayU', 'Safe & Secure', Icons.payment_rounded, () {
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
      final key = txnData.key;
      final txnid = txnData.txnid;
      final amount = txnData.amount;
      final productinfo = txnData.productinfo;
      final firstname = txnData.firstname;
      final email = txnData.email;
      final surl = txnData.surl;
      final furl = txnData.furl;

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

        await payu.openCheckoutScreen(
          payUPaymentParams: payUPaymentParams,
          payUCheckoutProConfig: payUCheckoutProConfig,
        );
      } catch (e) {
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              ApiService.getUserFriendlyErrorMessage(
                e,
                fallbackMessage:
                    'Unable to start PayU payment right now. Please try again.',
              ),
            ),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            ApiService.getUserFriendlyErrorMessage(
              e,
              fallbackMessage:
                  'Unable to start payment right now. Please try again.',
            ),
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
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
            Icon(icon, color: const Color(0xFFE67514), size: 28),
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

  Future<void> _printProperty() async {
    final bill = _details?.billDetails;
    final prop = _details?.propertyDetailsInfo;
    final owner = _details?.ownerDetails;

    final doc = pw.Document();

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context ctx) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Center(
                child: pw.Text(
                  'Property Tax Details',
                  style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold),
                ),
              ),
              pw.SizedBox(height: 4),
              pw.Center(
                child: pw.Text(
                  'Property ID: ${widget.propertyId}',
                  style: pw.TextStyle(fontSize: 12, color: PdfColors.grey700),
                ),
              ),
              pw.SizedBox(height: 16),
              pw.Divider(thickness: 1.5),
              pw.SizedBox(height: 10),
              pw.Text('Property Information',
                  style: pw.TextStyle(fontSize: 15, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 6),
              _buildPdfRow('Zone Name', prop?.zoneName ?? 'N/A'),
              _buildPdfRow('Ward Name', prop?.wardName ?? 'N/A'),
              _buildPdfRow('Mohalla Name', prop?.mohallaName ?? 'N/A'),
              _buildPdfRow('House No.', prop?.houseNo ?? 'N/A'),
              _buildPdfRow('Address', prop?.address ?? 'N/A'),
              pw.SizedBox(height: 12),
              pw.Divider(),
              pw.SizedBox(height: 8),
              pw.Text('Owner Information',
                  style: pw.TextStyle(fontSize: 15, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 6),
              _buildPdfRow('Owner Name', owner?.ownerName ?? 'N/A'),
              _buildPdfRow('Father Name', owner?.fatherName ?? 'N/A'),
              _buildPdfRow('Mobile No.', owner?.mobileNo ?? 'N/A'),
              pw.SizedBox(height: 12),
              pw.Divider(),
              pw.SizedBox(height: 8),
              pw.Text('Tax Summary',
                  style: pw.TextStyle(fontSize: 15, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 6),
              _buildPdfRow('Bill Date', bill?.billDate ?? 'N/A'),
              _buildPdfRow('Bill Number', bill?.billNo ?? 'N/A'),
              _buildPdfRow('Financial Year', bill?.finYear ?? 'N/A'),
              _buildPdfRow('House Tax Net Amount', 'Rs. ${bill?.houseTaxNetAmount ?? "0"}'),
              _buildPdfRow('Water Tax Net Amount', 'Rs. ${bill?.waterTaxNetAmount ?? "0"}'),
              _buildPdfRow('Sewer Tax Net Amount', 'Rs. ${bill?.sewerTaxNetAmount ?? "0"}'),
              _buildPdfRow('Other Tax Net Amount', 'Rs. ${bill?.othertaxNetAmount ?? "0"}'),
              _buildPdfRow('Water Charge Net Amount', 'Rs. ${bill?.waterChargeNetAmount ?? "0"}'),
              _buildPdfRow('Net Demand', 'Rs. ${bill?.netDemand ?? "0"}'),
              pw.SizedBox(height: 14),
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(width: 1.5),
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Net Payable',
                        style: pw.TextStyle(fontSize: 15, fontWeight: pw.FontWeight.bold)),
                    pw.Text('Rs. ${bill?.netPayble ?? "0"}',
                        style: pw.TextStyle(fontSize: 15, fontWeight: pw.FontWeight.bold)),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => doc.save(),
    );
  }

  pw.Widget _buildPdfRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 3),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Expanded(
            flex: 3,
            child: pw.Text(label,
                style: const pw.TextStyle(color: PdfColors.grey700)),
          ),
          pw.SizedBox(width: 8),
          pw.Expanded(
            flex: 4,
            child: pw.Text(value,
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        color: const Color(0xFFF5F5F5),
        child: SafeArea(
          child: Column(
            children: [
              Container(
                color: const Color(0xFFF5F5F5),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new_rounded,
                          color: Color(0xFFE67514), size: 20),
                      onPressed: () => Navigator.pop(context),
                    ),
                    Expanded(
                      child: Column(
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
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.help_outline_rounded,
                        color: Color(0xFFE67514),
                      ),
                      tooltip: 'Tour Guide',
                      onPressed: _handleTourTap,
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Container(
                  color: Colors.white,
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator(color: Color(0xFFE67514)))
                      : _errorMessage != null
                          ? _buildErrorState()
                          : _buildContent(),
                ),
              ),
            ],
          ),
        ),
      ),
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
                        color: const Color(0xFFFFF4E5),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.receipt_long_rounded, color: Color(0xFFE67514), size: 20),
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
                    color: const Color(0xFFFFF4E5),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFFFE0B2), width: 1),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Net Payable',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFFE67514),
                        ),
                      ),
                      Text(
                        '₹ ${bill?.netPayble ?? "0.0"}',
                        style: GoogleFonts.poppins(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFFE67514),
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
          _buildPrimaryButton(
            'Pay Your Tax Online',
            _handlePayTax,
            key: _keyPayTaxButton,
          ),
          const SizedBox(height: 12),
          Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: _buildSecondaryButton(
                      'Print Property',
                      Icons.print_outlined,
                      _printProperty,
                      key: _keyPrintPropertyButton,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildSecondaryButton(
                      'Add Grievance',
                      Icons.add_comment_outlined,
                      () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => PaymentGrievanceScreen(
                              propertyId: widget.propertyId,
                              propertyDetails: _details,
                            ),
                          ),
                        );
                      },
                      key: _keyAddGrievanceButton,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildSecondaryButton(
                      'ARV History',
                      Icons.history_rounded,
                      () {},
                      key: _keyArvHistoryButton,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildSecondaryButton(
                      'Payment History',
                      Icons.payment_rounded,
                      _showPaymentHistory,
                      key: _keyPaymentHistoryButton,
                    ),
                  ),
                ],
              ),
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
                    color: const Color(0xFFE67514),
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

  Widget _buildPrimaryButton(String text, VoidCallback onTap, {Key? key}) {
    return Container(
      key: key,
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

  Widget _buildSecondaryButton(
    String text,
    IconData icon,
    VoidCallback onTap, {
    Key? key,
  }) {
    return SizedBox(
      key: key,
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
