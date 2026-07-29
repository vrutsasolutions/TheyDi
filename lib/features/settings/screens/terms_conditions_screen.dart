import 'package:flutter/material.dart';
import 'package:theydi/core/theme/app_theme.dart';

class TermsConditionsScreen extends StatelessWidget {
  const TermsConditionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xffF8FAFC),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        centerTitle: true,
        title: const Text(
          'Terms & Conditions',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
  width: double.infinity,
  padding: const EdgeInsets.all(22),
  decoration: BoxDecoration(
    color: Colors.green.shade50,
    borderRadius: BorderRadius.circular(18),
    border: Border.all(color: Colors.green.shade100),
  ),
  child: Column(
  children: [
    Container(
      width: 90,
      height: 90,
      decoration: BoxDecoration(
        color: TheyDiColors.primary.withValues(alpha: .08),
        shape: BoxShape.circle,
      ),
      child: const Icon(
        Icons.gavel_rounded,
        size: 42,
        color: TheyDiColors.primary,
      ),
    ),
    const SizedBox(height: 16),
    Text(
      'Please read these terms carefully before using TheyDi.',
      textAlign: TextAlign.center,
      style: TheyDiTextStyles.bodyLarge.copyWith(
        color: TheyDiColors.textSecondary,
      ),
    ),
    const SizedBox(height: 12),
    // Text(
    //   'Effective Date: [Launch Date]\nLast Updated: [Last Updated Date]',
    //   textAlign: TextAlign.center,
    //   style: TheyDiTextStyles.bodySmall.copyWith(
    //     color: TheyDiColors.textMuted,
    //   ),
    // ),
  ],
),
),

const SizedBox(height: 24),

const Text(
  "Welcome to TheyDi",
  style: TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.bold,
  ),
),

const SizedBox(height: 10),

const Text(
  "By creating an account or using TheyDi, you agree to comply with these Terms & Conditions. Please read them carefully before using our platform.",
  style: TextStyle(
    fontSize: 16,
    height: 1.7,
  ),
),

const SizedBox(height: 28),

_section(
  "1. Eligibility",
  [
    "Users must provide accurate and truthful information.",
    "Age or identity verification may be required for certain services.",
  ],
),

_section(
  "2. User Accounts",
  [
    "Keep your login credentials secure.",
    "You are responsible for all activities under your account.",
    "Notify us immediately if you suspect unauthorized access.",
  ],
),

_section(
  "3. Events",
  [
    "Create events.",
    "Join events.",
    "Purchase tickets.",
    "Host communities.",
    "Hosts are responsible for event accuracy.",
  ],
),

_section(
  "4. Payments",
  [
    "Payments are securely processed using Razorpay.",
    "Refunds depend on the cancellation policy.",
    "Host payouts are released after successful event completion.",
  ],
),

_section(
  "5. Face Verification",
  [
    "Face verification may be required for selected features.",
    "Verification is used only for identity confirmation.",
  ],
),

_section(
  "6. Location Services",
  [
    "Location helps discover nearby events.",
    "Improves recommendations.",
    "Permission can be disabled anytime.",
  ],
),
            _section(
  "7. Events, Hosting & Attendance",
  [
    "Hosts are responsible for the legality, safety, and accuracy of their events.",
    "Hosts must comply with all applicable licences, permissions, and Indian laws.",
    "Attendees participate in events at their own risk.",
    "Some events require host approval before attendance is confirmed.",
  ],
),

_section(
  "8. Payments, Ticketing & Refunds",
  [
    "Payments are securely processed using Razorpay.",
    "Host payouts are processed through razorpayX or Cashfree.",
    "Platform fee (~10%) and payment gateway charges apply.",
    "Attendee cancellations receive a 90% refund before the event starts.",
    "Host cancellations within the allowed period receive a full attendee refund.",
    "Approved refunds are processed within 7 days.",
    "Hosts receive payouts after successful event completion.",
  ],
),

_section(
  "9. Location Services",
  [
    "GPS is used for nearby event discovery and recommendations.",
    "Location data is processed according to our Privacy Policy.",
    "Location permission can be disabled anytime from device settings.",
  ],
),

