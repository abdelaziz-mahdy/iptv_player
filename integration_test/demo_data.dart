import 'package:iptv_player/data/models/models.dart';
import 'package:iptv_player/data/repositories/fakes/fake_repositories.dart';

/// Base URL for the demo artwork served by `tools/screenshot_tour.sh`.
///
/// The posters are generated gradients, not third-party artwork, so the
/// screenshots in the README carry nothing that is not ours.
const demoArtBase =
    String.fromEnvironment('DEMO_ART', defaultValue: 'http://127.0.0.1:8099');

const _pid = 'p1';

/// Unique per run: cached_network_image keys its on-disk cache by URL, so
/// regenerated artwork would otherwise keep rendering the previous run's
/// images. Localhost, so refetching costs nothing.
final _bust = DateTime.now().millisecondsSinceEpoch;

/// A catalog big enough for a screenshot to look like a real install.
///
/// The shipped [FakeContentRepository] seeds three channels and four movies —
/// right for a unit test, far too sparse for a picture of the app. This
/// overrides just the listing methods and leaves the rest of the fake alone.
class DemoContentRepository extends FakeContentRepository {
  static const _channelNames = [
    'Aurora One HD', 'Aurora Sports', 'Aurora News 24', 'Meridian Movies',
    'Meridian Kids', 'Atlas Documentary', 'Vega Drama', 'Vega Cinema',
    'Northline Sports', 'Harbour TV', 'Solaris HD', 'Terra Nature',
  ];
  static const _movieTitles = [
    'Nightfall Protocol', 'The Quiet Coast', 'Ember and Ash', 'Signal Lost',
    'Paper Cities', 'The Long Return', 'Glasshouse', 'North of Nowhere',
    'Salt and Iron', 'The Ninth Hour', 'Blue Meridian', 'Afterlight',
  ];
  static const _movieYears = [
    '2025', '2024', '2024', '2023', '2023', '2022',
    '2022', '2021', '2021', '2020', '2019', '2018',
  ];
  static const _seriesTitles = [
    'Deep Field', 'Harbour Lights', 'The Cartographer',
    'Static', 'Wolves of Tavira', 'Low Orbit',
  ];

  late final List<Channel> _demoChannels = [
    for (var i = 0; i < _channelNames.length; i++)
      Channel(
        id: 'c$i',
        playlistId: _pid,
        name: _channelNames[i],
        number: '${101 + i}',
        logoUrl: '$demoArtBase/ch$i.png?v=$_bust',
        streamUrl: 'http://demo/live/$i',
        categoryId: i < 4 ? 'ch-ent' : (i < 8 ? 'ch-sport' : 'ch-news'),
      ),
  ];

  late final List<VodItem> _demoMovies = [
    for (var i = 0; i < _movieTitles.length; i++)
      VodItem(
        id: 'm$i',
        playlistId: _pid,
        title: _movieTitles[i],
        posterUrl: '$demoArtBase/movie$i.png?v=$_bust',
        year: _movieYears[i],
        rating: 6.4 + (i % 4) * 0.7,
        streamUrl: 'http://demo/movie/$i',
        categoryId: i < 5 ? 'mv-drama' : (i < 9 ? 'mv-thriller' : 'mv-classic'),
      ),
  ];

  late final List<Series> _demoSeries = [
    for (var i = 0; i < _seriesTitles.length; i++)
      Series(
        id: 'ds$i',
        playlistId: _pid,
        title: _seriesTitles[i],
        posterUrl: '$demoArtBase/series$i.png?v=$_bust',
        year: '${2025 - i}',
        rating: 7.1 + (i % 3) * 0.6,
        categoryId: i < 3 ? 'sr-drama' : 'sr-scifi',
      ),
  ];

  @override
  Stream<List<Channel>> channels(String playlistId) =>
      Stream.value(_demoChannels);

  @override
  Stream<List<VodItem>> movies(String playlistId) => Stream.value(_demoMovies);

  @override
  Stream<List<Series>> series(String playlistId) => Stream.value(_demoSeries);

  /// Category names matching the ids above, so each row shows a real count
  /// instead of 0.
  @override
  Future<List<CategoryRef>> categories(String playlistId, MediaKind kind) async {
    return switch (kind) {
      MediaKind.movie => const [
          CategoryRef(id: 'mv-drama', name: 'Drama'),
          CategoryRef(id: 'mv-thriller', name: 'Thriller'),
          CategoryRef(id: 'mv-classic', name: 'Classics'),
        ],
      MediaKind.channel => const [
          CategoryRef(id: 'ch-ent', name: 'Entertainment'),
          CategoryRef(id: 'ch-sport', name: 'Sports'),
          CategoryRef(id: 'ch-news', name: 'News'),
        ],
      MediaKind.episode => const [
          CategoryRef(id: 'sr-drama', name: 'Drama'),
          CategoryRef(id: 'sr-scifi', name: 'Sci-Fi'),
        ],
    };
  }
}
