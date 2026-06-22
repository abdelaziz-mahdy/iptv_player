import 'dart:ui';
import 'package:hydrated_bloc/hydrated_bloc.dart';

/// Holds and persists the active app [Locale] (English or Arabic).
class LocaleCubit extends HydratedCubit<Locale> {
  LocaleCubit() : super(const Locale('en'));

  void setEnglish() => emit(const Locale('en'));
  void setArabic() => emit(const Locale('ar'));
  void toggle() =>
      emit(state.languageCode == 'ar' ? const Locale('en') : const Locale('ar'));

  @override
  Locale? fromJson(Map<String, dynamic> json) =>
      Locale(json['code'] as String? ?? 'en');

  @override
  Map<String, dynamic>? toJson(Locale state) => {'code': state.languageCode};
}
