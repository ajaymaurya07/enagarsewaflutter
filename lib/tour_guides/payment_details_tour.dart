import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';

class PaymentDetailsTourStep {
  const PaymentDetailsTourStep({
    required this.keyTarget,
    required this.target,
  });

  final GlobalKey keyTarget;
  final TargetFocus target;
}

class PaymentDetailsTourGuide {
  static List<PaymentDetailsTourStep> buildSteps({
    required GlobalKey payTaxButtonKey,
    required GlobalKey printPropertyButtonKey,
    required GlobalKey addGrievanceButtonKey,
    required GlobalKey arvHistoryButtonKey,
    required GlobalKey paymentHistoryButtonKey,
  }) {
    return [
      _buildStep(
        identify: 'pay_tax_button',
        keyTarget: payTaxButtonKey,
        align: ContentAlign.top,
        icon: Icons.payments_outlined,
        title: 'Pay Your Tax Online',
        body:
            'Tap here to start the tax payment flow. An OTP will be sent to the registered mobile number before payment continues to the gateway.',
        radius: 16,
      ),
      _buildStep(
        identify: 'print_property_button',
        keyTarget: printPropertyButtonKey,
        align: ContentAlign.top,
        icon: Icons.print_outlined,
        title: 'Print Property',
        body:
            'Tap here to print or download the current property tax details for this property.',
        radius: 16,
      ),
      _buildStep(
        identify: 'add_grievance_button',
        keyTarget: addGrievanceButtonKey,
        align: ContentAlign.top,
        icon: Icons.add_comment_outlined,
        title: 'Add Grievance',
        body:
            'Use this button to raise a grievance related to payment or this property directly from the current screen.',
        radius: 16,
      ),
      _buildStep(
        identify: 'arv_history_button',
        keyTarget: arvHistoryButtonKey,
        align: ContentAlign.top,
        icon: Icons.history_rounded,
        title: 'ARV History',
        body:
            'Use this button to review ARV history related information for the selected property.',
        radius: 16,
      ),
      _buildStep(
        identify: 'payment_history_button',
        keyTarget: paymentHistoryButtonKey,
        align: ContentAlign.top,
        icon: Icons.payment_rounded,
        title: 'Payment History',
        body:
            'Tap here to view previous payment records and receipt history for this property.',
        radius: 16,
      ),
    ];
  }

  static TutorialCoachMark createCoachMark({
    required List<TargetFocus> targets,
    required VoidCallback onAdvance,
    VoidCallback? onFinish,
  }) {
    return TutorialCoachMark(
      targets: targets,
      colorShadow: const Color(0xFF111827),
      opacityShadow: 0.85,
      paddingFocus: 10,
      hideSkip: false,
      textSkip: 'SKIP TOUR',
      textStyleSkip: GoogleFonts.poppins(
        color: Colors.white,
        fontWeight: FontWeight.w600,
        fontSize: 13,
      ),
      onClickTarget: (target) => onAdvance(),
      onClickOverlay: (target) => onAdvance(),
      onFinish: onFinish,
    );
  }

  static PaymentDetailsTourStep _buildStep({
    required String identify,
    required GlobalKey keyTarget,
    required ContentAlign align,
    required IconData icon,
    required String title,
    required String body,
    double radius = 12,
  }) {
    return PaymentDetailsTourStep(
      keyTarget: keyTarget,
      target: TargetFocus(
        identify: identify,
        keyTarget: keyTarget,
        shape: ShapeLightFocus.RRect,
        radius: radius,
        contents: [
          TargetContent(
            align: align,
            builder: (context, controller) => _tourCard(
              icon: icon,
              title: title,
              body: body,
            ),
          ),
        ],
      ),
    );
  }

  static Widget _tourCard({
    required IconData icon,
    required String title,
    required String body,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF3E8),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: const Color(0xFFE67514), size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF111827),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            body,
            style: GoogleFonts.poppins(
              fontSize: 13,
              height: 1.5,
              color: const Color(0xFF4B5563),
            ),
          ),
        ],
      ),
    );
  }
}