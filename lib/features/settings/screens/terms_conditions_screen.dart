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

            const Text(
              "Welcome to TheyDi",
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 10),

            const Text(
              "TheyDi is a location-based social event discovery, hosting, and ticketing platform operated by Vrutsa Solutions. By downloading, installing, accessing, registering on, or using the TheyDi mobile application, web application, or any related services, you agree to be legally bound by these Terms and Conditions and our Privacy Policy. If you do not agree with any part of these Terms, you must not use the Platform.",
              style: TextStyle(
                fontSize: 16,
                height: 1.7,
              ),
            ),

            const SizedBox(height: 28),

            _section(
              "1. Acceptance of Terms",
              [
                "These Terms constitute a legally binding electronic agreement under the Information Technology Act, 2000 and do not require any physical, electronic, or digital signature.",
                "Using the Platform in any way means you accept these Terms in full.",
              ],
            ),

            _section(
              "2. Eligibility",
              [
                "TheyDi is open to users of all ages for general use, including event discovery, creating a profile, joining social circles, and attending events listed on the Platform.",
                "If you are a minor (under 18), you should use the Platform only with the consent and supervision of a parent or legal guardian. By allowing a minor to use TheyDi, the parent or guardian accepts these Terms on the minor's behalf and takes responsibility for the minor's activity on the Platform.",
                "Users must provide accurate information about themselves, including date of birth, at the time of registration. Providing false information is a violation of these Terms and may result in account termination and reporting to relevant authorities.",
                "If you are accessing the Platform on behalf of a business or organisation, you represent that you have the authority to bind that entity to these Terms.",
                "To enter into paid transactions (booking paid tickets, hosting paid events, or receiving payouts), you must be legally competent to enter into a binding contract under the Indian Contract Act, 1872, which generally requires you to be 18 years or older. Users under 18 may use free features of the Platform but may not transact directly on the Platform. Any paid transaction on behalf of a minor must be carried out by their parent or legal guardian using their own account.",
                "Hosts are responsible for setting appropriate audience guidelines for their events (such as age suitability, dress code, or venue rules) and for ensuring that their events comply with all applicable laws.",
                "We reserve the right to refuse service, suspend accounts, or remove content at our sole discretion in accordance with these Terms.",
              ],
            ),

            _section(
              "3. Account Registration",
              [
                "You must provide accurate, current, and complete information including your name, email, phone number, date of birth, gender, city, and profile details.",
                "You may be required to verify your identity through OTP, email verification, and/or face liveness video verification — an active check requiring you to rotate your head and blink on camera to confirm a real, live person is present. Completing this step means you consent to capture and processing of your facial and video data as described in our Privacy Policy.",
                "You are solely responsible for keeping your login credentials confidential, for all activity under your account, and for notifying us immediately of unauthorised use.",
                "You must not create an account using false information, impersonate another person, or maintain multiple accounts without our permission.",
                "We reserve the right to suspend or terminate accounts that violate these Terms or that we suspect are fraudulent, inactive, or unsafe.",
              ],
            ),

            _section(
              "4. Nature of the Platform",
              [
                "TheyDi is an intermediary as defined under Section 2(1)(w) of the Information Technology Act, 2000, connecting event Hosts with Attendees, and enabling event discovery, listing, ticketing, social features, and payment collection/payouts.",
                "We are not an organiser, promoter, sponsor, or curator of events listed on the Platform unless explicitly stated. Events are created, managed, and hosted by Users.",
                "We do not verify the accuracy, safety, legality, or quality of events listed. Attendance is at your own risk.",
              ],
            ),

            _section(
              "5. User Conduct",
              [
                "You agree not to: post unlawful, obscene, defamatory, harassing, hateful, discriminatory, sexually explicit, or violent content.",
                "Host, promote, or attend events involving illegal activities (unlicensed alcohol, drugs, gambling, or anything prohibited under Indian law).",
                "Impersonate any person, or misrepresent your identity, age, or affiliation.",
                "Harass, stalk, threaten, or harm other Users, or collect their personal information without consent.",
                "Use bots, scrapers, or automated tools, or attempt unauthorised access to the Platform, accounts, or systems.",
                "Interfere with the Platform through malware, denial-of-service attacks, or exploits.",
                "Post spam or unsolicited advertisements, or engage in unauthorised commercial activity.",
                "Violate applicable Indian laws including the IT Act 2000, IT Rules 2021, Bharatiya Nyaya Sanhita 2023, and the DPDP Act 2023.",
                "Circumvent gender balance, age restrictions, or Host approval mechanisms, or resell/scalp tickets outside the Platform.",
                "You agree to treat all Users with respect and follow our published community guidelines.",
              ],
            ),

            _section(
              "6. Content and Intellectual Property",
              [
                "You retain ownership of content you submit (photos, event descriptions, messages, profile info, reviews). By submitting it, you grant Vrutsa Solutions a worldwide, non-exclusive, royalty-free licence to host, store, use, reproduce, modify, publish, and display it to operate and promote the Services.",
                "You represent that you own or have rights to all content you submit, and that it does not infringe third-party rights.",
                "The TheyDi name, logo, design, source code, and features are owned by Vrutsa Solutions and protected under Indian and international IP law. You may not copy, modify, or create derivative works without our written consent.",
              ],
            ),

            _section(
              "7. Events, Hosting & Attendance",
              [
                "Hosts are solely responsible for the legality, safety, accuracy, and conduct of their events, and must comply with all applicable licences, permissions, tax laws, and regulations (police permissions, fire safety, GST registration, municipal bylaws).",
                "Hosts must accurately describe the event including location, time, duration, capacity, age restrictions, gender balance, and risks, and are responsible for verifying attendee eligibility where required by law.",
                "Attendees participate in events at their own risk. TheyDi does not guarantee the safety of any venue, host, or attendee, and Attendees must comply with rules set by Hosts and venues.",
                "Some events require Host approval before attendance is confirmed; approval or rejection is at the Host's sole discretion, except where discrimination on protected grounds is alleged.",
              ],
            ),

            _section(
              "8. Payments, Ticketing & Refunds",
              [
                "Attendee ticket payments are processed by Razorpay Payment Gateway, subject to Razorpay's own terms. Host payouts are processed directly by Vrutsa Entertainment Private Limited via netbanking bulk transfers (NEFT/RTGS/IMPS) from our business bank account — we do not use any third-party payout aggregator for Host disbursements.",
                "Platform fee: approximately 10% (inclusive of applicable taxes) on ticket sales, deducted from Host payouts. Payment gateway fee: approximately 2%, charged by Razorpay. All fees are subject to GST; invoices provided where required.",
                "Attendee cancellations before the event starts: 90% refund of the ticket price; the remaining 10% is retained as a cancellation fee. No refund for no-shows or cancellations after the event starts. Gateway charges are non-refundable.",
                "Host cancellations: allowed only 24–48 hours before the event start (except emergencies/force majeure with our approval). When cancelled within the permitted window, all Attendees receive a full 100% refund. Repeated Host cancellations may lead to penalties, reduced rating, or suspension.",
                "Force majeure cancellations are handled per the applicable event policy and our discretion; documentation may be required.",
                "Approved refunds are processed within 7 days. Refund disputes must be raised within 7 days of the event date via in-app support or theydi.app@gmail.com.",
                "No refund where: the Attendee doesn't show up, is denied entry for failing event requirements, is removed for violating rules, or cancels after the event has started.",
                "Host payouts are initiated after successful event completion and are typically credited within 7 days (via NEFT/RTGS/IMPS), calculated as: Total ticket sales − Platform fee (~10%) − Payment gateway fee (~2%) − Refunds issued. Hosts must complete KYC (bank details) before payouts are released.",
                "We may withhold or delay payouts pending investigation of disputes, chargebacks, or Terms violations. If a Host cancels an event, no payout is due and Attendees are refunded in full.",
                "Hosts are solely responsible for reporting and paying income tax, GST, and other applicable taxes on their earnings.",
              ],
            ),

            _section(
              "9. Location Services",
              [
                "The Platform uses GPS and location services for event discovery, distance calculation, and location-based recommendations.",
                "By granting location permissions, you consent to the collection and processing of your location data as described in our Privacy Policy.",
                "You may disable location services through your device settings, though this may limit certain features.",
              ],
            ),

            _section(
              "10. Social Features",
              [
                "The Platform enables friend requests, direct messaging, event circles, and profile viewing.",
                "You are solely responsible for your interactions with other Users; we are not responsible for the conduct of any User.",
                "You may block or report other Users through in-app tools. We review reports and may take action including warnings, content removal, suspension, or reporting to law enforcement.",
              ],
            ),

            _section(
              "11. Prohibited Events",
              [
                "Events promoting hate speech, terrorism, communal violence, or discrimination.",
                "Events involving unlicensed sale of alcohol or controlled substances.",
                "Adult, sexual, or escort services.",
                "Gambling, betting, or fantasy sports without proper licences.",
                "Political rallies or events that may incite violence.",
                "Any activity prohibited under Indian law.",
                "Violation may result in immediate account termination and reporting to law enforcement.",
              ],
            ),

            _section(
              "12. Content Moderation & Grievance Redressal",
              [
                "In compliance with the IT (Intermediary Guidelines and Digital Media Ethics Code) Rules, 2021, grievances, complaints, and reports may be sent to theydi.app@gmail.com.",
                "Response time: acknowledgement within 24 hours; resolution within 15 days.",
                "Report unlawful content or harassment via in-app reporting or email.",
                "We may remove content or suspend accounts without prior notice where we determine a violation of these Terms or applicable law.",
              ],
            ),

            _section(
              "13. Third-Party Services",
              [
                "Firebase (Google)",
                "Google Maps",
                "Razorpay",
                "Other integrated service providers",
                "Your use of these services is subject to their respective terms. We are not responsible for their availability, accuracy, or reliability.",
              ],
            ),

            _section(
              "14. Disclaimers & Limitation of Liability",
              [
                "The Platform is provided on an 'AS IS' and 'AS AVAILABLE' basis without warranties of any kind, express or implied.",
                "We do not warrant that the Platform will be uninterrupted, error-free, secure, or virus-free.",
                "To the maximum extent permitted by law, we are not liable for indirect or consequential damages, loss of profits/data/goodwill, personal injury or death arising from event attendance, actions of Hosts/Attendees/third parties, unauthorised data access despite reasonable security, or third-party payment failures.",
                "Our total aggregate liability to you for any claim shall not exceed the fees you paid us in the 3 months preceding the claim, or ₹5,000, whichever is lower.",
                "Nothing in these Terms excludes liability that cannot be excluded under applicable Indian law.",
              ],
            ),

            const SizedBox(height: 10),

            _section(
              "15. Indemnification",
              [
                "You agree to indemnify, defend, and hold harmless Vrutsa Solutions, its officers, directors, employees, and agents from claims, damages, liabilities, costs, and legal fees arising from your use of the Platform, your violation of these Terms or any law or third-party rights, any event you host or attend, or any content you submit.",
              ],
            ),

            _section(
              "16. Suspension & Termination",
              [
                "We may suspend or terminate your account at any time, with or without notice, for violation of these Terms, fraudulent or illegal activity, extended inactivity, or requests from law enforcement.",
                "You may delete your account at any time through in-app settings. Certain data may be retained as described in our Privacy Policy or as required by law.",
                "Upon termination, your right to use the Platform ends immediately. Provisions on IP, indemnification, liability, and dispute resolution survive termination.",
              ],
            ),

            _section(
              "17. Modifications to the Terms",
              [
                "We may amend these Terms at any time. Material changes will be notified via in-app notification, email, or a prominent notice on the Platform.",
                "Continued use of the Platform after changes constitutes acceptance of the amended Terms.",
              ],
            ),

            _section(
              "18. Governing Law & Dispute Resolution",
              [
                "These Terms are governed by the laws of India.",
                "Disputes are first attempted to be resolved amicably through good-faith negotiation for 30 days.",
                
              ],
            ),

            _section(
              "19. Miscellaneous",
              [
                
                "Severability: invalid provisions do not affect the remaining Terms.",
                "Waiver: failure to enforce a provision does not waive our rights.",
                "Assignment: you may not assign your rights under these Terms; we may assign ours without your consent.",
                "Notices: sent to you via email or in-app notification; notices to us go to theydi.app@gmail.com.",
                "Force Majeure: we are not liable for delays or failures due to events beyond our reasonable control.",
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
                        "20. Contact Us",
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
                "By clicking \"I Agree\" or by continuing to use TheyDi, you acknowledge that you have read,\nunderstood and agreed to these Terms & Conditions.",
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