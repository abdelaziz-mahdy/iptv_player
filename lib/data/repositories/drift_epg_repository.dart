import '../../core/result.dart';
import '../db/database.dart';
import '../models/models.dart';
import 'repositories.dart';

/// Drift-backed [EpgRepository].
class EpgRepositoryImpl implements EpgRepository {
  EpgRepositoryImpl(this._db);

  final AppDatabase _db;

  // ---------------------------------------------------------------------------
  // Mapping helpers
  // ---------------------------------------------------------------------------

  static EpgProgramme _fromRow(EpgRow r) => EpgProgramme(
        id: r.id,
        channelId: r.channelId,
        title: r.title,
        startUtc: r.startUtc,
        stopUtc: r.stopUtc,
        description: r.description,
      );

  // ---------------------------------------------------------------------------
  // EpgRepository
  // ---------------------------------------------------------------------------

  @override
  Future<Result<List<EpgProgramme>>> programmes(
      String channelId, DateTime from, DateTime to) async {
    try {
      final rows = await _db.getEpg(channelId, from, to);
      return Ok(rows.map(_fromRow).toList());
    } catch (e) {
      return Err(Failure('Failed to load EPG programmes', cause: e));
    }
  }
}
