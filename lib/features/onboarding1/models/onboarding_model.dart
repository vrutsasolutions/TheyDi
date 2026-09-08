class OnboardingModel {
  final String image;
  final String? desktopImage;
  final String title;
  final String description;

  const OnboardingModel({
    required this.image,
    this.desktopImage,
    required this.title,
    required this.description,
  });
}