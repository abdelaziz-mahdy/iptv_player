import 'package:equatable/equatable.dart';

/// A lightweight reference to a provider category — just its id and display
/// name. Used to populate filter chips / category pickers in the UI.
class CategoryRef extends Equatable {
  const CategoryRef({required this.id, required this.name});

  final String id;
  final String name;

  @override
  List<Object?> get props => [id, name];
}
