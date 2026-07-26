import 'package:flutter/material.dart';
import 'package:theydi/core/theme/app_theme.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Privacy Policy',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
  width: double.infinity,
  padding: const EdgeInsets.symmetric(
    horizontal: 24,
    vertical: 30,
  ),
  decoration: BoxDecoration(
    color: Colors.teal.withOpacity(0.08),
    borderRadius: BorderRadius.circular(18),
  ),
  child: Column(
  children: [
    Container(
      width: 90,
      height: 90,
      decoration: BoxDecoration(
        color: TheyDiColors.primary.withOpacity(.08),
        shape: BoxShape.circle,
      ),
      child: const Icon(
        Icons.privacy_tip_rounded,
        size: 42,
        color: TheyDiColors.primary,
      ),
    ),
    const SizedBox(height: 16),
    Text(
      'Your privacy matters to us.',
      style: TheyDiTextStyles.bodyLarge.copyWith(
        color: TheyDiColors.textSecondary,
      ),
    ),
  ],
),
),
const SizedBox(height: 24),
            _buildCard(
  icon: Icons.info_outline,
  title: "Introduction",
  content:
      "Application: TheyDi\n"
      "Operated by: Vrutsa Solutions\n"
      "Contact Email: theydi.app@gmail.com\n"
      
      "Vrutsa Solutions (\"we\", \"us\", \"our\") operates the TheyDi mobile application, web application, and related services (collectively, the \"Platform\"). This Privacy Policy explains how we collect, use, disclose, store and protect your personal data when you use TheyDi.\n\n"
      "This Privacy Policy is issued in compliance with:\n\n"
      "• Information Technology Act, 2000\n"
      "• Information Technology (Reasonable Security Practices and Procedures and Sensitive Personal Data or Information) Rules, 2011\n"
      "• Digital Personal Data Protection Act, 2023 (DPDP Act)\n"
      "• Information Technology (Intermediary Guidelines and Digital Media Ethics Code) Rules, 2021\n\n"
      "By using the Platform, you consent to the collection and use of your personal data as described in this Privacy Policy.",
),
const SizedBox(height: 18),

_buildCard(
  icon: Icons.business,
  title: "Data Fiduciary",
  content:
      "Vrutsa Solutions is the Data Fiduciary under the Digital Personal Data Protection Act, 2023 with respect to the personal data collected through TheyDi.\n\n"
      "Contact for Data Protection and Grievances:\n\n"
      "Email: theydi.app@gmail.com",
),
            _buildCard(
  icon: Icons.person_outline,
  title: "Information We Collect",
  content:
      "We collect the following categories of information from users of the TheyDi Platform.",
),

const SizedBox(height: 18),

_buildCard(
  icon: Icons.account_circle_outlined,
  title: "3.1 Information You Provide Directly",
  bullets: const [
    "Account Registration",
    "• Full name and display name",
    "• Email address",
    "• Phone number",
    "• Date of birth",
    "• Gender",
    "• City of residence",
    "• Password (stored in encrypted, hashed form)",
    "• Profile photo and additional photos",
    "• Face verification data (biometric)",
  
    "Event Data",
    "• Events you create (location, description, images, pricing, capacity)",
    "• Events you book, attend or express interest in",
    "• Reviews, ratings and feedback",
  
    "Payment Data",
    "• Billing name and address",
    "• UPI ID, card or bank details (processed securely through Razorpay/razorpayX or Cashfree)",
    "• Transaction history",
    "• PAN, IFSC, bank account and KYC documents for Hosts",

    "Social Interactions",
    "• Friend connections",
    "• Circle memberships",
    "• Direct messages and chat content",
    "• Circle posts",

    "Support Communications",
    "• Messages sent to customer support",
    "• Grievance reports",
    "• Misuse reports",
  ],
),

const SizedBox(height: 18),

_buildCard(
  icon: Icons.phone_android,
  title: "3.2 Information Collected Automatically",
  bullets: const [
    "Device Information (device model, OS version, identifiers, IP address, browser, network)",
    "Usage Data (screens viewed, clicks, searches, time spent, referrals)",
    "Location Data (GPS with permission and approximate IP location)",
    "Log Data (access logs, crash reports and error logs)",
    "Cookies and similar technologies for analytics and sessions",
  ],
),

const SizedBox(height: 18),

