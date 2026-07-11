import 'package:flutter/material.dart';

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
            const Icon(
              Icons.privacy_tip_rounded,
              size: 70,
              color: Colors.teal,
            ),
            const SizedBox(height: 14),

            const Center(
              child: Text(
                "Privacy Policy",
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),

            const SizedBox(height: 8),

            Center(
              child: Text(
                "Your privacy matters to us.",
                style: TextStyle(
                  color: Colors.grey.shade700,
                  fontSize: 15,
                ),
              ),
            ),

            const SizedBox(height: 25),

            _buildCard(
              icon: Icons.info_outline,
              title: "Introduction",
              content:
                  "Welcome to TheyDi, operated by Vrutsa Solutions.\n\n"
                  "We value your privacy and are committed to protecting your personal information. "
                  "This Privacy Policy explains how we collect, use, store and protect your data when using TheyDi.",
            ),

            _buildCard(
              icon: Icons.person_outline,
              title: "Information We Collect",
              bullets: const [
                "Name & Display Name",
                "Email Address",
                "Phone Number",
                "Date of Birth",
                "Gender",
                "City",
                "Profile Photo",
                "Face Verification Data (if used)",
                "Event Information",
                "Payment Information (Razorpay)",
                "Friends & Chats",
                "Device Information",
                "Usage Analytics",
                "GPS Location (with permission)",
              ],
            ),

            _buildCard(
              icon: Icons.settings,
              title: "How We Use Your Information",
              bullets: const [
                "Create and manage your account",
                "Allow event booking & hosting",
                "Process payments",
                "Enable messaging features",
                "Improve app performance",
                "Detect fraud and misuse",
                "Verify user identity",
                "Send important notifications",
              ],
            ),

            _buildCard(
              icon: Icons.face_retouching_natural,
              title: "Face Verification",
              content:
                  "Facial data is collected only for identity verification.\n\n"
                  "It is never used for advertising, profiling or surveillance.\n\n"
                  "You may request deletion of your face verification data at any time.",
            ),

            _buildCard(
              icon: Icons.share_outlined,
              title: "Information Sharing",
              bullets: const [
                "Firebase",
                "Google Maps",
                "Razorpay",
                "RazorpayX",
                "Cloud Providers",
                "Legal Authorities (when required by law)",
              ],
            ),

            _buildCard(
              icon: Icons.location_on_outlined,
              title: "Location Information",
              content:
                  "With your permission, TheyDi uses GPS location to:\n\n"
                  "• Show nearby events\n"
                  "• Calculate event distance\n"
                  "• Improve recommendations\n\n"
                  "You can disable location permission anytime from your device settings.",
            ),

            _buildCard(
              icon: Icons.lock_outline,
              title: "Data Security",
              bullets: const [
                "HTTPS Encryption",
                "Secure Authentication",
                "Firebase Security Rules",
                "Password Hashing",
                "Access Controls",
              ],
            ),

            _buildCard(
              icon: Icons.storage,
              title: "Data Retention",
              content:
                  "Your information is stored only as long as required to provide our services or comply with Indian laws.\n\n"
                  "Some financial records may be retained according to legal requirements.",
            ),

            _buildCard(
              icon: Icons.verified_user_outlined,
              title: "Your Rights",
              bullets: const [
                "View your personal information",
                "Correct inaccurate information",
                "Request deletion",
                "Withdraw consent",
                "Contact our grievance officer",
              ],
            ),

            _buildCard(
              icon: Icons.cookie_outlined,
              title: "Cookies",
              bullets: const [
                "Login Sessions",
                "Analytics",
                "User Preferences",
              ],
            ),

            _buildCard(
              icon: Icons.update,
              title: "Policy Updates",
              content:
                  "We may update this Privacy Policy from time to time. Significant changes will be communicated through the app or email.",
            ),

            _buildCard(
              icon: Icons.email_outlined,
              title: "Contact Us",
              content:
                  "Vrutsa Solutions\n\nEmail:\n\n"
                  "theydi.app@gmail.com",
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