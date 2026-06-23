import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import 'tables.dart';

part 'database.g.dart';

/// The app's local SQLite store (drift). Holds imported playlist content plus
/// favorites and watch progress. Pass an in-memory [executor] in tests.
@DriftDatabase(
  tables: [
    Playlists,
    Channels,
    VodItems,
    SeriesItems,
    Seasons,
    Episodes,
    EpgProgrammes,
    WatchProgressRows,
    Favorites,
    XtreamCredentials,
    Categories,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor])
      : super(executor ?? driftDatabase(name: 'noor'));

  @override
  int get schemaVersion => 3;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) => m.createAll(),
        onUpgrade: (m, from, to) async {
          if (from < 2) {
            await m.createTable(xtreamCredentials);
          }
          if (from < 3) {
            await m.createTable(categories);
          }
        },
      );

  // --- Playlists ---
  Future<List<PlaylistRow>> getPlaylists() => select(playlists).get();
  Future<void> upsertPlaylist(PlaylistsCompanion p) =>
      into(playlists).insertOnConflictUpdate(p);
  Future<void> deletePlaylist(String id) =>
      (delete(playlists)..where((t) => t.id.equals(id))).go();

  // --- Channels ---
  Stream<List<ChannelRow>> watchChannels(String playlistId) =>
      (select(channels)..where((t) => t.playlistId.equals(playlistId))).watch();
  Future<void> replaceChannels(String playlistId, List<ChannelsCompanion> rows) =>
      batch((b) {
        b.deleteWhere(channels, (t) => t.playlistId.equals(playlistId));
        b.insertAll(channels, rows, mode: InsertMode.insertOrReplace);
      });

  // --- Movies ---
  Stream<List<VodRow>> watchMovies(String playlistId) =>
      (select(vodItems)..where((t) => t.playlistId.equals(playlistId))).watch();
  Future<void> replaceMovies(String playlistId, List<VodItemsCompanion> rows) =>
      batch((b) {
        b.deleteWhere(vodItems, (t) => t.playlistId.equals(playlistId));
        b.insertAll(vodItems, rows, mode: InsertMode.insertOrReplace);
      });

  // --- Series / seasons / episodes ---
  Stream<List<SeriesRow>> watchSeries(String playlistId) =>
      (select(seriesItems)..where((t) => t.playlistId.equals(playlistId))).watch();
  Future<void> replaceSeries(String playlistId, List<SeriesItemsCompanion> rows) =>
      batch((b) {
        b.deleteWhere(seriesItems, (t) => t.playlistId.equals(playlistId));
        b.insertAll(seriesItems, rows, mode: InsertMode.insertOrReplace);
      });
  Future<List<SeasonRow>> getSeasons(String seriesId) =>
      (select(seasons)..where((t) => t.seriesId.equals(seriesId))).get();
  Future<void> upsertSeasons(List<SeasonsCompanion> rows) =>
      batch((b) => b.insertAll(seasons, rows, mode: InsertMode.insertOrReplace));
  Future<List<EpisodeRow>> getEpisodes(String seasonId) =>
      (select(episodes)..where((t) => t.seasonId.equals(seasonId))).get();
  Future<void> upsertEpisodes(List<EpisodesCompanion> rows) =>
      batch((b) => b.insertAll(episodes, rows, mode: InsertMode.insertOrReplace));

  // --- EPG ---
  Future<List<EpgRow>> getEpg(String channelId, DateTime from, DateTime to) =>
      (select(epgProgrammes)
            ..where((t) => t.channelId.equals(channelId) & t.stopUtc.isBiggerThanValue(from) & t.startUtc.isSmallerThanValue(to))
            ..orderBy([(t) => OrderingTerm(expression: t.startUtc)]))
          .get();
  Future<void> upsertEpg(List<EpgProgrammesCompanion> rows) =>
      batch((b) => b.insertAll(epgProgrammes, rows, mode: InsertMode.insertOrReplace));

  // --- Favorites ---
  Stream<List<FavoriteRow>> watchFavorites(String playlistId) =>
      (select(favorites)..where((t) => t.playlistId.equals(playlistId))).watch();
  Future<bool> isFavorite(String itemKey) async =>
      await (select(favorites)..where((t) => t.itemKey.equals(itemKey))).getSingleOrNull() != null;
  Future<void> addFavorite(FavoritesCompanion f) =>
      into(favorites).insertOnConflictUpdate(f);
  Future<void> removeFavorite(String itemKey) =>
      (delete(favorites)..where((t) => t.itemKey.equals(itemKey))).go();

  // --- Watch progress ---
  Future<WatchProgressRow?> getProgress(String itemKey) =>
      (select(watchProgressRows)..where((t) => t.itemKey.equals(itemKey))).getSingleOrNull();
  Future<void> saveProgress(WatchProgressRowsCompanion p) =>
      into(watchProgressRows).insertOnConflictUpdate(p);
  Future<void> deleteProgress(String itemKey) =>
      (delete(watchProgressRows)..where((t) => t.itemKey.equals(itemKey))).go();
  Stream<List<WatchProgressRow>> watchContinue(String playlistId) =>
      (select(watchProgressRows)
            ..where((t) =>
                t.playlistId.equals(playlistId) &
                t.kind.equals('channel').not())
            ..orderBy([
              (t) => OrderingTerm(expression: t.updatedAt, mode: OrderingMode.desc)
            ])
            ..limit(20))
          .watch();

  // --- Categories ---
  Future<void> replaceCategories(String playlistId, String type, List<CategoriesCompanion> rows) =>
      batch((b) {
        b.deleteWhere(categories, (t) => t.playlistId.equals(playlistId) & t.type.equals(type));
        b.insertAll(categories, rows, mode: InsertMode.insertOrReplace);
      });
  Future<List<CategoryRow>> getCategories(String playlistId, String type) =>
      (select(categories)..where((t) => t.playlistId.equals(playlistId) & t.type.equals(type))).get();

  // --- Xtream credentials ---
  Future<void> upsertCredentials(XtreamCredentialsCompanion c) =>
      into(xtreamCredentials).insertOnConflictUpdate(c);
  Future<XtreamCredentialRow?> getCredentials(String playlistId) =>
      (select(xtreamCredentials)..where((t) => t.playlistId.equals(playlistId)))
          .getSingleOrNull();
}
