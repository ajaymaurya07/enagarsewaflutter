import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';
import 'services/api_service.dart';
import 'services/database_service.dart';
import 'payment_details_screen.dart';
import 'tour_guides/property_tax_tour.dart';

class PropertyTaxScreen extends StatefulWidget {
  const PropertyTaxScreen({super.key});

  @override
  State<PropertyTaxScreen> createState() => _PropertyTaxScreenState();
}

class _PropertyTaxScreenState extends State<PropertyTaxScreen> {
  final _keyFirstPropertyCard = GlobalKey();

  List<PropertyEntity> _savedProperties = [];
  bool _isLoading = true;
  TutorialCoachMark? _tutorialCoachMark;

  @override
  void initState() {
    super.initState();
    _loadProperties();
  }

  Future<void> _loadProperties() async {
    setState(() => _isLoading = true);
    try {
      final properties = await DatabaseService.getAllProperties();
      if (!mounted) return;

      setState(() {
        _savedProperties = properties;
        _isLoading = false;
      });

      await WidgetsBinding.instance.endOfFrame;
      await _autoStartTourIfFirstVisit();
    } catch (e) {
      if (!mounted) return;

      setState(() => _isLoading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(
        SnackBar(
          content: Text(
            ApiService.getUserFriendlyErrorMessage(
              e,
              fallbackMessage:
                  'Unable to load properties right now. Please try again.',
            ),
          ),
        ),
      );
    }
  }

  Future<void> _autoStartTourIfFirstVisit() async {
    if (_savedProperties.isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    final seen = prefs.getBool('tour_property_tax') ?? false;
    if (!seen && mounted) {
      await prefs.setBool('tour_property_tax', true);
      _startTour();
    }
  }

  void _startTour() {
    if (_savedProperties.isEmpty || !mounted) return;

    final targets = PropertyTaxTourGuide.buildTargets(
      propertyCardKey: _keyFirstPropertyCard,
    );

    _tutorialCoachMark = PropertyTaxTourGuide.createCoachMark(
      targets: targets,
      onAdvance: () => _tutorialCoachMark?.next(),
    )..show(context: context);
  }

  void _handleTourTap() {
    if (_isLoading) {
      _showSnackBar('Tour will be available after properties are loaded.');
      return;
    }

    if (_savedProperties.isEmpty) {
      _showSnackBar('Add or verify a property first to view this tour.');
      return;
    }

    _startTour();
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message, style: GoogleFonts.poppins())),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surfaceContainerLowest,
      appBar: AppBar(
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        elevation: 0,
        toolbarHeight: 70,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: colorScheme.onSurface,
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'My Properties',
          style: GoogleFonts.poppins(
            color: colorScheme.onSurface,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
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
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: colorScheme.primary))
          : _savedProperties.isEmpty
          ? _buildEmptyState()
          : ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
              itemCount: _savedProperties.length,
              itemBuilder: (context, index) {
                return _buildPropertyCard(
                  _savedProperties[index],
                  isPrimaryTourCard: index == 0,
                );
              },
            ),
    );
  }

  Widget _buildEmptyState() {
    final colorScheme = Theme.of(context).colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: colorScheme.surface,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 20,
                  ),
                ],
              ),
              child: Icon(
                Icons.home_work_outlined,
                size: 64,
                color: colorScheme.outline,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'No properties added yet',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Your verified properties will appear here for quick access.',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPropertyCard(
    PropertyEntity property, {
    bool isPrimaryTourCard = false,
  }) {
    final colorScheme = Theme.of(context).colorScheme;

    return GestureDetector(
      key: isPrimaryTourCard ? _keyFirstPropertyCard : null,
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) =>
                PaymentDetailsScreen(propertyId: property.propertyId),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 20),
        decoration: BoxDecoration(
          color: colorScheme.surface,
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
            // Header Part
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.location_city_rounded,
                      color: colorScheme.primary,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'PID: ${property.propertyId}',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: colorScheme.onSurface,
                      ),
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: colorScheme.onSurfaceVariant,
                    size: 20,
                  ),
                ],
              ),
            ),
            Divider(
              height: 1,
              thickness: 0.8,
              color: colorScheme.outlineVariant,
            ),

            // Details Part
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  _buildModernDetailRow('Owner', property.ownerName),
                  const SizedBox(height: 12),
                  _buildModernDetailRow('Ward', property.ward),
                  const SizedBox(height: 12),
                  _buildModernDetailRow('Mohalla', property.mohalla),
                  const SizedBox(height: 12),
                  _buildModernDetailRow('Mobile', property.phoneNumber),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModernDetailRow(String label, String value) {
    final colorScheme = Theme.of(context).colorScheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 80, // Fixed width for labels to align values
          child: Text(
            '$label:',
            style: GoogleFonts.poppins(
              fontSize: 13,
              color: colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 13,
              color: colorScheme.onSurface,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}
