import 'package:flutter_test/flutter_test.dart';
import 'package:theydi/features/auth/screens/signup_step3_validation.dart';

void main() {
  group('signup step 3 validation', () {
    test('reports missing bio and photo', () {
      final result = validateSignupStep3Fields(
        username: 'sheerap_23',
        bio: '',
        hasPhoto: false,
        usernameState: SignupStep3UsernameState.available,
      );

      expect(result.isValid, isFalse);
      expect(result.message, 'Bio is required');
    });

    test(
        'allows a valid submission when username is available and a photo is attached',
        () {
      final result = validateSignupStep3Fields(
        username: 'sheerap_23',
        bio: 'Travel and food lover',
        hasPhoto: true,
        usernameState: SignupStep3UsernameState.available,
      );

      expect(result.isValid, isTrue);
      expect(result.message, isNull);
    });
  });
}
