import 'package:hydrated_bloc/hydrated_bloc.dart';
import 'accessibility_settings.dart';

/// Holds and persists [AccessibilitySettings] across app restarts.
class AccessibilityCubit extends HydratedCubit<AccessibilitySettings> {
  AccessibilityCubit() : super(const AccessibilitySettings());

  void setTextScale(double v) => emit(state.copyWith(textScale: v));
  void toggleReduceMotion() => emit(state.copyWith(reduceMotion: !state.reduceMotion));
  void toggleHighContrast() => emit(state.copyWith(highContrast: !state.highContrast));
  void toggleColorblindSafe() => emit(state.copyWith(colorblindSafe: !state.colorblindSafe));
  void toggleHyperlegible() => emit(state.copyWith(hyperlegibleFont: !state.hyperlegibleFont));
  void toggleCaptions() => emit(state.copyWith(captionsOn: !state.captionsOn));
  void setCaptionSize(double v) => emit(state.copyWith(captionSize: v));
  void setCaptionBg(double v) => emit(state.copyWith(captionBgOpacity: v));
  void setCaptionColor(int v) => emit(state.copyWith(captionColor: v));

  @override
  AccessibilitySettings fromJson(Map<String, dynamic> json) =>
      AccessibilitySettings.fromJson(json);

  @override
  Map<String, dynamic> toJson(AccessibilitySettings state) => state.toJson();
}
