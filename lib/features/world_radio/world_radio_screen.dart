import 'dart:async';
import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import '../../main.dart';
import 'radio_browser_service.dart';
import 'station_model.dart';
import 'widgets/station_tile.dart';

class WorldRadioScreen extends StatefulWidget {
  const WorldRadioScreen({super.key});

  @override
  State<WorldRadioScreen> createState() => _WorldRadioScreenState();
}

class _WorldRadioScreenState extends State<WorldRadioScreen> {
  final RadioBrowserService _service = RadioBrowserService();
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();

  List<Station> _stations = [];
  List<TagInfo> _topTags = [];

  bool _isLoading = false;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  String? _error;

  String _searchQuery = '';
  String? _selectedTag;
  Timer? _searchDebounce;

  static const int _pageSize = 30;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadInitial();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    _searchDebounce?.cancel();
    super.dispose();
  }

  Future<void> _loadInitial() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // ცარიერი ცარიერდება — top stations + top tags
      final results = await Future.wait([
        _fetchStations(offset: 0),
        _service.getTopTags(limit: 20),
      ]);

      if (!mounted) return;

      setState(() {
        _stations = results[0] as List<Station>;
        _topTags = results[1] as List<TagInfo>;
        _isLoading = false;
        _hasMore = _stations.length >= _pageSize;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = 'სადგურების ჩატვირთვა ვერ მოხერხდა';
      });
      print('🔴 Load error: $e');
    }
  }

  Future<List<Station>> _fetchStations({required int offset}) async {
    if (_searchQuery.isNotEmpty || _selectedTag != null) {
      return _service.searchStations(
        name: _searchQuery.isNotEmpty ? _searchQuery : null,
        tag: _selectedTag,
        limit: _pageSize,
        offset: offset,
      );
    }
    return _service.getTopStations(limit: _pageSize, offset: offset);
  }

  Future<void> _loadMore() async {
    if (_isLoadingMore || !_hasMore || _isLoading) return;

    setState(() => _isLoadingMore = true);

    try {
      final more = await _fetchStations(offset: _stations.length);

      if (!mounted) return;

      setState(() {
        _stations.addAll(more);
        _isLoadingMore = false;
        _hasMore = more.length >= _pageSize;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoadingMore = false);
      print('🔴 Load more error: $e');
    }
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 300) {
      _loadMore();
    }
  }

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 500), () {
      if (!mounted) return;
      setState(() {
        _searchQuery = value.trim();
      });
      _loadInitial();
    });
  }

  void _onTagSelected(String? tag) {
    setState(() {
      _selectedTag = tag;
      // ცარიერი ცარიერდება — ცარიერი ცარიერდება ცარიერი
    });
    _loadInitial();
  }

  Future<void> _onStationTap(Station station) async {
    // Register click (statistics) — fire-and-forget
    _service.registerClick(station.stationUuid);

    // ცარიერი ცარიერდება
    await audioHandler.playStation(
      url: station.url,
      name: station.name,
      country: station.country,
      favicon: station.favicon,
    );

    // ცარიერი feedback
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('🎵 ${station.name}'),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            _buildSearchBar(),
            _buildTagFilters(),
            const Divider(height: 1),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Row(
        children: [
          Text(
            'მსოფლიო რადიოები',
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          const Spacer(),
          if (_stations.isNotEmpty)
            Text(
              '${_stations.length}',
              style: TextStyle(fontSize: 12, color: Colors.grey[500]),
            ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: TextField(
        controller: _searchController,
        onChanged: _onSearchChanged,
        decoration: InputDecoration(
          hintText: 'მოძებნე სადგური...',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchController.clear();
                    _onSearchChanged('');
                  },
                )
              : null,
          filled: true,
          fillColor: Theme.of(
            context,
          ).colorScheme.surfaceContainerHighest.withOpacity(0.5),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(28),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(vertical: 0),
        ),
      ),
    );
  }

  Widget _buildTagFilters() {
    if (_topTags.isEmpty) return const SizedBox(height: 8);

    return SizedBox(
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        children: [
          _buildFilterChip(
            label: 'ყველა',
            isSelected: _selectedTag == null,
            onTap: () => _onTagSelected(null),
          ),
          ..._topTags.map(
            (tag) => _buildFilterChip(
              label: tag.name,
              isSelected: _selectedTag == tag.name,
              onTap: () => _onTagSelected(tag.name),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (_) => onTap(),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return _buildErrorState();
    }

    if (_stations.isEmpty) {
      return _buildEmptyState();
    }

    return _buildStationList();
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.cloud_off, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(_error ?? 'შეცდომა', style: const TextStyle(fontSize: 16)),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _loadInitial,
            icon: const Icon(Icons.refresh),
            label: const Text('თავიდან ცადე'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'ცარიერი ცარიერდება',
            style: TextStyle(fontSize: 16, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  Widget _buildStationList() {
    return StreamBuilder<MediaItem?>(
      stream: audioHandler.mediaItem,
      builder: (context, snapshot) {
        final currentlyPlayingUrl = snapshot.data?.id;

        return ListView.builder(
          controller: _scrollController,
          itemCount: _stations.length + (_hasMore ? 1 : 0),
          itemBuilder: (context, index) {
            if (index >= _stations.length) {
              return const Padding(
                padding: EdgeInsets.all(16),
                child: Center(
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              );
            }

            final station = _stations[index];
            return StationTile(
              station: station,
              isPlaying: station.url == currentlyPlayingUrl,
              onTap: () => _onStationTap(station),
            );
          },
        );
      },
    );
  }
}
