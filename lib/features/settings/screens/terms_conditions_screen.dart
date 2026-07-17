import 'package:flutter/material.dart';

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
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: Colors.green.shade100),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Icon(
                    Icons.gavel_rounded,
                    color: Colors.green,
                    size: 34,
                  ),
                  SizedBox(height: 12),
                  Text(
                    "Terms & Conditions",
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 6),
                  Text(
                    "Effective Date: [Launch Date]\nLast Updated: [Last Updated Date]",
                    style: TextStyle(
                      color: Colors.black54,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 25),
            const Text(
              "Welcome to TheyDi.",
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              "By creating an account or using TheyDi, you agree to comply with these Terms & Conditions. Please read them carefully before using our platform.",
              style: TextStyle(
                height: 1.7,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 30),
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
              "7. Social Features",
              [
                "Add friends.",
                "Send messages.",
                "Join circles.",
                "Users are responsible for their interactions.",
              ],
            ),
            _section(
              "8. Prohibited Activities",
              [
                "Hate speech.",
                "Violence.",
                "Illegal activities.",
                "Fraud.",
                "Adult services.",
                "Unlicensed gambling.",
                "Sale of illegal substances.",
              ],
            ),
            _section(
              "9. Content Moderation",
              [
                "We may remove content violating these Terms.",
                "Accounts may be suspended without notice for serious violations.",
              ],
            ),
            _section(
              "10. Third-Party Services",
              [
                "Firebase",
                "Google Maps",
                "Razorpay",
                "RazorpayX",
              ],
            ),
            _section(
              "11. Limitation of Liability",
              [
                "Event cancellations.",
                "Third-party failures.",
                "Data loss.",
                "User disputes.",
                "Indirect damages.",
              ],
            ),
            _section(
              "12. Suspension & Termination",
              [
                "Fraud.",
                "Illegal activities.",
                "Violation of these Terms.",
                "Law enforcement requests.",
              ],
            ),
            _section(
              "13. Governing Law",
              [
                "These Terms are governed by the laws of India.",
              ],
            ),
            _section(
              "14. Changes",
              [
                "We may update these Terms from time to time.",
                "Continued use of TheyDi indicates acceptance of updated Terms.",
              ],
            ),
            const SizedBox(height: 30),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(15),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Contact Us",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 10),
                  Text(
                    "Vrutsa Solutions",
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(Icons.email_outlined, size: 18),
                      SizedBox(width: 8),
                      Text("theydi.app@gmail.com"),
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