_section(
  "10. Social Features",
  [
    "Add friends and connect with other users.",
    "Send direct messages.",
    "Join event circles and communities.",
    "Users are responsible for their own interactions.",
    "You may block or report other users at any time.",
  ],
),

_section(
  "11. Prohibited Events",
  [
    "Hate speech or discriminatory events.",
    "Illegal drugs or unlicensed alcohol.",
    "Adult or escort services.",
    "Illegal gambling or betting.",
    "Political events promoting violence.",
    "Any activity prohibited under Indian law.",
  ],
),

_section(
  "12. Content Moderation & Grievance",
  [
    "Content violating these Terms may be removed.",
    "Accounts may be suspended or terminated for serious violations.",
    "Report issues through the app or email: theydi.app@gmail.com.",
    "Acknowledgement within 24 hours and resolution within 15 days.",
  ],
),

_section(
  "13. Third-Party Services",
  [
    "Firebase",
    "Google Maps",
    "Razorpay",
    "RazorpayX",
    "Other integrated service providers",
  ],
),

_section(
  "14. Disclaimer & Limitation of Liability",
  [
    "The Platform is provided on an 'AS IS' basis.",
    "We do not guarantee uninterrupted or error-free service.",
    "We are not responsible for user disputes or third-party failures.",
    "Liability is limited to the maximum extent permitted under Indian law.",
  ],
),
            const SizedBox(height: 30),
            _section(
  "15. Indemnification",
  [
    "You agree to indemnify and hold Vrutsa Solutions harmless from claims arising from your use of the Platform.",
    "This includes violations of these Terms, applicable laws, third-party rights, hosted events, or submitted content.",
  ],
),

_section(
  "16. Suspension & Termination",
  [
    "Accounts may be suspended or terminated for violations of these Terms.",
    "Fraudulent or illegal activities may result in immediate termination.",
    "Users may delete their account through app settings.",
    "Certain information may be retained as required by law.",
  ],
),

_section(
  "17. Changes to the Terms",
  [
    "We may update these Terms from time to time.",
    "Material changes will be communicated through the app or email.",
    "Continued use of TheyDi indicates acceptance of the updated Terms.",
  ],
),

_section(
  "18. Governing Law & Dispute Resolution",
  [
    "These Terms are governed by the laws of India.",
    "Disputes should first be resolved through mutual discussion.",
    "If unresolved, disputes may be referred to arbitration under Indian law.",
    "Courts at [Insert City] shall have exclusive jurisdiction.",
  ],
),

_section(
  "19. Miscellaneous",
  [
    "These Terms together with the Privacy Policy form the complete agreement.",
    "Invalid provisions do not affect the remaining Terms.",
    "Failure to enforce a provision does not waive our rights.",
    "We may assign our rights and obligations when required.",
    "Force majeure events may delay or affect our services.",
  ],
),

const SizedBox(height: 20),

Container(
  width: double.infinity,
  padding: const EdgeInsets.all(20),
  decoration: BoxDecoration(
    color: Colors.grey.shade100,
    borderRadius: BorderRadius.circular(16),
    border: Border.all(color: Colors.grey.shade300),
  ),
  child: const Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          Icon(
            Icons.contact_mail_rounded,
            color: Colors.green,
            size: 24,
          ),
          SizedBox(width: 10),
          Text(
            "Contact Us",
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
      SizedBox(height: 16),
      Text(
        "Vrutsa Solutions",
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
      SizedBox(height: 10),
      Row(
        children: [
          Icon(
            Icons.email_outlined,
            size: 18,
            color: Colors.black54,
          ),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              "theydi.app@gmail.com",
              style: TextStyle(fontSize: 15),
            ),
          ),
        ],
      ),
    ],
  ),
),
            const SizedBox(height: 30),
            Center(
              child: Text(
                "By using TheyDi, you acknowledge that you have read,\nunderstood and agreed to these Terms & Conditions.",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.grey.shade700,
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  static Widget _section(String title, List<String> points) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 26),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          ...points.map(
            (e) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "• ",
                    style: TextStyle(fontSize: 18),
                  ),
                  Expanded(
                    child: Text(
                      e,
                      style: const TextStyle(
                        height: 1.6,
                        fontSize: 16,
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
}
