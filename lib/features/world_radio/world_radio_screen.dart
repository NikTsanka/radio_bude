import 'dart:async';
import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import '../../core/constants.dart';
import '../../main.dart';
import 'radio_browser_service.dart';
import 'station_model.dart';
import 'widgets/country_picker_sheet.dart';
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
  List<CountryInfo> _countries = [];

  bool _isLoading = false;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  String? _error;

  String _searchQuery = '';
  String? _selectedTag;
  CountryInfo? _selectedCountry;
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
      final results = await Future.wait([
        _fetchStations(offset: 0),
        if (_topTags.isEmpty)
          _service.getTopTags(limit: 20)
        else
          Future.value(_topTags),
        if (_countries.isEmpty)
          _service.getCountries()
        else
          Future.value(_countries),
      ]);

      if (!mounted) return;

      setState(() {
        _stations = results[0] as List<Station>;
        _topTags = results[1] as List<TagInfo>;
        _countries = results[2] as List<CountryInfo>;
        _isLoading = false;
        _hasMore = _stations.length >= _pageSize;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = 'Failed to load stations';
      });
      print('🔴 Load error: $e');
    }
  }

  Future<List<Station>> _fetchStations({required int offset}) async {
    // თუ რომელიმე ფილტრი/ძებნა აქტიურია — search ვცადოთ
    if (_searchQuery.isNotEmpty ||
        _selectedTag != null ||
        _selectedCountry != null) {
      return _service.searchStations(
        name: _searchQuery.isNotEmpty ? _searchQuery : null,
        tag: _selectedTag,
        countryCode: _selectedCountry?.code,
        limit: _pageSize,
        offset: offset,
      );
    }
    // სხვა შემთხვევაში — top stations
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
    setState(() => _selectedTag = tag);
    _loadInitial();
  }

  Future<void> _openCountryPicker() async {
    if (_countries.isEmpty) {
      // თუ ქვეყნები ჯერ არ ჩაგვიტვირთვია
      try {
        final countries = await _service.getCountries();
        if (!mounted) return;
        setState(() => _countries = countries);
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to load countries')),
        );
        return;
      }
    }

    final result = await showModalBottomSheet<CountryInfo?>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CountryPickerSheet(
        countries: _countries,
        selectedCountry: _selectedCountry,
      ),
    );

    if (!mounted) return;

    if (result == null) return; // user dismissed without selecting

    if (isClearSelection(result)) {
      // "გასუფთავება" ღილაკი დაიჭირა
      setState(() => _selectedCountry = null);
    } else {
      setState(() => _selectedCountry = result);
    }

    _loadInitial();
  }

  void _clearAllFilters() {
    _searchController.clear();
    setState(() {
      _searchQuery = '';
      _selectedTag = null;
      _selectedCountry = null;
    });
    _loadInitial();
  }

  Future<void> _onStationTap(Station station) async {
    _service.registerClick(station.stationUuid);

    await audioHandler.playStation(
      url: station.url,
      name: station.name,
      country: station.country,
      favicon: station.favicon,
    );

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

  /// Radio Bude-ზე დაბრუნება
  Future<void> _backToRadioBude() async {
    await audioHandler.playRadioBude();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('🎙️ Radio Hangi'),
          duration: Duration(seconds: 2),
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
            _buildFilterChips(),
            const Divider(height: 1),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'World Radio',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          // Radio Bude-ზე დაბრუნების ღილაკი — მხოლოდ მაშინ ჩანს, როცა სხვა სადგური უკრავს
          StreamBuilder<MediaItem?>(
            stream: audioHandler.mediaItem,
            builder: (context, snapshot) {
              final isPlayingRadioBude = snapshot.data?.album == Constants.radioBudeName;

              if (isPlayingRadioBude) {
                return Text(
                  '${_stations.length}',
                  style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                );
              }

              return IconButton(
                onPressed: _backToRadioBude,
                icon: const Icon(Icons.home),
                tooltip: 'Back to Radio Hangi',
                color: Theme.of(context).colorScheme.primary,
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _searchController,
              onChanged: _onSearchChanged,
              decoration: InputDecoration(
                hintText: 'Search stations...',
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
                ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(28),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
              ),
            ),
          ),
          const SizedBox(width: 8),
          // ქვეყნის ფილტრის ღილაკი
          _buildCountryButton(),
        ],
      ),
    );
  }

  Widget _buildCountryButton() {
    final isSelected = _selectedCountry != null;

    return Material(
      color: isSelected
          ? Theme.of(context).colorScheme.primary
          : Theme.of(
              context,
            ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: _openCountryPicker,
        child: SizedBox(
          width: 48,
          height: 48,
          child: Icon(
            Icons.public,
            color: isSelected ? Theme.of(context).colorScheme.onPrimary : null,
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChips() {
    final hasActiveFilters =
        _selectedTag != null ||
        _selectedCountry != null ||
        _searchQuery.isNotEmpty;

    return SizedBox(
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        children: [
          // არჩეული ქვეყანა — ვიზუალური chip
          if (_selectedCountry != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
              child: InputChip(
                avatar: const Icon(Icons.location_on, size: 18),
                label: Text(_selectedCountry!.name),
                onDeleted: () {
                  setState(() => _selectedCountry = null);
                  _loadInitial();
                },
              ),
            ),

          // "ყველა" / Tag chips
          _buildFilterChip(
            label: 'All',
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

          // "გასუფთავება" — თუ რამე ფილტრი აქტიურია
          if (hasActiveFilters)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
              child: ActionChip(
                avatar: const Icon(Icons.clear, size: 18),
                label: const Text('Clear'),
                onPressed: _clearAllFilters,
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
          Text(_error ?? 'Error', style: const TextStyle(fontSize: 16)),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _loadInitial,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
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
            'No stations found',
            style: TextStyle(fontSize: 16, color: Colors.grey[600]),
          ),
          const SizedBox(height: 16),
          TextButton.icon(
            onPressed: _clearAllFilters,
            icon: const Icon(Icons.clear_all),
            label: const Text('Clear filters'),
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
