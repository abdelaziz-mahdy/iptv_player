import 'package:equatable/equatable.dart';

/// A lightweight reference to a provider category — just its id and display
/// name. Used to populate filter chips / category pickers in the UI.
class CategoryRef extends Equatable {
  const CategoryRef({required this.id, required this.name, this.count});

  final String id;
  final String name;

  /// Number of items in this category, shown on the right of the row. Null when
  /// unknown (the count is computed by the cubit from the loaded items).
  final int? count;

  CategoryRef copyWith({int? count}) =>
      CategoryRef(id: id, name: name, count: count ?? this.count);

  @override
  List<Object?> get props => [id, name, count];
}
