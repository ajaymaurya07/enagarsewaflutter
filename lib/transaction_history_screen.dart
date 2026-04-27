import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';

import 'services/api_service.dart';
import 'services/storage_service.dart';
import 'transaction_details_screen.dart';
import 'tour_guides/transaction_history_tour.dart';

class TransactionHistoryScreen extends StatefulWidget {
  const TransactionHistoryScreen({super.key});

  @override
  State<TransactionHistoryScreen> createState() =>
      _TransactionHistoryScreenState();
}

class _TransactionHistoryScreenState extends State<TransactionHistoryScreen> {
  bool _isLoading = true;
  List<TransactionData> _transactions = [];
  String? _errorMessage;
  final GlobalKey _firstTransactionCardKey = GlobalKey();
  final GlobalKey _firstStatusBadgeKey = GlobalKey();

  TutorialCoachMark? _tutorialCoachMark;
  bool _isTourActive = false;
  bool _hasQueuedAutoTour = false;

  @override
  void initState() {
    super.initState();
    _fetchTransactions();
  }

  Future<void> _autoStartTourIfFirstVisit() async {
    final prefs = await SharedPreferences.getInstance();
    final seen = prefs.getBool('tour_transaction_history') ?? false;
    if (!seen && mounted) {
      await prefs.setBool('tour_transaction_history', true);
      await _startTour(showUnavailableMessage: false);
    }
  }

  void _showTourSegment({required TargetFocus target, VoidCallback? onFinish}) {
    _tutorialCoachMark = TransactionHistoryTourGuide.createCoachMark(
      targets: [target],
      onAdvance: () => _tutorialCoachMark?.next(),
      onFinish: onFinish,
      onSkip: _handleTourSkip,
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
      alignment: 0.2,
    );
    await WidgetsBinding.instance.endOfFrame;
  }

  Future<void> _showTourStep(
    List<TransactionHistoryTourStep> steps,
    int index,
  ) async {
    if (!mounted || index >= steps.length) {
      _resetTourState();
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

  Future<void> _startTour({bool showUnavailableMessage = true}) async {
    if (!mounted || _isTourActive) {
      return;
    }

    final steps = TransactionHistoryTourGuide.buildSteps(
      transactionCardKey: _firstTransactionCardKey,
      statusBadgeKey: _firstStatusBadgeKey,
    );

    if (steps.any((step) => step.keyTarget.currentContext == null)) {
      if (showUnavailableMessage) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Tour will be available once transaction records load.',
            ),
          ),
        );
      }
      return;
    }

    _isTourActive = true;
    await _showTourStep(steps, 0);
  }

  bool _handleTourSkip() {
    _resetTourState();
    return true;
  }

  void _resetTourState() {
    _isTourActive = false;
    _tutorialCoachMark = null;
  }

  void _openTransactionDetails(TransactionData txn) {
    if (_isTourActive) {
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TransactionDetailsScreen(transaction: txn),
      ),
    );
  }

  Future<void> _fetchTransactions() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final email = await StorageService.getEmailId();
      if (email == null || email.isEmpty) {
        setState(() {
          _errorMessage = "Email not found. Please log in again.";
          _isLoading = false;
        });
        return;
      }

      final response = await ApiService.getTransactionsByEmail(email);

      if (response.status == true) {
        setState(() {
          _transactions = response.data ?? [];
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = response.message ?? "Failed to load transactions";
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      appBar: AppBar(
        title: Text(
          'Transaction History',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(
              Icons.help_outline_rounded,
              color: Color(0xFFE67514),
            ),
            tooltip: 'Tour Guide',
            onPressed: _startTour,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _fetchTransactions,
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF0E3B90)),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error_outline_rounded,
                color: Colors.red,
                size: 60,
              ),
              const SizedBox(height: 16),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(color: Colors.black87),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _fetchTransactions,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0E3B90),
                ),
                child: const Text(
                  'Retry',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_transactions.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history_rounded, size: 80, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text(
              'No transactions found',
              style: GoogleFonts.poppins(
                fontSize: 16,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    if (!_hasQueuedAutoTour) {
      _hasQueuedAutoTour = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _autoStartTourIfFirstVisit();
        }
      });
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _transactions.length,
      itemBuilder: (context, index) {
        final txn = _transactions[index];
        return _buildTransactionCard(
          txn,
          cardKey: index == 0 ? _firstTransactionCardKey : null,
          statusBadgeKey: index == 0 ? _firstStatusBadgeKey : null,
        );
      },
    );
  }

  Widget _buildTransactionCard(
    TransactionData txn, {
    Key? cardKey,
    Key? statusBadgeKey,
  }) {
    final status = txn.transactionStatus?.toLowerCase() ?? '';
    final bool isSuccess = status == 'success' || status == 'captured';
    final bool isPending = status == 'pending';

    Color statusColor = Colors.red;
    Color bgColor = const Color(0xFFFFEBEE);
    IconData statusIcon = Icons.error_outline_rounded;

    if (isSuccess) {
      statusColor = Colors.green;
      bgColor = const Color(0xFFE8F5E9);
      statusIcon = Icons.check_circle_outline_rounded;
    } else if (isPending) {
      statusColor = const Color(0xFFE6A23C); // Amber/Yellow-ish
      bgColor = const Color(0xFFFFF7E6);
      statusIcon = Icons.access_time_rounded;
    }

    return GestureDetector(
      key: cardKey,
      onTap: () => _openTransactionDetails(txn),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: bgColor,
                  shape: BoxShape.circle,
                ),
                child: Icon(statusIcon, color: statusColor, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: Text(
                            '₹ ${txn.paymentAmount ?? "0.0"}',
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.poppins(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF333333),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          key: statusBadgeKey,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            txn.transactionStatus ?? 'Unknown',
                            style: GoogleFonts.poppins(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: statusColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'TXN ID: ${txn.txnId ?? "N/A"}',
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF444444),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      txn.dateTime ?? '',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
