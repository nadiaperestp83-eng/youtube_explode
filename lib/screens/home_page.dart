/*
 *     Copyright (C) 2026 Valeri Gokadze
 *
 *     Musify is free software: you can redistribute it and/or modify
 *     it under the terms of the GNU General Public License as published by
 *     the Free Software Foundation, either version 3 of the License, or
 *     (at your option) any later version.
 *
 *     Musify is distributed in the hope that it will be useful,
 *     but WITHOUT ANY WARRANTY; without even the implied warranty of
 *     MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *     GNU General Public License for more details.
 *
 *     You should have received a copy of the GNU General Public License
 *     along with this program.  If not, see <https://www.gnu.org/licenses/>.
 *
 *
 *     For more information about Musify, including how to contribute,
 *     please visit: https://github.com/gokadzev/Musify
 */

import 'package:cached_network_image/cached_network_image.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:musify/constants/app_constants.dart';
import 'package:musify/extensions/l10n.dart';
import 'package:musify/main.dart';
import 'package:musify/services/common_services.dart';
import 'package:musify/services/listening_stats_service.dart';
import 'package:musify/services/playlists_manager.dart';
import 'package:musify/services/settings_manager.dart';
import 'package:musify/utilities/app_utils.dart';
import 'package:musify/utilities/async_loader.dart';
import 'package:musify/utilities/listening_stats_utils.dart';
import 'package:musify/widgets/announcement_box.dart';
import 'package:musify/widgets/listening_recap_card.dart';
import 'package:musify/widgets/mini_player_bottom_space.dart';
import 'package:musify/widgets/section_header.dart';
import 'package:musify/widgets/song_bar.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late final Future<List> _suggestedPlaylistsFuture;
  late Future<List> _recommendedSongsFuture;

  @override
  void initState() {
    super.initState();
    _suggestedPlaylistsFuture = getPlaylists(
      playlistsNum: recommendedCubesNumber,
    );
    _recommendedSongsFuture = getRecommendedSongs();
    externalRecommendations.addListener(_refreshRecommendedSongs);
  }

  @override
  void dispose() {
    externalRecommendations.removeListener(_refreshRecommendedSongs);
    super.dispose();
  }

  void _refreshRecommendedSongs() {
    if (!mounted) return;
    setState(() {
      _recommendedSongsFuture = getRecommendedSongs();
    });
  }

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 18) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context) {
    final playlistHeight = MediaQuery.sizeOf(context).height * 0.25 / 1.1;
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: commonSingleChildScrollViewPadding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildGreetingHeader(context),
              const SizedBox(height: 20),
              ValueListenableBuilder<String?>(
                valueListenable: announcementURL,
                builder: (_, _url, __) {
                  if (_url == null) return const SizedBox.shrink();
                  final isSponsorshipAnnouncement =
                      isSponsorshipAnnouncementUrl(_url);
                  final _message = isSponsorshipAnnouncement
                      ? context.l10n!.sponsorProject
                      : context.l10n!.newAnnouncement;
                  final _icon = isSponsorshipAnnouncement
                      ? FluentIcons.heart_24_filled
                      : FluentIcons.megaphone_24_filled;

                  return AnnouncementBox(
                    message: _message,
                    url: _url,
                    icon: _icon,
                    onDismiss: () async {
                      announcementURL.value = null;
                    },
                  );
                },
              ),
              _buildFavoriteArtistsSection(),
              _buildRecentPlayedSection(playlistHeight),
              _buildCurrentMonthRecapSection(),
              _buildRecommendedSongsSection(),
              const MiniPlayerBottomSpace(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGreetingHeader(BuildContext context) {
    final textColor = Theme.of(context).textTheme.bodyLarge?.color;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            _greeting(),
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: textColor,
            ),
          ),
          Row(
            children: [
              IconButton(
                tooltip: 'Notifications',
                onPressed: () {
                  // TODO: sem uma tela/rota de notificações definida ainda.
                },
                icon: const Icon(FluentIcons.alert_24_regular),
              ),
              IconButton(
                tooltip: context.l10n!.timeMachine,
                onPressed: () => context.push('/home/timeMachine'),
                icon: const Icon(FluentIcons.history_24_regular),
              ),
              IconButton(
                tooltip: 'Settings',
                onPressed: () {
                  // TODO: me diga a rota real de settings_page.dart
                  // (ex: context.push('/settings')) que eu conecto aqui.
                },
                icon: const Icon(FluentIcons.settings_24_regular),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFavoriteArtistsSection() {
    return ValueListenableBuilder<List<Map>>(
      valueListenable: userLikedPlaylists,
      builder: (_, likedPlaylists, __) {
        final artistPlaylists = likedPlaylists
            .where((playlist) => isArtistPlaylist(playlist))
            .toList();

        if (artistPlaylists.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionHeader(
              title: 'Your favorite artist',
              icon: FluentIcons.person_24_filled,
            ),
            SizedBox(
              height: 104,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: artistPlaylists.length,
                itemBuilder: (context, index) {
                  final playlist = artistPlaylists[index];
                  final imageUrl =
                      playlist['image'] ??
                      playlist['lowResImage'] ??
                      playlist['highResImage'];
                  final title = playlist['title']?.toString() ?? '';

                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: GestureDetector(
                      onTap: () =>
                          context.push('/home/playlist/${playlist['ytid']}'),
                      child: SizedBox(
                        width: 72,
                        child: Column(
                          children: [
                            ClipOval(
                              child: SizedBox(
                                width: 64,
                                height: 64,
                                child: imageUrl != null
                                    ? CachedNetworkImage(
                                        imageUrl: imageUrl.toString(),
                                        fit: BoxFit.cover,
                                        errorWidget: (_, __, ___) =>
                                            const Icon(
                                              FluentIcons.person_24_filled,
                                            ),
                                      )
                                    : const Icon(
                                        FluentIcons.person_24_filled,
                                      ),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildRecentPlayedSection(double playlistHeight) {
    return AsyncLoader<List<dynamic>>(
      future: _suggestedPlaylistsFuture,
      builder: (context, playlists) {
        if (playlists.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionHeader(
              title: 'Recent played',
              icon: FluentIcons.list_24_filled,
            ),
            SizedBox(
              height: 140,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: playlists.length,
                itemBuilder: (context, index) {
                  final playlist = playlists[index];
                  final imageUrl =
                      playlist['image'] ??
                      playlist['lowResImage'] ??
                      playlist['highResImage'];
                  final title = playlist['title']?.toString() ?? '';

                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: GestureDetector(
                      onTap: () =>
                          context.push('/home/playlist/${playlist['ytid']}'),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: SizedBox(
                          width: 160,
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              imageUrl != null
                                  ? CachedNetworkImage(
                                      imageUrl: imageUrl.toString(),
                                      fit: BoxFit.cover,
                                      errorWidget: (_, __, ___) =>
                                          Container(color: Colors.grey[900]),
                                    )
                                  : Container(color: Colors.grey[900]),
                              Positioned(
                                left: 0,
                                right: 0,
                                bottom: 0,
                                child: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [
                                        Colors.transparent,
                                        Colors.black.withValues(alpha: 0.75),
                                      ],
                                    ),
                                  ),
                                  child: Text(
                                    title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildRecommendedSongsSection() {
    return AsyncLoader<List<dynamic>>(
      future: _recommendedSongsFuture,
      builder: (context, data) {
        if (data.isEmpty) return const SizedBox.shrink();
        return _buildRecommendedForYouSection(context, data);
      },
    );
  }

  Widget _buildCurrentMonthRecapSection() {
    return ValueListenableBuilder<bool>(
      valueListenable: wrappedEnabled,
      builder: (_, isEnabled, __) {
        if (!isEnabled) return const SizedBox.shrink();

        final currentMonthKey = listeningStatsMonthKey(DateTime.now());
        final monthStats = listeningStatsService.monthStats(currentMonthKey);
        final songs = listeningStatsService.monthTopSongs(currentMonthKey);
        final displayMinutes = monthDisplayMinutes(monthStats);
        if (displayMinutes <= 0 && songs.isEmpty) {
          return const SizedBox.shrink();
        }

        final previewSongs = songs.take(wrappedShareSongsLimit).toList();
        final periodLabel = formatMonthPeriodLabel(
          Localizations.localeOf(context),
          currentMonthKey,
        );

        return Column(
          children: [
            SectionHeader(
              title: context.l10n!.timeMachine,
              icon: FluentIcons.data_trending_24_filled,
            ),
            ListeningRecapCard(
              periodLabel: periodLabel,
              minutes: displayMinutes,
              songs: previewSongs,
              onSongTap: (index) => _playRecapSongs(previewSongs, index),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 10, 8, 0),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.tonalIcon(
                  onPressed: () => context.push('/home/timeMachine'),
                  icon: const Icon(FluentIcons.arrow_right_24_regular),
                  label: Text(context.l10n!.listeningStats),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _playRecapSongs(
    List<Map<String, dynamic>> songs,
    int index,
  ) async {
    if (songs.isEmpty) return;
    await audioHandler.playPlaylistSong(
      playlist: {'title': context.l10n!.timeMachine, 'list': songs},
      songIndex: index,
    );
  }

  Widget _buildRecommendedForYouSection(
    BuildContext context,
    List<dynamic> data,
  ) {
    final recommendedTitle = context.l10n!.recommendedForYou;

    return Column(
      children: [
        SectionHeader(
          title: recommendedTitle,
          icon: FluentIcons.sparkle_24_filled,
          actionButton: IconButton(
            onPressed: () async {
              await audioHandler.playPlaylistSong(
                playlist: {'title': recommendedTitle, 'list': data},
                songIndex: 0,
              );
            },
            icon: Icon(
              FluentIcons.play_circle_24_filled,
              color: Theme.of(context).colorScheme.primary,
              size: 30,
            ),
          ),
        ),
        ListView.builder(
          shrinkWrap: true,
          physics: const BouncingScrollPhysics(),
          itemCount: data.length,
          padding: commonListViewBottomPadding,
          itemBuilder: (context, index) {
            final borderRadius = getItemBorderRadius(index, data.length);
            return RepaintBoundary(
              key: listItemKey('home_recommended', index, data[index]),
              child: SongBar(data[index], true, borderRadius: borderRadius),
            );
          },
        ),
      ],
    );
  }
}