_buildCard(
  icon: Icons.cloud_outlined,
  title: "3.3 Information from Third Parties",
  bullets: const [
    "Firebase Authentication (Google)",
    "Razorpay & razorpayX or Cashfree transaction status",
    "Google Maps Platform services",
    "Future social login providers (if enabled)",
  ],
),

const SizedBox(height: 18),

_buildCard(
  icon: Icons.lock_outline,
  title: "3.4 Sensitive Personal Data",
  content:
      "Under the SPDI Rules and the Digital Personal Data Protection Act (DPDP Act), the following information is considered sensitive:",
  bullets: const [
    "Financial information",
    "Bank and payment details",
    "Biometric information (face verification data)",
    "Passwords",
    "We protect this information using enhanced security measures.",
  ],
),

const SizedBox(height: 18),

_buildCard(
  icon: Icons.child_care,
  title: "3.5 Children's Data",
  content:
      "TheyDi is available to users of all ages. However, age-restricted (18+) events and paid transactions are only available to users aged 18 years or above.\n\nFor users under 18, personal data is processed only with the consent of a parent or legal guardian as required by the DPDP Act.",
  bullets: const [
    "No behavioural profiling of minors",
    "No targeted advertising to minors",
    "No access to 18+ events",
    "No paid bookings or host payouts for minors",
    "Parents may request review or deletion of a child's data by contacting theydi.app@gmail.com",
  ],
),

const SizedBox(height: 18),

_buildCard(
  icon: Icons.face_retouching_natural,
  title: "3.6 Biometric Data (Face Verification)",
  content:
      "Where face verification is used, facial data is processed solely for identity verification. It is not used for surveillance or profiling and is not shared with third parties except where required by law. Users may request deletion of this data at any time.",
),
            _buildCard(
  icon: Icons.settings,
  title: "4. How We Use Your Information",
  content:
      "We use your personal data for the following purposes:",
),

const SizedBox(height: 18),

_buildCard(
  icon: Icons.person_outline,
  title: "Providing the Service",
  bullets: const [
    "Creating and managing your account",
    "Enabling event discovery, booking and attendance",
    "Processing payments and host payouts",
    "Enabling social features, friend connections and messaging",
    "Sending event confirmations, reminders and notifications",
  ],
),

const SizedBox(height: 18),

_buildCard(
  icon: Icons.location_on_outlined,
  title: "Location-Based Features",
  bullets: const [
    "Showing nearby events sorted by distance",
    "Providing directions to event venues",
    "Calculating radius-based recommendations",
  ],
),

const SizedBox(height: 18),

_buildCard(
  icon: Icons.security,
  title: "Safety and Security",
  bullets: const [
    "Verifying user identity",
    "Detecting fraud, abuse and violations of our Terms",
    "Investigating reports of misconduct",
    "Cooperating with law enforcement where legally required",
  ],
),

const SizedBox(height: 18),

_buildCard(
  icon: Icons.notifications_active_outlined,
  title: "Communication",
  bullets: const [
    "Sending booking confirmations and payment receipts",
    "Sending OTPs and security notifications",
    "Responding to support requests",
    "Sending service updates and policy changes",
    "Sending marketing communications with your consent (opt-out available)",
  ],
),

const SizedBox(height: 18),

_buildCard(
  icon: Icons.analytics_outlined,
  title: "Improving the Platform",
  bullets: const [
    "Analytics and product improvement",
    "Debugging and error resolution",
    "Research and development",
  ],
),

const SizedBox(height: 18),

_buildCard(
  icon: Icons.gavel_outlined,
  title: "Legal Compliance",
  bullets: const [
    "Complying with tax laws",
    "Meeting KYC obligations",
    "Responding to court orders and lawful government requests",
  ],
),

const SizedBox(height: 24),

_buildCard(
  icon: Icons.balance,
  title: "5. Legal Basis for Processing (DPDP Act)",
  content:
      "Under the Digital Personal Data Protection Act (DPDP Act), we process your personal data based on the following legal grounds:",
  bullets: const [
    "Your consent obtained during signup and for specific permissions such as location, notifications and marketing.",
    "Legitimate uses permitted under Section 7 of the DPDP Act, including performance of contract, compliance with law and responding to medical emergencies.",
    "You may withdraw your consent at any time as described in the 'Your Rights' section.",
  ],
),

const SizedBox(height: 24),

_buildCard(
  icon: Icons.share_outlined,
  title: "6. Sharing and Disclosure of Information",
  content:
      "We do not sell your personal data. We share information only in the following circumstances:",
),

