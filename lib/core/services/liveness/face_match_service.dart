import 'dart:math';

class FaceLandmarkSet {
  final Map<String, double> ratios;
  const FaceLandmarkSet(this.ratios);
}

class FaceMatchService {
  static FaceLandmarkSet ratiosFromPoints(Map<String, List<double>> p) {
    double d(String a, String b) {
      final pa = p[a]!, pb = p[b]!;
      return sqrt(pow(pa[0] - pb[0], 2) + pow(pa[1] - pb[1], 2));
    }

    final eyeDist = d('leftEyeOuter', 'rightEyeOuter');

    return FaceLandmarkSet({
      'eyeToNose': d('leftEyeOuter', 'noseTip') / eyeDist,
      'noseToMouth': d('noseTip', 'mouthCenter') / eyeDist,
      'jawWidth': d('leftJaw', 'rightJaw') / eyeDist,
      'eyeToJaw': d('leftEyeOuter', 'leftJaw') / eyeDist,
      'mouthWidth': d('mouthLeft', 'mouthRight') / eyeDist,
      'browToEye': d('leftBrow', 'leftEyeOuter') / eyeDist,
    });
  }

  static double similarity(FaceLandmarkSet a, FaceLandmarkSet b) {
    double totalDiff = 0;
    int count = 0;
    for (final key in a.ratios.keys) {
      final av = a.ratios[key];
      final bv = b.ratios[key];
      if (av == null || bv == null) continue;
      totalDiff += (av - bv).abs() / ((av + bv) / 2);
      count++;
    }
    if (count == 0) return 0;
    return (1 - (totalDiff / count)).clamp(0.0, 1.0);
  }

  static bool isMatch(FaceLandmarkSet a, FaceLandmarkSet b, {double threshold = 0.85}) {
    return similarity(a, b) >= threshold;
  }
}