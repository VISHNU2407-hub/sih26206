import 'package:flutter/material.dart';
import '../models/hospital_model.dart';
import '../services/location_service.dart';
import '../services/hospital_service.dart';
import '../widgets/hospital_card.dart';

class MedicalEmergencyScreen extends StatefulWidget {
  const MedicalEmergencyScreen({super.key});

  @override
  State<MedicalEmergencyScreen> createState() => _MedicalEmergencyScreenState();
}

class _MedicalEmergencyScreenState extends State<MedicalEmergencyScreen> {
  List<Hospital> _hospitals = [];
  List<Hospital> _filteredHospitals = [];
  bool _isLoading = false;
  bool _hasPermission = false;
  String? _errorMessage;
  String _searchQuery = '';
  String _contactFilter = 'all'; // 'all', 'available', 'not_available'
  final TextEditingController _searchController = TextEditingController();

  /// How many hospitals to show initially for performance.
  int _initialDisplayCount = 100;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final hasPermission = await LocationService.checkLocationPermission();

    if (!hasPermission) {
      final requested = await LocationService.requestLocationPermission();
      if (!requested) {
        setState(() {
          _isLoading = false;
          _hasPermission = false;
          _errorMessage =
              'Location permission is required to find nearest hospitals.';
        });
        return;
      }
    }

    final position = await LocationService.getCurrentPosition();

    if (position == null) {
      final serviceEnabled = await LocationService.isLocationServiceEnabled();
      setState(() {
        _isLoading = false;
        _hasPermission = true;
        _errorMessage = serviceEnabled
            ? 'Unable to get your location. Please try again.'
            : 'Location services are disabled. Please enable them.';
      });
      return;
    }

    try {
      final hospitals = await HospitalService.getNearestHospitals(
        position.latitude,
        position.longitude,
      );

      setState(() {
        _isLoading = false;
        _hasPermission = true;
        _hospitals = hospitals;
        _filteredHospitals = hospitals;
        if (hospitals.isEmpty) {
          _errorMessage = 'No hospitals found in your area.';
        }
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _hasPermission = true;
        _errorMessage = 'Failed to load hospitals. Please try again.';
      });
    }
  }

  void _filterHospitals(String query) {
    setState(() {
      _searchQuery = query.toLowerCase();
      _applyFilters();
    });
  }

  void _applyFilters() {
    var filtered = _hospitals;

    // Apply search filter
    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((hospital) {
        return hospital.name.toLowerCase().contains(_searchQuery) ||
            hospital.address.toLowerCase().contains(_searchQuery);
      }).toList();
    }

    // Apply contact filter
    if (_contactFilter == 'available') {
      filtered = filtered.where((hospital) => hospital.hasPhone).toList();
    } else if (_contactFilter == 'not_available') {
      filtered = filtered.where((hospital) => !hospital.hasPhone).toList();
    }

    setState(() {
      _filteredHospitals = filtered;
    });
  }

  Future<void> _retry() async {
    await _loadData();
  }

  Future<void> _openLocationSettings() async {
    await LocationService.openLocationSettings();
    await _loadData();
  }

  void _onContactFilterChanged(String filter) {
    setState(() {
      _contactFilter = filter;
      _applyFilters();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Icon(Icons.medical_services, size: 24),
            const SizedBox(width: 12),
            const Text('Medical Emergency'),
          ],
        ),
        backgroundColor: Colors.red,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Colors.red),
            SizedBox(height: 16),
            Text(
              'Loading hospitals near you...',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 64, color: Colors.grey.shade400),
              const SizedBox(height: 16),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.grey.shade700),
              ),
              const SizedBox(height: 24),
              if (!_hasPermission) ...[
                ElevatedButton.icon(
                  onPressed: _retry,
                  icon: const Icon(Icons.location_on),
                  label: const Text('Grant Permission'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                  ),
                ),
              ] else ...[
                ElevatedButton.icon(
                  onPressed: _openLocationSettings,
                  icon: const Icon(Icons.settings),
                  label: const Text('Open Settings'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextButton.icon(
                  onPressed: _retry,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Try Again'),
                ),
              ],
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        _buildLocationHeader(),
        _buildFilterSection(),
        Expanded(child: _buildHospitalList()),
      ],
    );
  }

  Widget _buildLocationHeader() {
    final total = _filteredHospitals.length;
    final hasMore = total > _initialDisplayCount;
    final displayCount = hasMore ? _initialDisplayCount : total;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        border: Border(
          bottom: BorderSide(color: Colors.red.shade200, width: 1),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.near_me, color: Colors.red.shade700, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _searchQuery.isNotEmpty || _contactFilter != 'all'
                  ? '$total hospitals found'
                  : hasMore
                      ? 'Nearest $displayCount+ hospitals near you'
                      : '$displayCount hospitals near you',
              style: TextStyle(
                fontSize: 15,
                color: Colors.red.shade900,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          IconButton(
            onPressed: _retry,
            icon: const Icon(Icons.refresh),
            color: Colors.red.shade700,
            tooltip: 'Refresh',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterSection() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: Colors.white,
      child: Column(
        children: [
          TextField(
            controller: _searchController,
            onChanged: _filterHospitals,
            decoration: InputDecoration(
              hintText: 'Search hospitals by name...',
              hintStyle: TextStyle(fontSize: 13, color: Colors.grey.shade500),
              prefixIcon: const Icon(Icons.search, size: 20),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 20),
                      onPressed: () {
                        _searchController.clear();
                        _filterHospitals('');
                      },
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.red.shade400, width: 2),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 10,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _buildFilterChip('All Hospitals', 'all'),
              const SizedBox(width: 8),
              _buildFilterChip('Contacts Available', 'available'),
              const SizedBox(width: 8),
              _buildFilterChip('Contacts Not Available', 'not_available'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _contactFilter == value;
    return Expanded(
      child: InkWell(
        onTap: () => _onContactFilterChanged(value),
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? Colors.red.shade600 : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected ? Colors.red.shade600 : Colors.grey.shade300,
            ),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isSelected ? Colors.white : Colors.grey.shade700,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    );
  }

  Widget _buildHospitalList() {
    final displayList = _filteredHospitals.take(_initialDisplayCount).toList();
    final totalCount = _filteredHospitals.length;
    final hasMore = totalCount > _initialDisplayCount;

    if (_filteredHospitals.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.search_off, size: 56, color: Colors.grey.shade400),
              const SizedBox(height: 16),
              Text(
                _searchQuery.isNotEmpty
                    ? 'No hospitals found matching "$_searchQuery"'
                    : 'No hospitals found in your area.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 15, color: Colors.grey.shade700),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: displayList.length + (hasMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index >= displayList.length) {
          // Show more button
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Center(
              child: TextButton(
                onPressed: () {
                  // Expand to show all (or up to a larger limit)
                  setState(() {
                    // For simplicity, we remove the limit so all show
                    // In a real app, consider incremental loading
                    _initialDisplayCount = totalCount;
                  });
                },
                child: Text(
                  'Show all $totalCount hospitals',
                  style: TextStyle(
                    color: Colors.red.shade700,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          );
        }
        return HospitalCard(hospital: displayList[index]);
      },
    );
  }
}
