import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/di/injection.dart';
import '../../core/theme/app_palette.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/focusable_button.dart';
import '../../data/models/models.dart';
import '../../data/repositories/repositories.dart';
import '../../l10n/generated/app_localizations.dart';
import 'cubit/playlists_cubit.dart';

class PlaylistsScreen extends StatefulWidget {
  const PlaylistsScreen({
    super.key,
    required this.onAddPlaylist,
    required this.onSelected,
  });

  final VoidCallback onAddPlaylist;
  final void Function(Playlist) onSelected;

  @override
  State<PlaylistsScreen> createState() => _PlaylistsScreenState();
}

class _PlaylistsScreenState extends State<PlaylistsScreen> {
  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => PlaylistsCubit(sl<PlaylistRepository>())..load(),
      child: _PlaylistsView(
        onAddPlaylist: widget.onAddPlaylist,
        onSelected: widget.onSelected,
      ),
    );
  }
}

class _PlaylistsView extends StatelessWidget {
  const _PlaylistsView({
    required this.onAddPlaylist,
    required this.onSelected,
  });

  final VoidCallback onAddPlaylist;
  final void Function(Playlist) onSelected;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final textTheme = Theme.of(context).textTheme;
    final l10n = AppLocalizations.of(context)!;

    return BlocBuilder<PlaylistsCubit, PlaylistsState>(
      builder: (context, state) {
        if (state.loading) {
          return const Center(child: CircularProgressIndicator());
        }

        return Scaffold(
          backgroundColor: p.bg,
          appBar: AppBar(
            backgroundColor: p.bg,
            title: Text(
              l10n.playlists,
              style: textTheme.titleLarge?.copyWith(color: p.fg),
            ),
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Playlist items
              ...state.playlists.map(
                (playlist) => _PlaylistTile(
                  playlist: playlist,
                  isActive: state.activeId == playlist.id,
                  onTap: () {
                    context.read<PlaylistsCubit>().select(playlist.id);
                    onSelected(playlist);
                  },
                  palette: p,
                  textTheme: textTheme,
                ),
              ),
              const SizedBox(height: 12),

              // Add Playlist button (dashed border)
              _AddPlaylistButton(
                onPressed: onAddPlaylist,
                palette: p,
                textTheme: textTheme,
              ),

              const SizedBox(height: 24),

              // Compliance text
              Text(
                l10n.complianceNote,
                style: textTheme.bodySmall?.copyWith(color: p.dim),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        );
      },
    );
  }
}

class _PlaylistTile extends StatelessWidget {
  const _PlaylistTile({
    required this.playlist,
    required this.isActive,
    required this.onTap,
    required this.palette,
    required this.textTheme,
  });

  final Playlist playlist;
  final bool isActive;
  final VoidCallback onTap;
  final AppPalette palette;
  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    final p = palette;
    final l10n = AppLocalizations.of(context)!;
    final typeLabel = _typeLabel(playlist.type);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: FocusableButton(
        onPressed: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: p.surface2,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isActive ? p.accent : p.border,
              width: isActive ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              // Initial avatar
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: p.accent,
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Center(
                  child: Text(
                    playlist.initial,
                    style: textTheme.titleMedium?.copyWith(
                      color: Colors.black,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Name + subtitle
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      playlist.name,
                      style: textTheme.bodyLarge?.copyWith(
                        color: p.fg,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      playlist.serverUrl ?? typeLabel,
                      style: textTheme.bodySmall?.copyWith(color: p.dim),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (playlist.channelCount > 0) ...[
                      const SizedBox(height: 2),
                      Text(
                        '${playlist.channelCount} ${l10n.channels}',
                        style:
                            textTheme.bodySmall?.copyWith(color: p.dim),
                      ),
                    ],
                  ],
                ),
              ),
              // Active checkmark
              if (isActive)
                Icon(Icons.check_circle_rounded, color: p.accent, size: 24),
            ],
          ),
        ),
      ),
    );
  }

  String _typeLabel(PlaylistType type) {
    switch (type) {
      case PlaylistType.xtream:
        return 'Xtream Codes';
      case PlaylistType.m3u:
        return 'M3U Playlist';
      case PlaylistType.upload:
        return 'Uploaded File';
    }
  }
}

class _AddPlaylistButton extends StatelessWidget {
  const _AddPlaylistButton({
    required this.onPressed,
    required this.palette,
    required this.textTheme,
  });

  final VoidCallback onPressed;
  final AppPalette palette;
  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    final p = palette;
    final l10n = AppLocalizations.of(context)!;
    return FocusableButton(
      semanticLabel: l10n.addPlaylist,
      onPressed: onPressed,
      child: CustomPaint(
        painter: _DashedBorderPainter(color: p.border),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.add_rounded, color: p.fg, size: 20),
              const SizedBox(width: 8),
              Text(
                l10n.addPlaylist,
                style: textTheme.labelLarge?.copyWith(color: p.fg),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  final Color color;
  _DashedBorderPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    const dashWidth = 6.0;
    const dashSpace = 4.0;
    const cornerRadius = 14.0;
    final rect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, size.height),
      const Radius.circular(cornerRadius),
    );
    final path = Path()..addRRect(rect);
    final metrics = path.computeMetrics();
    for (final metric in metrics) {
      double distance = 0;
      while (distance < metric.length) {
        canvas.drawPath(
            metric.extractPath(distance, distance + dashWidth), paint);
        distance += dashWidth + dashSpace;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorderPainter old) => old.color != color;
}
