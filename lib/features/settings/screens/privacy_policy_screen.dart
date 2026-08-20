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
                color: Colors.teal.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(18),
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
                  const SizedBox(height: 8),
                  Text(
                    'Effective Date: August 20, 2026\nLast Updated: August 20, 2026',
                    textAlign: TextAlign.center,
                    style: TheyDiTextStyles.bodyLarge.copyWith(
                      color: TheyDiColors.textSecondary,
                      fontSize: 12,
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
                  "Contact Email: theydi.app@gmail.com\n\n"
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
              title: "2. Data Fiduciary",
              content:
                  "Vrutsa Solutions is the Data Fiduciary under the Digital Personal Data Protection Act, 2023 with respect to the personal data collected through TheyDi.\n\n"
                  "Contact for Data Protection and Grievances:\n\n"
                  "Email: theydi.app@gmail.com",
            ),
            const SizedBox(height: 18),

            _buildCard(
              icon: Icons.person_outline,
              title: "3. Information We Collect",
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
                "• Face liveness verification data — including a short video capturing head rotation and eye-blink actions (biometric — see Section 3.6)",

                "Event Data",
                "• Events you create (including location, description, images, capacity, pricing)",
                "• Events you book, attend, or express interest in",
                "• Reviews, ratings, and feedback",

                "Payment Data",
                "• Billing name and address",
                "• UPI ID, card details, or bank account details (processed via Razorpay— we do not store full card numbers or CVVs)",
                "• Transaction history",
                "• For Hosts:bank account number, IFSC, and KYC documents",

                "Social Interactions",
                "• Friend connections, circle memberships",
                "• Direct messages and chat content",
                "• Content posted in event circles",

                "Support Communications",
                "• Messages sent to customer support, grievance officer, or reports of misuse",
              ],
            ),
            const SizedBox(height: 18),

            _buildCard(
              icon: Icons.phone_android,
              title: "3.2 Information Collected Automatically",
              bullets: const [
                "Device Information: device model, OS version, unique device identifiers, IP address, browser type, mobile network information",
                "Usage Data: screens viewed, features used, time spent, clicks, search queries, referral source",
                "Location Data: GPS coordinates (with permission), approximate location from IP address",
                "Log Data: access logs, error logs, crash reports",
                "Cookies and Similar Technologies: session cookies, analytics identifiers",
              ],
            ),
            const SizedBox(height: 18),

            _buildCard(
              icon: Icons.cloud_outlined,
              title: "3.3 Information from Third Parties",
              bullets: const [
                "Firebase Authentication (Google): Authentication metadata",
                "Payment Providers (Razorpay): Transaction status, payout confirmation",
                "Google Maps Platform: Location resolution, geocoding, place details",
                "Social login providers (if enabled in future): Profile data as authorised by you",
              ],
            ),
            const SizedBox(height: 18),

            _buildCard(
              icon: Icons.lock_outline,
              title: "3.4 Sensitive Personal Data",
              content:
                  "Under the SPDI Rules and the Digital Personal Data Protection Act (DPDP Act), the following information is considered sensitive:",
              bullets: const [
                "Financial information (payment details, bank details)",
                "Biometric information (face verification data, if used)",
                "Passwords",
                "We handle such data with heightened security measures.",
              ],
            ),
            const SizedBox(height: 18),

            _buildCard(
              icon: Icons.child_care,
              title: "3.5 Children's Data",
              content:
                  "TheyDi is open to users of all ages. There are no age-restricted (18+) events on the Platform.\n\n"
                  "For users under 18, we process personal data only with the consent of a parent or legal guardian, in accordance with the Digital Personal Data Protection Act, 2023. We take the following measures to protect minors:",
              bullets: const [
                "We do not track, profile, or monitor minors for advertising or behavioural targeting",
                "We do not display targeted advertisements to minors",
                "Minors may use the free features of the Platform but cannot make paid bookings, host paid events, or receive payouts. Any paid transaction on behalf of a minor must be carried out by their parent or legal guardian using their own account",
                "Location data, chat data, and profile data of minors are processed only to the extent necessary to deliver core Platform features, and are subject to the same security and retention safeguards as adult users' data",
                "We rely on the date of birth provided at signup and on the supervising parent or guardian to determine and confirm the age of the user",
                "Parents or guardians who believe their child has provided data without appropriate consent, or who wish to review, correct, or delete their child's data, may contact us at theydi.app@gmail.com. We will act on such requests within the timelines set out in Section 10 of this Policy",
              ],
            ),
            const SizedBox(height: 18),

            _buildCard(
              icon: Icons.face_retouching_natural,
              title: "3.6 Biometric Data (Face Liveness Video Verification)",
              content:
                  "TheyDi uses a face liveness video verification system to confirm that the person creating or accessing an account is a real, live human being. This is an active biometric check — not just a static photo.",
              bullets: const [
                "What we capture: A short video (typically a few seconds) of your face while you perform simple movements such as rotating your head (left, right, up, down) and blinking your eyes. Facial feature vectors and liveness signals derived from this video (e.g. movement patterns, blink detection).",
                "Why we capture it: To prevent fake accounts, impersonation, deepfakes, and misuse of stolen photos. To increase trust and safety across the platform, especially for social events where users meet in person.",
                "How we use it: Solely for identity and liveness verification at the point of signup or re-verification. The verification result (pass/fail) is stored against your account; the underlying video and biometric data are handled per our retention policy (Section 9).",
                "How we protect it: Video and biometric data are transmitted over encrypted channels (HTTPS/TLS) and stored in encrypted form. Access is strictly restricted to verification and fraud-prevention personnel on a need-to-know basis. We do not use your facial data for advertising, profiling, surveillance, behavioural tracking, or training of third-party AI models. We do not sell or share your biometric data with any third party except our verification service provider (acting solely on our instructions), or where required by law, court order, or lawful request from a competent authority.",
                "Your rights: You may request access to, correction of, or deletion of your face liveness data at any time by writing to theydi.app@gmail.com. Deletion may result in loss of verified status on your account and may restrict access to certain features. You may withdraw consent to further biometric processing; however, this may prevent you from continuing to use features that require verification.",
                "Biometric data qualifies as Sensitive Personal Data under the SPDI Rules and receives the heightened security measures described in Section 8.",
              ],
            ),
            const SizedBox(height: 24),

            _buildCard(
              icon: Icons.settings,
              title: "4. How We Use Your Information",
              content: "We use your personal data for the following purposes:",
            ),
            const SizedBox(height: 18),

            _buildCard(
              icon: Icons.person_outline,
              title: "Providing the Service",
              bullets: const [
                "Creating and managing your account",
                "Enabling event discovery, booking and attendance",
                "Processing payments and payouts",
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
                "Detecting fraud, abuse and violations of Terms",
                "Investigating reports of misconduct",
                "Cooperating with law enforcement where legally required",
              ],
            ),
            const SizedBox(height: 18),

            _buildCard(
              icon: Icons.notifications_active_outlined,
              title: "Communication",
              bullets: const [
                "Sending transactional messages (booking confirmations, OTPs, payment receipts)",
                "Responding to support queries",
                "Sending service updates and policy changes",
                "With your consent, sending marketing communications (which you can opt out of)",
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
                "Complying with tax laws, KYC obligations, court orders, and government requests",
              ],
            ),
            const SizedBox(height: 24),

            _buildCard(
              icon: Icons.balance,
              title: "5. Legal Basis for Processing (DPDP Act)",
              content:
                  "Under the DPDP Act, we process personal data based on:",
              bullets: const [
                "Your consent, obtained at signup and for specific purposes such as location access, notifications, and marketing",
                "Legitimate uses as permitted under Section 7 of the DPDP Act including performance of contract, compliance with law, and responding to medical emergencies",
                "You may withdraw consent at any time as described in Section 10.",
              ],
            ),
            const SizedBox(height: 24),

            _buildCard(
              icon: Icons.share_outlined,
              title: "6. Sharing and Disclosure of Information",
              content:
                  "We do not sell your personal data. We share data only as follows:",
            ),
            const SizedBox(height: 18),

            _buildCard(
              icon: Icons.people_outline,
              title: "6.1 With Other Users",
              bullets: const [
                "Your profile information (name, photo, city, age, gender, event participation) is visible to other Users based on your privacy settings",
                "Hosts of events you book receive your name, contact information, and booking details",
                "Attendees you interact with through friend requests, circles, and messages see your profile",
              ],
            ),
            const SizedBox(height: 18),

            _buildCard(
              icon: Icons.cloud_outlined,
              title: "6.2 With Service Providers (Data Processors)",
              bullets: const [
                "Google Firebase (Authentication, Firestore Database, Cloud Functions, Cloud Storage, Analytics, Crashlytics)",
                "Google Cloud Platform (Maps, Directions, Geocoding, Places APIs)",
                "Razorpay (attendee payment processing)",
                "Face liveness verification provider (biometric verification, on our instructions only)",
                "Cloud hosting, email delivery, SMS/OTP, and analytics providers",
                "These providers are contractually obligated to protect your data and use it only for stated purposes.",
              ],
            ),
            const SizedBox(height: 18),

            _buildCard(
              icon: Icons.account_balance_wallet_outlined,
              title: "Host Payouts",
              content:
                  "Host payouts are processed directly by Vrutsa Entertainment Private Limited via netbanking bulk transfers from our business bank account and are not disbursed through any third-party payout aggregator. Your bank details are shared only with our own banking partner for the purpose of executing the transfer.",
            ),
            const SizedBox(height: 18),

            _buildCard(
              icon: Icons.policy_outlined,
              title: "6.3 For Legal Reasons",
              content: "We may disclose data to:",
              bullets: const [
                "Comply with laws, court orders, or legal processes",
                "Respond to lawful requests from law enforcement",
                "Protect our rights, property, or safety, or that of Users or the public",
                "Investigate fraud, security issues, or violations",
              ],
            ),
            const SizedBox(height: 18),

            _buildCard(
              icon: Icons.business_center_outlined,
              title: "6.4 Business Transfers",
              content:
                  "In case of merger, acquisition, restructuring, or sale of assets, your data may be transferred, subject to the acquirer honouring this Privacy Policy.",
            ),
            const SizedBox(height: 18),

            _buildCard(
              icon: Icons.verified_user_outlined,
              title: "6.5 With Your Consent",
              content:
                  "For any other disclosure, we will obtain your explicit consent.",
            ),
            const SizedBox(height: 24),

            _buildCard(
              icon: Icons.public,
              title: "7. Cross-Border Data Transfer",
              content:
                  "Some of our service providers (e.g., Google, Firebase) may store or process data outside India. Where cross-border transfer occurs, we ensure:",
              bullets: const [
                "Compliance with the DPDP Act (transfers only to countries not restricted by the Central Government)",
                "Appropriate contractual safeguards with providers",
                "Continued protection of your data",
              ],
            ),
            const SizedBox(height: 24),

            _buildCard(
              icon: Icons.lock_outline,
              title: "8. Data Security",
              content:
                  "We implement reasonable security measures under the SPDI Rules and DPDP Act including:",
              bullets: const [
                "Encryption of data in transit (HTTPS/TLS)",
                "Encryption of sensitive data at rest",
                "Password hashing using industry-standard algorithms",
                "Firebase Security Rules restricting unauthorised access",
                "Access controls limiting employee access on a need-to-know basis",
                "Regular security reviews and updates",
                "Secure payment handling via PCI-DSS compliant providers (Razorpay)",
              ],
            ),
            const SizedBox(height: 18),

            _buildCard(
              icon: Icons.warning_amber_rounded,
              title: "Security Notice",
              content:
                  "No system is completely secure. While we take reasonable measures, we cannot guarantee absolute security. You are responsible for keeping your login credentials confidential.",
            ),
            const SizedBox(height: 18),

            _buildCard(
              icon: Icons.notification_important_outlined,
              title: "Data Breach Notification",
              content:
                  "In case of a personal data breach affecting your rights, we will notify you and the Data Protection Board of India as required by the DPDP Act.",
            ),
            const SizedBox(height: 24),

            _buildCard(
              icon: Icons.storage_outlined,
              title: "9. Data Retention",
              content:
                  "We retain your personal data only as long as necessary for the purposes described:",
              bullets: const [
                "Account data (active users): Duration of account + 90 days after deletion",
                "Face liveness video and biometric data: Duration of account + 90 days after deletion (or until consent is withdrawn)",
                "Transaction records (payments, refunds, cancellations, payouts):as required by tax and accounting laws",
                "KYC records for Hosts (bank details): RBI / FIU-IND norms",
                "Chat and message history: Duration of account + 90 days after deletion",
                "Location history: 30 days (rolling)",
                "Log data: 12 months",
                "Marketing preferences: Until withdrawn",
                "Data required for legal, tax, fraud prevention, or dispute resolution purposes may be retained longer. Upon retention expiry, data is deleted or anonymised.",
              ],
            ),
            const SizedBox(height: 24),

            _buildCard(
              icon: Icons.gpp_good_outlined,
              title: "10. Your Rights (DPDP Act)",
              content:
                  "As a Data Principal under the DPDP Act, you have the following rights:",
              bullets: const [
                "Right to Access: Request a summary of personal data we process about you",
                "Right to Correction and Erasure: Correct inaccurate data or request deletion of data no longer needed",
                "Right to Withdraw Consent: Withdraw consent at any time. Withdrawal does not affect prior lawful processing",
                "Right to Nominate: Nominate another individual to exercise your rights in the event of death or incapacity",
                "Right to Grievance Redressal: File a complaint with our Grievance Officer, and thereafter with the Data Protection Board of India",

                "Exercise your rights through:",
                "• In-app: Settings → Privacy → Data Requests",
                "• Email: theydi.app@gmail.com",
                "We will respond within 30 days of a valid request. Identity verification may be required.",
              ],
            ),
            const SizedBox(height: 20),

            _buildCard(
              icon: Icons.cookie_outlined,
              title: "11. Cookies and Tracking Technologies",
              content:
                  "Our web application uses cookies and similar technologies for:",
              bullets: const [
                "Authentication and session management",
                "Remembering preferences",
                "Analytics (via Firebase Analytics, Google Analytics)",
                "Performance monitoring",
                "You can control cookies through browser settings. Disabling cookies may affect functionality.",
              ],
            ),
            const SizedBox(height: 20),

            _buildCard(
              icon: Icons.campaign_outlined,
              title: "12. Marketing Communications",
              content:
                  "With your consent, we may send promotional messages via email,push notification, or in-app messages. You may opt out at any time:",
              bullets: const [
                "Email: unsubscribe link",
                
                "Push notifications: Device settings",
                "In-app: Settings → Notifications",
                "Transactional messages (bookings, payments, security alerts) will continue regardless of marketing preferences.",
              ],
            ),
            const SizedBox(height: 20),

            _buildCard(
              icon: Icons.link_outlined,
              title: "13. Third-Party Links and Services",
              content:
                  "The Platform may contain links to third-party websites or services (event venues, sponsors, external content). We are not responsible for their privacy practices. Review their policies separately.",
            ),
            const SizedBox(height: 20),

            _buildCard(
              icon: Icons.auto_awesome_outlined,
              title: "14. Automated Decision-Making",
              content: "We may use algorithms for:",
              bullets: const [
                "Sorting events by distance and relevance",
                "Fraud detection",
                "Content recommendations",
                "We do not use fully automated decision-making that produces significant legal effects. Where automated decisions are made, human review is available on request.",
              ],
            ),
            const SizedBox(height: 20),

            _buildCard(
              icon: Icons.update,
              title: "15. Changes to This Policy",
              content:
                  "We may update this Privacy Policy from time to time. Material changes will be notified via:",
              bullets: const [
                "In-app notification",
                "Email to your registered address",
                "Prominent notice on the Platform",
                "Continued use after changes constitutes acceptance. If you disagree, discontinue use and delete your account.",
              ],
            ),
            const SizedBox(height: 20),

            _buildCard(
              icon: Icons.support_agent_outlined,
              title: "16. Grievance Redressal",
              content:
                  "If you have concerns about data handling, contact us:",
              bullets: const [
                "Email: theydi.app@gmail.com",
                "Acknowledgement: within 24 hours",
                "Resolution: within 15 days",
                "If unsatisfied, you may escalate to the Data Protection Board of India established under the DPDP Act.",
              ],
            ),
            const SizedBox(height: 20),

            _buildCard(
              icon: Icons.email_outlined,
              title: "17. Contact Us",
              content:
                  "Vrutsa Solutions\n\n"
                  "Email: theydi.app@gmail.com",
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
                  padding: const EdgeInsets.only(top: 8, bottom: 0),
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