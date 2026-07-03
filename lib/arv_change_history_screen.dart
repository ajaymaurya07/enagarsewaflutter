import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'services/api_service.dart';
import 'services/database_service.dart';

class ArvChangeHistoryScreen extends StatefulWidget {
  const ArvChangeHistoryScreen({super.key});

  @override
  State<ArvChangeHistoryScreen> createState() => _ArvChangeHistoryScreenState();
}

class _ArvChangeHistoryScreenState extends State<ArvChangeHistoryScreen> {
  static const _accent = Color(0xFFE67514);

  bool _isLoadingInit = false;
  bool _needsPropertySelect = false;
  bool _isOtpVerified = false;
  bool _isLoadingHistory = false;

  List<PropertyEntity> _properties = [];
  PropertyEntity? _selectedProperty;
  List<ArvChangeHistoryItem> _historyItems = [];
  bool _sortNewestFirst = true;
  final Set<String> _expandedKeys = {};
  String? _currentItemDate;

  String? _initError;
  String? _historyError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadProperties());
  }

  // ─── Flow ─────────────────────────────────────────────────────────────────

  Future<void> _loadProperties() async {
    setState(() {
      _isLoadingInit = true;
      _initError = null;
      _needsPropertySelect = false;
      _isOtpVerified = false;
      _historyItems = [];
      _historyError = null;
    });

    try {
      final props = await DatabaseService.getAllProperties();
      if (!mounted) return;

      if (props.isEmpty) {
        setState(() {
          _isLoadingInit = false;
          _initError = 'No property found. Please select a property first.';
        });
        return;
      }

      _properties = props;

      if (props.length == 1) {
        setState(() => _isLoadingInit = false);
        await _sendOtpForProperty(props.first);
      } else {
        setState(() {
          _isLoadingInit = false;
          _needsPropertySelect = true;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoadingInit = false;
        _initError = ApiService.getUserFriendlyErrorMessage(
          e,
          fallbackMessage: 'Something went wrong. Please try again.',
        );
      });
    }
  }

  Future<void> _sendOtpForProperty(PropertyEntity property) async {
    setState(() {
      _selectedProperty = property;
      _needsPropertySelect = false;
      _isLoadingInit = true;
      _initError = null;
    });

    try {
      final otpRes =
          await ApiService.sendOtp(property.phoneNumber, property.propertyId);
      if (!mounted) return;

      setState(() => _isLoadingInit = false);

      if (otpRes.success == true) {
        final ph = property.phoneNumber;
        final masked = otpRes.maskedMobile ??
            'XXXXXX${ph.length > 4 ? ph.substring(ph.length - 4) : ph}';
        _showOtpSheet(ph, property.propertyId, masked);
      } else {
        setState(() => _initError = otpRes.message ?? 'Failed to send OTP');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoadingInit = false;
        _initError = ApiService.getUserFriendlyErrorMessage(
          e,
          fallbackMessage: 'Unable to send OTP. Please try again.',
        );
      });
    }
  }

  void _showOtpSheet(
      String mobileNo, String propertyId, String maskedMobile) {
    final otpCtrl = TextEditingController();
    bool isVerifying = false;
    String? sheetError;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => StatefulBuilder(
        builder: (sheetCtx, setSheet) => Padding(
          padding:
              EdgeInsets.only(bottom: MediaQuery.of(sheetCtx).viewInsets.bottom),
          child: Container(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
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
                        borderRadius: BorderRadius.circular(2)),
                  ),
                ),
                const SizedBox(height: 22),

                // Info banner
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF4E5),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFFFE0B2)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.security_rounded,
                          color: _accent, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Verification Required',
                              style: GoogleFonts.poppins(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF333333)),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              'ARV change history is sensitive property data. Verify your mobile number to continue.',
                              style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  color: const Color(0xFF666666),
                                  height: 1.45),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                Text(
                  'Enter OTP',
                  style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF222222)),
                ),
                const SizedBox(height: 4),
                RichText(
                  text: TextSpan(
                    style: GoogleFonts.poppins(
                        fontSize: 12.5, color: Colors.grey.shade500),
                    children: [
                      const TextSpan(text: 'A 6-digit code was sent to '),
                      TextSpan(
                        text: maskedMobile,
                        style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF333333)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),

                if (sheetError != null) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.red.shade200)),
                    child: Row(
                      children: [
                        Icon(Icons.error_outline,
                            color: Colors.red.shade600, size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(sheetError!,
                              style: GoogleFonts.poppins(
                                  fontSize: 12, color: Colors.red.shade700)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                ],

                TextField(
                  controller: otpCtrl,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                      fontSize: 20,
                      letterSpacing: 10,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF222222)),
                  decoration: InputDecoration(
                    hintText: '– – – – – –',
                    hintStyle: GoogleFonts.poppins(
                        fontSize: 13,
                        color: Colors.grey.shade300,
                        letterSpacing: 4),
                    counterText: '',
                    filled: true,
                    fillColor: const Color(0xFFF8F9FB),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none),
                    enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(color: Colors.grey.shade200)),
                    focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide:
                            const BorderSide(color: _accent, width: 1.5)),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 16),
                  ),
                ),
                const SizedBox(height: 24),

                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: isVerifying
                        ? null
                        : () async {
                            if (otpCtrl.text.trim().isEmpty) {
                              setSheet(
                                  () => sheetError = 'Please enter the OTP');
                              return;
                            }
                            if (otpCtrl.text.trim().length < 4) {
                              setSheet(() =>
                                  sheetError = 'Please enter a valid OTP');
                              return;
                            }
                            setSheet(() {
                              isVerifying = true;
                              sheetError = null;
                            });
                            final sheetNav = Navigator.of(sheetCtx);
                            try {
                              final res = await ApiService.verifyOtp(
                                  mobileNo, otpCtrl.text.trim());
                              if (!mounted) return;
                              if (res.success == true) {
                                if (mounted) {
                                  setState(() => _isOtpVerified = true);
                                }
                                sheetNav.pop();
                                await _fetchArvHistory(propertyId);
                              } else {
                                setSheet(() =>
                                    sheetError =
                                        res.message ?? 'Invalid OTP');
                              }
                            } catch (e) {
                              if (!mounted) return;
                              setSheet(() => sheetError =
                                  ApiService.getUserFriendlyErrorMessage(e,
                                      fallbackMessage:
                                          'Unable to verify OTP. Please try again.'));
                            } finally {
                              if (mounted) setSheet(() => isVerifying = false);
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _accent,
                      disabledBackgroundColor: _accent.withValues(alpha: 0.55),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    child: isVerifying
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.white)),
                          )
                        : Text('Verify OTP',
                            style: GoogleFonts.poppins(
                                fontSize: 15, fontWeight: FontWeight.w700)),
                  ),
                ),
                const SizedBox(height: 10),

                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: isVerifying
                        ? null
                        : () => Navigator.of(sheetCtx).pop(),
                    child: Text('Cancel',
                        style: GoogleFonts.poppins(
                            fontSize: 14, color: Colors.grey.shade500)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ).then((_) {
      if (mounted && !_isOtpVerified) Navigator.of(context).pop();
    });
  }

  Future<void> _fetchArvHistory(String propertyId) async {
    setState(() {
      _isLoadingHistory = true;
      _historyError = null;
      _historyItems = [];
      _expandedKeys.clear();
    });

    try {
      final res = await ApiService.getArvChangeHistory(propertyId);
      if (!mounted) return;

      if (res.success == true) {
        final items = res.data ?? [];
        setState(() {
          _historyItems = items;
          _isLoadingHistory = false;
          _currentItemDate =
              items.isNotEmpty ? items.first.arvChangeDate : null;
          // all cards expanded by default
          for (int i = 0; i < items.length; i++) {
            _expandedKeys.add(_itemKey(items[i], i));
          }
        });
      } else {
        setState(() {
          _isLoadingHistory = false;
          _historyError = res.message ?? 'Failed to fetch ARV history';
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoadingHistory = false;
        _historyError = ApiService.getUserFriendlyErrorMessage(e,
            fallbackMessage:
                'Unable to load ARV history. Please try again.');
      });
    }
  }

  String _itemKey(ArvChangeHistoryItem item, int idx) =>
      '${item.arvChangeDate ?? idx}_${item.oldArv}_${item.currentArv}';

  List<ArvChangeHistoryItem> get _displayItems => _sortNewestFirst
      ? List.from(_historyItems)
      : _historyItems.reversed.toList();

  // ─── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        title: Text(
          'ARV Change History',
          style: GoogleFonts.poppins(
              fontWeight: FontWeight.w700,
              fontSize: 18,
              color: const Color(0xFF222222)),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: _accent, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoadingInit) {
      return const Center(child: CircularProgressIndicator(color: _accent));
    }
    if (_initError != null) return _buildInitError();
    if (_needsPropertySelect) return _buildPropertySelect();
    if (!_isOtpVerified) return const SizedBox.shrink();
    if (_isLoadingHistory) {
      return const Center(child: CircularProgressIndicator(color: _accent));
    }
    if (_historyError != null) return _buildHistoryError();
    return _buildContent();
  }

  // ── Init error ─────────────────────────────────────────────────────────────

  Widget _buildInitError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline_rounded,
                size: 64, color: Colors.red.shade300),
            const SizedBox(height: 16),
            Text(_initError!,
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                    height: 1.5)),
            const SizedBox(height: 28),
            ElevatedButton(
              onPressed: _loadProperties,
              style: ElevatedButton.styleFrom(
                  backgroundColor: _accent,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 28, vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12))),
              child: Text('Try Again',
                  style:
                      GoogleFonts.poppins(fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
  }

  // ── Property selection ─────────────────────────────────────────────────────

  Widget _buildPropertySelect() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Select Property',
                  style: GoogleFonts.poppins(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF222222))),
              const SizedBox(height: 4),
              Text(
                "Choose which property's ARV change history you want to view.",
                style: GoogleFonts.poppins(
                    fontSize: 12.5,
                    color: Colors.grey.shade500,
                    height: 1.4),
              ),
            ],
          ),
        ),
        Divider(height: 1, color: Colors.grey.shade200),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
            itemCount: _properties.length,
            itemBuilder: (context, i) =>
                _buildPropertySelectCard(_properties[i]),
          ),
        ),
      ],
    );
  }

  Widget _buildPropertySelectCard(PropertyEntity p) {
    return GestureDetector(
      onTap: () => _sendOtpForProperty(p),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 10,
                offset: const Offset(0, 4))
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                  color: const Color(0xFFFFF4E5),
                  borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.home_work_outlined,
                  color: _accent, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(p.propertyId,
                      style: GoogleFonts.poppins(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF222222))),
                  const SizedBox(height: 3),
                  Text(p.ownerName,
                      style: GoogleFonts.poppins(
                          fontSize: 12, color: Colors.grey.shade500)),
                  if (p.ward.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text('Ward: ${p.ward}',
                        style: GoogleFonts.poppins(
                            fontSize: 11, color: Colors.grey.shade400)),
                  ],
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios_rounded,
                size: 14, color: Colors.grey.shade400),
          ],
        ),
      ),
    );
  }

  // ── History error ──────────────────────────────────────────────────────────

  Widget _buildHistoryError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.history_toggle_off_rounded,
                size: 64, color: Colors.red.shade300),
            const SizedBox(height: 16),
            Text(_historyError!,
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                    height: 1.5)),
            const SizedBox(height: 28),
            ElevatedButton(
              onPressed: _selectedProperty != null
                  ? () => _fetchArvHistory(_selectedProperty!.propertyId)
                  : null,
              style: ElevatedButton.styleFrom(
                  backgroundColor: _accent,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 28, vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12))),
              child: Text('Retry',
                  style:
                      GoogleFonts.poppins(fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
  }

  // ── Main content ───────────────────────────────────────────────────────────

  Widget _buildContent() {
    final items = _displayItems;

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(child: _buildPropertyInfoCard()),
        SliverToBoxAdapter(child: _buildSectionHeader(items.length)),
        if (items.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.history_rounded,
                      size: 64, color: Colors.grey.shade300),
                  const SizedBox(height: 12),
                  Text('No Records Found',
                      style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade400)),
                  const SizedBox(height: 4),
                  Text('No ARV change history for this property.',
                      style: GoogleFonts.poppins(
                          fontSize: 12, color: Colors.grey.shade400)),
                ],
              ),
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, i) =>
                    _buildTimelineItem(items[i], i, items.length),
                childCount: items.length,
              ),
            ),
          ),
      ],
    );
  }

  // ── Property info card ─────────────────────────────────────────────────────

  Widget _buildPropertyInfoCard() {
    final p = _selectedProperty;
    final first =
        _historyItems.isNotEmpty ? _historyItems.first : null;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 12,
              offset: const Offset(0, 4))
        ],
      ),
      child: Column(
        children: [
          _infoRow(
            _infoCell('Property ID',
                p?.propertyId ?? first?.propertyId ?? '—',
                isBlue: true),
            _infoCell('House No.', first?.houseNo ?? '—'),
          ),
          const SizedBox(height: 12),
          _infoRow(
            _infoCell('Owner Name',
                p?.ownerName ?? first?.ownerName ?? '—'),
            _infoCell(
                'Current ARV',
                first?.currentArv != null
                    ? '${first!.currentArv}'
                    : '—'),
          ),
          const SizedBox(height: 12),
          _infoRow(
            _infoCell('Property Address',
                p?.address ?? first?.address ?? '—'),
            _infoCell('Language', first?.ulbLanguage ?? '—'),
          ),
        ],
      ),
    );
  }

  Row _infoRow(Widget l, Widget r) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [Expanded(child: l), Expanded(child: r)],
      );

  Widget _infoCell(String label, String value, {bool isBlue = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: GoogleFonts.poppins(
                fontSize: 10.5, color: Colors.grey.shade500)),
        const SizedBox(height: 2),
        Text(
          value,
          style: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: isBlue
                  ? const Color(0xFF1565C0)
                  : const Color(0xFF222222)),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  // ── Section header ─────────────────────────────────────────────────────────

  Widget _buildSectionHeader(int count) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
      child: Row(
        children: [
          Text(
            'ARV Change History ($count)',
            style: GoogleFonts.poppins(
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF222222)),
          ),
          const Spacer(),
          GestureDetector(
            onTap: () =>
                setState(() => _sortNewestFirst = !_sortNewestFirst),
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.swap_vert_rounded,
                      size: 13, color: Colors.grey.shade600),
                  const SizedBox(width: 4),
                  Text(
                    'Sort: ${_sortNewestFirst ? "Newest First" : "Oldest First"}',
                    style: GoogleFonts.poppins(
                        fontSize: 11,
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w500),
                  ),
                  Icon(Icons.keyboard_arrow_down_rounded,
                      size: 13, color: Colors.grey.shade600),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Timeline item ──────────────────────────────────────────────────────────

  Widget _buildTimelineItem(
      ArvChangeHistoryItem item, int idx, int total) {
    final isFirst = idx == 0;
    final isLast = idx == total - 1;
    final isCurrent = item.arvChangeDate == _currentItemDate;
    final key = _itemKey(item, idx);
    final isExpanded = _expandedKeys.contains(key);

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Timeline column ──
          SizedBox(
            width: 44,
            child: Column(
              children: [
                Container(
                  width: 2,
                  height: isCurrent ? 16 : 23,
                  color: isFirst
                      ? Colors.transparent
                      : Colors.grey.shade300,
                ),
                isCurrent
                    ? Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          color: Colors.green.shade500,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.arrow_upward_rounded,
                            color: Colors.white, size: 16),
                      )
                    : Container(
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade600,
                          shape: BoxShape.circle,
                        ),
                      ),
                Expanded(
                  child: Container(
                    width: 2,
                    color: isLast
                        ? Colors.transparent
                        : Colors.grey.shade300,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 8),

          // ── Card ──
          Expanded(
            child: Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 8,
                      offset: const Offset(0, 3))
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Card header
                  Padding(
                    padding:
                        const EdgeInsets.fromLTRB(14, 12, 14, 10),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            'ARV Updated',
                            style: GoogleFonts.poppins(
                                fontSize: 13.5,
                                fontWeight: isCurrent
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                                color: isCurrent
                                    ? const Color(0xFF222222)
                                    : Colors.grey.shade700),
                          ),
                        ),
                        if (isCurrent)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.green.shade50,
                              borderRadius:
                                  BorderRadius.circular(20),
                              border: Border.all(
                                  color: Colors.green.shade400,
                                  width: 1),
                            ),
                            child: Text(
                              'Current',
                              style: GoogleFonts.poppins(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.green.shade700),
                            ),
                          ),
                      ],
                    ),
                  ),

                  // Expandable details
                  if (isExpanded) ...[
                    Divider(
                        height: 1, color: Colors.grey.shade100),
                    Padding(
                      padding:
                          const EdgeInsets.fromLTRB(14, 2, 14, 0),
                      child: Column(
                        children: [
                          _detailRow(
                              'Old ARV', '${item.oldArv ?? 0}'),
                          Divider(
                              height: 1,
                              color: Colors.grey.shade100),
                          _detailRow(
                              'New ARV', '${item.currentArv ?? 0}'),
                          Divider(
                              height: 1,
                              color: Colors.grey.shade100),
                          _detailRow(
                              'Changed By',
                              item.ownerName ?? '—'),
                          Divider(
                              height: 1,
                              color: Colors.grey.shade100),
                          _detailRow(
                              'Change Date',
                              item.arvChangeDate ?? '—'),
                          Divider(
                              height: 1,
                              color: Colors.grey.shade100),
                          _detailRow(
                              'ULB ID',
                              '${item.ulbId ?? "—"}',
                              highlight: true),
                        ],
                      ),
                    ),
                  ],

                  // Expand / collapse toggle
                  GestureDetector(
                    onTap: () => setState(() {
                      if (_expandedKeys.contains(key)) {
                        _expandedKeys.remove(key);
                      } else {
                        _expandedKeys.add(key);
                      }
                    }),
                    child: Container(
                      width: double.infinity,
                      padding:
                          const EdgeInsets.symmetric(vertical: 7),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.vertical(
                          top: isExpanded
                              ? Radius.zero
                              : const Radius.circular(12),
                          bottom: const Radius.circular(12),
                        ),
                      ),
                      child: Center(
                        child: Icon(
                          isExpanded
                              ? Icons.keyboard_arrow_up_rounded
                              : Icons.keyboard_arrow_down_rounded,
                          color: Colors.grey.shade400,
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value, {bool highlight = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: GoogleFonts.poppins(
                  fontSize: 12.5, color: Colors.grey.shade500),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: GoogleFonts.poppins(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: highlight
                      ? const Color(0xFF1565C0)
                      : const Color(0xFF222222)),
            ),
          ),
        ],
      ),
    );
  }
}