const SizedBox(height: 18),

_buildCard(
  icon: Icons.people_outline,
  title: "6.1 With Other Users",
  bullets: const [
    "Your profile information is visible according to your privacy settings.",
    "Event hosts receive your booking details.",
    "Friends and circle members can view information you choose to share.",
  ],
),

const SizedBox(height: 18),

_buildCard(
  icon: Icons.cloud_outlined,
  title: "6.2 With Service Providers",
  bullets: const [
    "Google Firebase (Authentication, Firestore, Storage, Cloud Functions, Analytics, Crashlytics)",
    "Google Cloud Platform (Maps, Directions, Geocoding, Places APIs)",
    "Razorpay (Payment Processing)",
    "razorpayX or Cashfree(Host Payouts)",
    "Cloud hosting, email delivery, SMS/OTP and analytics providers",
    "These providers are contractually obligated to protect your information.",
  ],
),

const SizedBox(height: 18),

_buildCard(
  icon: Icons.policy_outlined,
  title: "6.3 For Legal Reasons",
  bullets: const [
    "Comply with laws and legal processes",
    "Respond to lawful requests from authorities",
    "Protect the rights, safety and property of Users and the Platform",
    "Investigate fraud, abuse and security incidents",
  ],
),

const SizedBox(height: 18),

_buildCard(
  icon: Icons.business_center_outlined,
  title: "6.4 Business Transfers",
  content:
      "In the event of a merger, acquisition, restructuring or sale of assets, your information may be transferred, provided the acquiring party continues to honour this Privacy Policy.",
),

const SizedBox(height: 18),

_buildCard(
  icon: Icons.verified_user_outlined,
  title: "6.5 With Your Consent",
  content:
      "For any disclosure not covered above, we will obtain your explicit consent before sharing your personal information.",
),

const SizedBox(height: 24),

_buildCard(
  icon: Icons.public,
  title: "7. Cross-Border Data Transfer",
  content:
      "Some service providers such as Google and Firebase may process or store data outside India.",
  bullets: const [
    "Transfers comply with the Digital Personal Data Protection Act (DPDP Act).",
    "Data is transferred only to jurisdictions permitted under applicable law.",
    "Appropriate contractual safeguards are maintained with service providers.",
    "We continue to ensure the security and protection of your personal information.",
  ],
),
           
            _buildCard(
  icon: Icons.lock_outline,
  title: "8. Data Security",
  content:
      "We implement reasonable security measures under the SPDI Rules and the Digital Personal Data Protection Act (DPDP Act) to protect your personal information.",
  bullets: const [
    "Encryption of data in transit (HTTPS/TLS)",
    "Encryption of sensitive data at rest",
    "Password hashing using industry-standard algorithms",
    "Firebase Security Rules restricting unauthorised access",
    "Access controls on a need-to-know basis",
    "Regular security reviews and updates",
    "Secure payment handling through PCI-DSS compliant providers (Razorpay)",
  ],
),

const SizedBox(height: 18),

_buildCard(
  icon: Icons.warning_amber_rounded,
  title: "Security Notice",
  content:
      "No system is completely secure. While we take reasonable measures to protect your information, we cannot guarantee absolute security. Please keep your login credentials confidential.",
),

const SizedBox(height: 18),

_buildCard(
  icon: Icons.notification_important_outlined,
  title: "Data Breach Notification",
  content:
      "If a personal data breach affects your rights, we will notify you and the Data Protection Board of India as required under the DPDP Act.",
),

const SizedBox(height: 24),

_buildCard(
  icon: Icons.storage_outlined,
  title: "9. Data Retention",
  content:
      "We retain your personal data only for as long as necessary to fulfil the purposes described in this Privacy Policy.",
  bullets: const [
    "Account data: Duration of account + 90 days after deletion",
    "Transaction records: 8 years",
    "Host KYC records: 5 years after last transaction",
    "Chat & message history: Duration of account + 90 days",
    "Location history: 30 days",
    "Log data: 12 months",
    "Marketing preferences: Until consent is withdrawn",
    "Grievance records: 3 years",
    "Data may be retained longer where required by law or for fraud prevention and dispute resolution.",
    "Expired data is securely deleted or anonymised.",
  ],
),

const SizedBox(height: 24),

