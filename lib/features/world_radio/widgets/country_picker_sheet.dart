import 'package:flutter/material.dart';
import '../radio_browser_service.dart';

/// Modal bottom sheet ქვეყნების ასარჩევად
///
/// გამოყენება:
/// ```dart
/// final country = await showModalBottomSheet<CountryInfo?>(
///   context: context,
///   isScrollControlled: true,
///   builder: (_) => CountryPickerSheet(countries: countries),
/// );
/// ```
class CountryPickerSheet extends StatefulWidget {
  final List<CountryInfo> countries;
  final CountryInfo? selectedCountry;

  const CountryPickerSheet({
    super.key,
    required this.countries,
    this.selectedCountry,
  });

  @override
  State<CountryPickerSheet> createState() => _CountryPickerSheetState();
}

class _CountryPickerSheetState extends State<CountryPickerSheet> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<CountryInfo> get _filteredCountries {
    if (_query.isEmpty) return widget.countries;
    final lowerQuery = _query.toLowerCase();
    return widget.countries
        .where((c) => c.name.toLowerCase().contains(lowerQuery))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              _buildHandle(),
              _buildHeader(),
              _buildSearchBar(),
              const Divider(height: 1),
              Expanded(child: _buildList(scrollController)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHandle() {
    return Container(
      width: 40,
      height: 4,
      margin: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: Colors.grey[600],
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
      child: Row(
        children: [
          Text(
            'აირჩიე ქვეყანა',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          const Spacer(),
          if (widget.selectedCountry != null)
            TextButton.icon(
              onPressed: () => Navigator.pop(context, _ClearSelection()),
              icon: const Icon(Icons.clear, size: 18),
              label: const Text('გასუფთავება'),
            ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: TextField(
        controller: _searchController,
        autofocus: false,
        onChanged: (value) => setState(() => _query = value.trim()),
        decoration: InputDecoration(
          hintText: 'მოძებნე ქვეყანა...',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: _query.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _query = '');
                  },
                )
              : null,
          filled: true,
          fillColor: Theme.of(
            context,
          ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(24),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(vertical: 0),
        ),
      ),
    );
  }

  Widget _buildList(ScrollController scrollController) {
    final countries = _filteredCountries;

    if (countries.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 48, color: Colors.grey[400]),
            const SizedBox(height: 8),
            const Text('ქვეყანა ვერ მოიძებნა'),
          ],
        ),
      );
    }

    return ListView.builder(
      controller: scrollController,
      itemCount: countries.length,
      itemBuilder: (context, index) {
        final country = countries[index];
        final isSelected = widget.selectedCountry?.code == country.code;

        return ListTile(
          leading: _buildFlag(country.code),
          title: Text(
            country.name,
            style: TextStyle(
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              color: isSelected ? Theme.of(context).colorScheme.primary : null,
            ),
          ),
          subtitle: Text('${country.stationCount} სადგური'),
          trailing: isSelected
              ? Icon(
                  Icons.check_circle,
                  color: Theme.of(context).colorScheme.primary,
                )
              : null,
          onTap: () => Navigator.pop(context, country),
        );
      },
    );
  }

  Widget _buildFlag(String countryCode) {
    if (countryCode.length != 2) {
      return _buildFlagFallback();
    }

    // Unicode flag emoji-ის გენერაცია ISO 3166 country code-დან
    // ASCII A=65, Regional Indicator A=0x1F1E6 — სხვაობა 127397
    try {
      final emoji = countryCode
          .toUpperCase()
          .codeUnits
          .map((c) => String.fromCharCode(c + 127397))
          .join();
      return Text(emoji, style: const TextStyle(fontSize: 28));
    } catch (e) {
      return _buildFlagFallback();
    }
  }

  Widget _buildFlagFallback() {
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: Colors.grey[700],
        borderRadius: BorderRadius.circular(4),
      ),
      child: const Icon(Icons.flag, color: Colors.white, size: 16),
    );
  }
}

/// Sentinel class — "clear selection" action-ისთვის
class _ClearSelection extends CountryInfo {
  _ClearSelection() : super(name: '', code: '', stationCount: 0);
}

/// Helper — გადაამოწმე ცარიერი action იყო თუ რეალური country
bool isClearSelection(CountryInfo? result) {
  return result is _ClearSelection;
}
