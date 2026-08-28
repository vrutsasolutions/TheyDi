import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:theydi/core/services/referral_service.dart';

void main() {
  group('ReferralService', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('generates invite links and extracts valid referral codes', () {
      final service = ReferralService.instance;

      expect(
        service.inviteLink('ABCD2345'),
        'https://theydi-cefdf.web.app/invite/ABCD2345',
      );
      expect(
        service.extractReferralCode(
          Uri.parse('https://theydi.app/invite/abcd2345'),
        ),
        'ABCD2345',
      );
      expect(
        service.extractReferralCode(
          Uri.parse('https://theydi-cefdf.web.app/invite/xyz789'),
        ),
        'XYZ789',
      );
    });

    test('rejects invalid referral links', () {
      final service = ReferralService.instance;

      expect(
        service.extractReferralCode(
          Uri.parse('https://example.com/invite/ABCD2345'),
        ),
        isNull,
      );
      expect(
        service.extractReferralCode(
          Uri.parse('https://theydi.app/not-invite/ABCD2345'),
        ),
        isNull,
      );
      expect(
        service.extractReferralCode(Uri.parse('https://theydi.app/invite/abc')),
        isNull,
      );
    });

    test('persists only normalized valid pending referral codes', () async {
      final service = ReferralService.instance;

      await service.savePendingReferralCode(' abcd2345 ');
      expect(await service.getPendingReferralCode(), 'ABCD2345');

      await service.savePendingReferralCode('bad');
      expect(await service.getPendingReferralCode(), 'ABCD2345');

      await service.clearPendingReferralCode();
      expect(await service.getPendingReferralCode(), isNull);
    });
  });
}