_buildCard(
  icon: Icons.gpp_good_outlined,
  title: "10. Your Rights (DPDP Act)",
  content:
      "As a Data Principal under the Digital Personal Data Protection Act (DPDP Act), you have the following rights:",
  bullets: const [
    "Right to Access your personal data",
    "Right to Correction and Erasure of inaccurate or unnecessary data",
    "Right to Withdraw Consent at any time",
    "Right to Nominate another individual to exercise your rights",
    "Right to Grievance Redressal",
    
    "Exercise your rights through:",
    "• Settings → Privacy → Data Requests",
    "• Email: theydi.app@gmail.com",
    "We will respond within 30 days of a valid request. Identity verification may be required.",
  ],
),
            _buildCard(
  icon: Icons.cookie_outlined,
  title: "11. Cookies and Tracking Technologies",
  content:
      "Our web application uses cookies and similar technologies to improve your experience.",
  bullets: const [
    "Authentication and session management",
    "Remembering user preferences",
    "Analytics (Firebase Analytics & Google Analytics)",
    "Performance monitoring",
    "You can control cookies through your browser settings. Disabling cookies may affect certain features.",
  ],
),

const SizedBox(height: 20),

_buildCard(
  icon: Icons.campaign_outlined,
  title: "12. Marketing Communications",
  content:
      "With your consent, we may send promotional communications through various channels.",
  bullets: const [
    "Email (unsubscribe link available)",
    "SMS (Reply STOP to opt out)",
    "WhatsApp messages",
    "Push notifications",
    "In-app notifications",
    "Transactional messages such as booking confirmations, payment receipts and security alerts will continue regardless of marketing preferences.",
  ],
),

const SizedBox(height: 20),

_buildCard(
  icon: Icons.link_outlined,
  title: "13. Third-Party Links and Services",
  content:
      "The Platform may contain links to third-party websites, sponsors, event venues or external services. We are not responsible for their privacy practices. Please review their respective Privacy Policies before sharing your personal information.",
),

const SizedBox(height: 20),

_buildCard(
  icon: Icons.auto_awesome_outlined,
  title: "14. Automated Decision-Making",
  content:
      "We use automated systems to improve your experience on TheyDi.",
  bullets: const [
    "Sorting events by distance and relevance",
    "Fraud detection",
    "Content recommendations",
    "We do not use fully automated decision-making that produces significant legal effects. Human review is available upon request.",
  ],
),
           _buildCard(
  icon: Icons.update,
  title: "15. Changes to This Policy",
  content:
      "We may update this Privacy Policy from time to time. Material changes will be communicated through the following channels:",
  bullets: const [
    "In-app notifications",
    "Email to your registered address",
    "Prominent notice on the Platform",
    "Continued use of TheyDi after such updates constitutes acceptance of the revised Privacy Policy.",
    "If you disagree with any changes, you should discontinue using the Platform and delete your account.",
  ],
),

const SizedBox(height: 20),

_buildCard(
  icon: Icons.support_agent_outlined,
  title: "16. Grievance Redressal",
  content:
      "If you have any concerns regarding the collection, use or protection of your personal data, please contact us.",
  bullets: const [
    "Email: theydi.app@gmail.com",
    "Acknowledgement: Within 24 hours",
    "Resolution: Within 15 days",
    "If you are not satisfied with our response, you may escalate the matter to the Data Protection Board of India under the DPDP Act.",
  ],
),

const SizedBox(height: 20),

_buildCard(
  icon: Icons.email_outlined,
  title: "17. Contact Us",
  content:
      "Vrutsa Solutions\n\n"
      "Email: theydi.app@gmail.com\n\n"
      "By using TheyDi, you acknowledge that you have read and understood this Privacy Policy.",
),
            const SizedBox(height: 25),
            Center(
              child: Text(
                "By using TheyDi, you acknowledge that you have read and understood this Privacy Policy.",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.grey.shade700,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _buildCard({
    required IconData icon,
    required String title,
    String? content,
    List<String>? bullets,
  }) {
    return Card(
      elevation: 3,
      margin: const EdgeInsets.only(bottom: 18),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: Colors.teal),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 19,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            if (content != null)
              Text(
                content,
                style: const TextStyle(
                  height: 1.6,
                  fontSize: 15,
                ),
              ),
            if (bullets != null)
              ...bullets.map(
                (e) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.check_circle,
                        color: Colors.teal,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          e,
                          style: const TextStyle(
                            fontSize: 15,
                            height: 1.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
