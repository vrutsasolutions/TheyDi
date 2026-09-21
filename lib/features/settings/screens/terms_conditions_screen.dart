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
        title: const Text('Terms & Conditions', style: TextStyle(fontWeight: FontWeight.bold)),
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
                    child: const Icon(Icons.gavel_rounded, size: 42, color: TheyDiColors.primary),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Please read these terms carefully before using TheyDi.',
                    textAlign: TextAlign.center,
                    style: TheyDiTextStyles.bodyLarge.copyWith(color: TheyDiColors.textSecondary),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Effective Date: August 20, 2026\nLast Updated: September 21, 2026',
                    textAlign: TextAlign.center,
                    style: TheyDiTextStyles.bodyLarge.copyWith(color: TheyDiColors.textSecondary, fontSize: 12),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            const Text("Welcome to TheyDi", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            const Text(
              "TheyDi is a social network for discovering people, communities, organizations, and real-world experiences — operated by Vrutsa Solutions. TheyDi serves both individuals (Social and Professional users) and organizations (companies, institutions, entertainment groups, communities, and more) within the same platform. By downloading, installing, accessing, registering on, or using the TheyDi mobile application, web application, or any related services, you agree to be legally bound by these Terms and Conditions and our Privacy Policy. If you do not agree with any part of these Terms, you must not use the Platform.",
              style: TextStyle(fontSize: 16, height: 1.7),
            ),

            const SizedBox(height: 28),

            _section("1. Acceptance of Terms", const [
              "These Terms constitute a legally binding electronic agreement under the Information Technology Act, 2000 and do not require any physical, electronic, or digital signature.",
              "Using the Platform in any way means you accept these Terms in full.",
            ]),

            _section("2. Eligibility", const [
              "TheyDi is open to users of all ages for general use, including experience discovery, creating a profile, joining communities, following organizations, and attending experiences listed on the Platform.",
              "If you are a minor (under 18), you should use the Platform only with the consent and supervision of a parent or legal guardian. By allowing a minor to use TheyDi, the parent or guardian accepts these Terms on the minor's behalf and takes responsibility for the minor's activity on the Platform.",
              "Users must provide accurate information about themselves, including date of birth, at the time of registration. Providing false information is a violation of these Terms and may result in account termination.",
              "If you are accessing the Platform on behalf of a business, institution, or organisation, you represent that you have the authority to bind that entity to these Terms.",
              "To enter into paid transactions (booking paid tickets, hosting paid experiences, creating paid organization events, or receiving payouts), you must be legally competent to enter into a binding contract under the Indian Contract Act, 1872 (generally 18 years or older).",
              "Hosts and Organizations are responsible for setting appropriate audience guidelines for their experiences and for ensuring that all activities comply with applicable laws.",
              "We reserve the right to refuse service, suspend accounts, or remove content at our sole discretion in accordance with these Terms.",
            ]),

            _section("3. Account Registration", const [
              "You must provide accurate, current, and complete information including your name, email, phone number, date of birth, gender, city, and profile details.",
              "You may optionally provide professional identity information including your profession, company or organization name, industry, skills, and social links. This information is used to enable professional discovery and networking features.",
              "You may be required to verify your identity through OTP, email verification, and/or face liveness video verification. Completing this step means you consent to capture and processing of your facial and video data as described in our Privacy Policy.",
              "You are solely responsible for keeping your login credentials confidential, for all activity under your account, and for notifying us immediately of unauthorised use.",
              "You must not create an account using false information, impersonate another person, or maintain multiple accounts without our permission.",
              "We reserve the right to suspend or terminate accounts that violate these Terms.",
            ]),

            _section("4. Nature of the Platform", const [
              "TheyDi is an intermediary as defined under Section 2(1)(w) of the Information Technology Act, 2000, operating a social network that connects individuals, communities, and organizations through shared experiences.",
              "TheyDi serves both B2C (individual users discovering social and professional experiences) and B2B2C (organizations building communities, creating experiences, and reaching relevant audiences) on the same platform. The 'experience' (event) is the bridge connecting both sides.",
              "We are not an organiser, promoter, sponsor, or curator of experiences listed on the Platform unless explicitly stated. Experiences are created, managed, and hosted by Users and Organizations.",
              "We do not verify the accuracy, safety, legality, or quality of experiences listed. Attendance is at your own risk.",
            ]),

            _section("5. Organizations", const [
              "Any verified user may create an Organization profile on TheyDi representing a company, institution, entertainment group, NGO, sports body, professional group, college/university, online community, or any other recognized entity.",
              "One user account may own or manage multiple Organizations. You do not need a separate account for each Organization.",
              "The Organization owner is responsible for all content, experiences, and communities created under that Organization's profile. The owner may add admin users who share this responsibility.",
              "Organizations must accurately represent their identity, nature, and purpose. Creating a fraudulent or misleading Organization profile is a violation of these Terms and may result in removal and legal action.",
              "Organization followers, members, and community participants are users who have chosen to engage with that Organization. Their data is processed as described in our Privacy Policy.",
              "Organizations may create experiences either under a personal profile or under an Organization profile. When an experience is hosted under an Organization, it displays 'Hosted by [Organization Name]' to attendees.",
              "Organizations are solely responsible for ensuring their activities, events, and communications comply with all applicable laws, including tax registration, event permits, and content regulations.",
              "TheyDi may verify Organizations at its discretion and display a verification badge. Verification does not constitute endorsement or guarantee of the Organization's claims.",
            ]),

            _section("6. Communities", const [
              "TheyDi supports two types of communities: Circles (private, invitation-based friend groups) and Communities (open or approval-gated groups around shared interests, industries, or goals).",
              "Every experience on TheyDi automatically generates an Experience Community — a temporary social space for participants to connect before, during, and after the experience. This community is visible only to participants of that experience.",
              "Community creators and admins are responsible for managing their community, moderating content, and ensuring compliance with these Terms and community guidelines.",
              "Communities must not be used for unlawful purposes, spam, harassment, promotion of prohibited content, or circumvention of Platform rules.",
              "TheyDi may remove communities, posts, or members that violate these Terms, without prior notice.",
              "Organization-linked communities are managed by the Organization and subject to the same rules as standalone communities.",
            ]),

            _section("7. Social and Professional Experiences", const [
              "Experiences (events) on TheyDi are classified as Social (music, food, gaming, fitness, travel, parties, etc.) or Professional (hackathons, conferences, workshops, startup meetups, career events, etc.). This classification is set by the host at creation and determines how the experience appears in discovery.",
              "Hosts must accurately classify their experience. Misclassification to game the discovery algorithm is a violation of these Terms.",
              "For Professional experiences, hosts may additionally display organization information, job titles, and professional context to attendees.",
              "Social experiences may include age groups, gender balance settings, and indoor/outdoor type. Hosts must ensure these settings are accurate and comply with applicable laws.",
              "TheyDi is not responsible for the professional claims or credentials of any host, speaker, or organization on the Platform.",
            ]),

            _section("8. User Conduct", const [
              "You agree not to: post unlawful, obscene, defamatory, harassing, hateful, discriminatory, sexually explicit, or violent content.",
              "Host, promote, or attend experiences involving illegal activities (unlicensed alcohol, drugs, gambling, or anything prohibited under Indian law).",
              "Impersonate any person, organization, or brand, or misrepresent your identity, age, or professional credentials.",
              "Harass, stalk, threaten, or harm other Users, or collect their personal information without consent.",
              "Use bots, scrapers, or automated tools, or attempt unauthorised access to the Platform, accounts, or systems.",
              "Interfere with the Platform through malware, denial-of-service attacks, or exploits.",
              "Post spam or unsolicited advertisements in communities, chats, or experience communities.",
              "Violate applicable Indian laws including the IT Act 2000, IT Rules 2021, Bharatiya Nyaya Sanhita 2023, and the DPDP Act 2023.",
              "Circumvent gender balance, age restrictions, audience type settings, or Host approval mechanisms.",
              "Resell or scalp tickets outside the Platform.",
              "You agree to treat all Users, Organizations, and community members with respect and follow our published community guidelines.",
            ]),

            _section("9. Content and Intellectual Property", const [
              "You retain ownership of content you submit (photos, experience descriptions, messages, profile info, organization content, community posts, reviews). By submitting it, you grant Vrutsa Solutions a worldwide, non-exclusive, royalty-free licence to host, store, use, reproduce, modify, publish, and display it to operate and promote the Services.",
              "You represent that you own or have rights to all content you submit, and that it does not infringe third-party rights.",
              "The TheyDi name, logo, design, source code, and features are owned by Vrutsa Solutions and protected under Indian and international IP law. You may not copy, modify, or create derivative works without our written consent.",
              "Organization names, logos, and branding submitted by Organization owners must be owned by or properly licensed to the submitting user.",
            ]),

            _section("10. Experiences, Hosting & Attendance", const [
              "Hosts and Organizations are solely responsible for the legality, safety, accuracy, and conduct of their experiences, and must comply with all applicable licences, permissions, tax laws, and regulations.",
              "Hosts must accurately describe the experience including location, time, duration, capacity, age restrictions, gender balance, audience type (Social or Professional), and any associated organization.",
              "Attendees participate in experiences at their own risk. TheyDi does not guarantee the safety of any venue, host, organization, or attendee.",
              "Some experiences require Host approval before attendance is confirmed; approval or rejection is at the Host's or Organization's sole discretion.",
            ]),

            _section("11. Payments, Ticketing & Refunds", const [
              "Attendee ticket payments are processed by Razorpay Payment Gateway, subject to Razorpay's own terms. Host payouts are processed directly by Vrutsa Entertainment Private Limited via netbanking bulk transfers (NEFT/RTGS/IMPS).",
              "Platform fee: approximately 10% (inclusive of applicable taxes) on ticket sales, deducted from Host payouts. Payment gateway fee: approximately 2%, charged by Razorpay.",
              "Attendee cancellations before the experience starts: 90% refund of the ticket price; 10% retained as cancellation fee. No refund for no-shows or cancellations after the experience starts.",
              "Host or Organization cancellations: allowed only 24–48 hours before the experience start (except emergencies/force majeure). All attendees receive a full 100% refund when cancelled within the permitted window.",
              "Approved refunds are processed within 7 days. Refund disputes must be raised within 7 days of the experience date via in-app support or theydi.app@gmail.com.",
              "Host payouts are initiated after successful experience completion and credited within 7 days, calculated as: Total ticket sales − Platform fee (~10%) − Payment gateway fee (~2%) − Refunds issued. KYC (bank details) must be completed before payouts are released.",
              "Hosts and Organizations are solely responsible for reporting and paying income tax, GST, and other applicable taxes on their earnings.",
            ]),

            _section("12. Location Services", const [
              "The Platform uses GPS and location services for experience discovery, distance calculation, and city-based recommendations.",
              "By granting location permissions, you consent to the collection and processing of your location data as described in our Privacy Policy.",
              "You may disable location services through your device settings, though this may limit certain features.",
            ]),

            _section("13. Social and Community Features", const [
              "The Platform enables connections, direct messaging, communities, experience communities, organization follows, and profile discovery.",
              "You are solely responsible for your interactions with other Users, Organizations, and community members; we are not responsible for the conduct of any User or Organization.",
              "Experience Communities are automatically created for every experience and are visible only to participants. They are not public communities.",
              "Community admins and organization owners are responsible for moderating content within their communities and organization profiles.",
              "You may block or report other Users through in-app tools. We review reports and may take action including warnings, content removal, suspension, or reporting to law enforcement.",
            ]),

            _section("14. Prohibited Experiences", const [
              "Experiences promoting hate speech, terrorism, communal violence, or discrimination.",
              "Experiences involving unlicensed sale of alcohol or controlled substances.",
              "Adult, sexual, or escort services.",
              "Gambling, betting, or fantasy sports without proper licences.",
              "Political rallies or experiences that may incite violence.",
              "Any activity prohibited under Indian law.",
              "Violation may result in immediate account and organization termination and reporting to law enforcement.",
            ]),

            _section("15. Content Moderation & Grievance Redressal", const [
              "In compliance with the IT (Intermediary Guidelines and Digital Media Ethics Code) Rules, 2021, grievances, complaints, and reports may be sent to theydi.app@gmail.com.",
              "Response time: acknowledgement within 24 hours; resolution within 15 days.",
              "Report unlawful content, harmful community behaviour, or fraudulent organizations via in-app reporting or email.",
              "We may remove content, communities, organization profiles, or suspend accounts without prior notice where we determine a violation of these Terms or applicable law.",
            ]),

            _section("16. Third-Party Services", const [
              "Firebase (Google)",
              "Google Maps",
              "Razorpay",
              "Other integrated service providers",
              "Your use of these services is subject to their respective terms. We are not responsible for their availability, accuracy, or reliability.",
            ]),

            _section("17. Disclaimers & Limitation of Liability", const [
              "The Platform is provided on an 'AS IS' and 'AS AVAILABLE' basis without warranties of any kind, express or implied.",
              "We do not warrant that the Platform will be uninterrupted, error-free, secure, or virus-free.",
              "We do not verify professional credentials, organizational claims, or the accuracy of user-provided professional identity information. Users rely on such information at their own discretion.",
              "To the maximum extent permitted by law, we are not liable for indirect or consequential damages, loss of profits/data/goodwill, personal injury or death arising from experience attendance, actions of Hosts/Attendees/Organizations/community members/third parties, unauthorised data access despite reasonable security, or third-party payment failures.",
              "Our total aggregate liability to you for any claim shall not exceed the fees you paid us in the 3 months preceding the claim, or ₹5,000, whichever is lower.",
              "Nothing in these Terms excludes liability that cannot be excluded under applicable Indian law.",
            ]),

            _section("18. Indemnification", const [
              "You agree to indemnify, defend, and hold harmless Vrutsa Solutions, its officers, directors, employees, and agents from claims, damages, liabilities, costs, and legal fees arising from your use of the Platform, your violation of these Terms or any law or third-party rights, any experience you host or attend, any organization you create or manage, any community you administer, or any content you submit.",
            ]),

            _section("19. Suspension & Termination", const [
              "We may suspend or terminate your account, organization profile, or community at any time, with or without notice, for violation of these Terms, fraudulent or illegal activity, extended inactivity, or requests from law enforcement.",
              "You may delete your account at any time through in-app settings. Organization profiles and communities you own will be removed with your account unless transferred to another admin.",
              "Upon termination, your right to use the Platform ends immediately. Provisions on IP, indemnification, liability, and dispute resolution survive termination.",
            ]),

            _section("20. Modifications to the Terms", const [
              "We may amend these Terms at any time. Material changes will be notified via in-app notification, email, or a prominent notice on the Platform.",
              "Continued use of the Platform after changes constitutes acceptance of the amended Terms.",
            ]),

            _section("21. Governing Law & Dispute Resolution", const [
              "These Terms are governed by the laws of India.",
              "Disputes are first attempted to be resolved amicably through good-faith negotiation for 30 days.",
            ]),

            _section("22. Miscellaneous", const [
              "Severability: invalid provisions do not affect the remaining Terms.",
              "Waiver: failure to enforce a provision does not waive our rights.",
              "Assignment: you may not assign your rights under these Terms; we may assign ours without your consent.",
              "Notices: sent to you via email or in-app notification; notices to us go to theydi.app@gmail.com.",
              "Force Majeure: we are not liable for delays or failures due to events beyond our reasonable control.",
            ]),

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
                      Icon(Icons.contact_mail_rounded, color: Colors.green, size: 24),
                      SizedBox(width: 10),
                      Text("23. Contact Us", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  SizedBox(height: 16),
                  Text("Vrutsa Solutions", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  SizedBox(height: 10),
                  Row(
                    children: [
                      Icon(Icons.email_outlined, size: 18, color: Colors.black54),
                      SizedBox(width: 8),
                      Expanded(child: Text("theydi.app@gmail.com", style: TextStyle(fontSize: 15))),
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
                style: TextStyle(color: Colors.grey.shade700, fontSize: 15, fontWeight: FontWeight.w500),
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
          Text(title, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          ...points.map((e) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("• ", style: TextStyle(fontSize: 18)),
                    Expanded(child: Text(e, style: const TextStyle(height: 1.6, fontSize: 16))),
                  ],
                ),
              )),
        ],
      ),
    );
  }
}