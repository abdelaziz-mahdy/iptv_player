import 'package:drift/drift.dart';

/// User playlists. `type` stores a [PlaylistType] name; credentials for Xtream
/// live in secure storage, never here.
@DataClassName('PlaylistRow')
class Playlists extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get type => text()();
  TextColumn get serverUrl => text().nullable()();
  TextColumn get initial => text()();
  IntColumn get channelCount => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('ChannelRow')
class Channels extends Table {
  TextColumn get id => text()();
  TextColumn get playlistId => text()();
  TextColumn get name => text()();
  TextColumn get number => text()();
  TextColumn get logoUrl => text().nullable()();
  TextColumn get streamUrl => text()();
  TextColumn get categoryId => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('VodRow')
class VodItems extends Table {
  TextColumn get id => text()();
  TextColumn get playlistId => text()();
  TextColumn get title => text()();
  TextColumn get posterUrl => text().nullable()();
  TextColumn get categoryId => text().nullable()();
  TextColumn get year => text().nullable()();
  RealColumn get rating => real().nullable()();
  TextColumn get streamUrl => text()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('SeriesRow')
class SeriesItems extends Table {
  TextColumn get id => text()();
  TextColumn get playlistId => text()();
  TextColumn get title => text()();
  TextColumn get posterUrl => text().nullable()();
  TextColumn get categoryId => text().nullable()();
  TextColumn get year => text().nullable()();
  RealColumn get rating => real().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('SeasonRow')
class Seasons extends Table {
  TextColumn get id => text()();
  TextColumn get seriesId => text()();
  IntColumn get number => integer()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('EpisodeRow')
class Episodes extends Table {
  TextColumn get id => text()();
  TextColumn get seasonId => text()();
  TextColumn get title => text()();
  IntColumn get number => integer()();
  IntColumn get durationSec => integer().nullable()();
  TextColumn get streamUrl => text()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('EpgRow')
class EpgProgrammes extends Table {
  TextColumn get id => text()();
  TextColumn get channelId => text()();
  TextColumn get title => text()();
  DateTimeColumn get startUtc => dateTime()();
  DateTimeColumn get stopUtc => dateTime()();
  TextColumn get description => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('WatchProgressRow')
class WatchProgressRows extends Table {
  TextColumn get itemKey => text()();
  TextColumn get playlistId => text()();
  TextColumn get kind => text()();
  IntColumn get positionSec => integer()();
  IntColumn get durationSec => integer()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {itemKey};
}

@DataClassName('FavoriteRow')
class Favorites extends Table {
  TextColumn get itemKey => text()();
  TextColumn get playlistId => text()();
  TextColumn get kind => text()();
  DateTimeColumn get addedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {itemKey};
}

@DataClassName('XtreamCredentialRow')
class XtreamCredentials extends Table {
  TextColumn get playlistId => text()();
  TextColumn get username => text()();
  TextColumn get password => text()();

  @override
  Set<Column> get primaryKey => {playlistId};
}

@DataClassName('CategoryRow')
class Categories extends Table {
  TextColumn get playlistId => text()();
  TextColumn get type => text()();
  TextColumn get categoryId => text()();
  TextColumn get name => text()();

  @override
  Set<Column> get primaryKey => {playlistId, type, categoryId};
}
