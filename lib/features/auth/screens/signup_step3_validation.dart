enum SignupStep3UsernameState { idle, checking, available, taken, invalid }

class SignupStep3ValidationResult {
  const SignupStep3ValidationResult({required this.isValid, this.message});

  final bool isValid;
  final String? message;
}

SignupStep3ValidationResult validateSignupStep3Fields({
  required String username,
  required String bio,
  required bool hasPhoto,
  required SignupStep3UsernameState usernameState,
}) {
  final trimmedUsername = username.trim();
  if (trimmedUsername.isEmpty) {
    return const SignupStep3ValidationResult(
      isValid: false,
      message: 'Username is required',
    );
  }

  if (bio.trim().isEmpty) {
    return const SignupStep3ValidationResult(
      isValid: false,
      message: 'Bio is required',
    );
  }

  if (!hasPhoto) {
    return const SignupStep3ValidationResult(
      isValid: false,
      message: 'Profile photo is required',
    );
  }

  if (usernameState == SignupStep3UsernameState.taken) {
    return const SignupStep3ValidationResult(
      isValid: false,
      message: 'Username is taken. Please choose another.',
    );
  }

  if (usernameState == SignupStep3UsernameState.checking) {
    return const SignupStep3ValidationResult(
      isValid: false,
      message: 'Still checking username… please wait.',
    );
  }

  return const SignupStep3ValidationResult(isValid: true);
}
