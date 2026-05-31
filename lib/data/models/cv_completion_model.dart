import 'package:viecnow/data/models/candidate_profile_models.dart';
import 'package:viecnow/data/models/work_experience_model.dart';

/// Mức hoàn thiện CV trên `users/{uid}`.
class CvCompletionModel {
  final int percent;
  final bool hasBasicInfo;
  final bool hasSelfIntro;
  final bool hasExperience;
  final bool hasEducation;
  final bool hasSkills;
  final bool hasCvFile;

  const CvCompletionModel({
    required this.percent,
    required this.hasBasicInfo,
    required this.hasSelfIntro,
    required this.hasExperience,
    required this.hasEducation,
    required this.hasSkills,
    required this.hasCvFile,
  });

  bool get isReadyForFullTime => percent >= 60 && hasBasicInfo && (hasCvFile || hasSelfIntro);

  factory CvCompletionModel.fromUserData(Map<String, dynamic> data) {
    final first = (data['firstName'] ?? '').toString().trim();
    final last = (data['lastName'] ?? '').toString().trim();
    final phone = (data['phone'] ?? '').toString().trim();
    final email = (data['email'] ?? '').toString().trim();

    final hasBasicInfo =
        first.isNotEmpty && last.isNotEmpty && phone.isNotEmpty && email.isNotEmpty;

    final selfIntro = selfIntroductionFromUserData(data).isNotEmpty;
    final skills = skillsFromUserData(data).isNotEmpty;
    final educations = EducationModel.listFromUserData(data).isNotEmpty;
    final experiences = WorkExperienceModel.listFromUserData(data);
    final declaredNoExp = data['hasWorkExperience'] == false;
    final hasExperience = experiences.isNotEmpty || declaredNoExp;
    final cvUrl = (data['cvUrl'] ?? '').toString().trim().isNotEmpty;

    final checks = [
      hasBasicInfo,
      selfIntro,
      hasExperience,
      educations,
      skills,
      cvUrl,
    ];
    final done = checks.where((c) => c).length;
    final percent = ((done / checks.length) * 100).round();

    return CvCompletionModel(
      percent: percent,
      hasBasicInfo: hasBasicInfo,
      hasSelfIntro: selfIntro,
      hasExperience: hasExperience,
      hasEducation: educations,
      hasSkills: skills,
      hasCvFile: cvUrl,
    );
  }
}
