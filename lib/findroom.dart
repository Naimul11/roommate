import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:roommate/subpages/menubar.dart';
import 'package:roommate/subpages/roomdetails.dart';
import 'package:intl/intl.dart';
import 'package:roommate/utils/bangladesh_locations.dart';

class FindRoomPage extends StatefulWidget {
  const FindRoomPage({super.key});

  @override
  State<FindRoomPage> createState() => _FindRoomPageState();
}

class _FindRoomPageState extends State<FindRoomPage> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _allPosts = [];
  bool _matchPreferences = false;

  // User filter preferences
  String _filterSmoker = 'Any';
  String _filterPetLover = 'Any';
  String _filterCleanliness = 'Any';
  String _filterReligion = 'Any';
  String _filterAgeRange = 'Any';

  // Location filters
  String? _filterDivision;
  String? _filterDistrict;
  List<String> _availableDistricts = [];

  @override
  void initState() {
    super.initState();
    _loadAllPosts();
    _loadUserPreferences();
  }

  Future<void> _loadUserPreferences() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (userDoc.exists) {
        final userData = userDoc.data()!;
        setState(() {
          _filterSmoker = userData['smoker'] ?? 'Any';
          _filterPetLover = userData['petLover'] ?? 'Any';
          _filterCleanliness = userData['cleanliness'] ?? 'Any';
          _filterReligion = userData['religion'] ?? 'Any';
          _filterAgeRange = userData['ageRange'] ?? 'Any';
        });
      }
    } catch (e) {
      // Silently fail if user preferences not found
    }
  }

  Future<void> _loadAllPosts() async {
    setState(() => _isLoading = true);

    try {
      // Use collectionGroup to query all 'post' subcollections across all users
      final postsSnapshot = await FirebaseFirestore.instance
          .collectionGroup('post')
          .get();

      List<Map<String, dynamic>> posts = [];

      for (var postDoc in postsSnapshot.docs) {
        final postData = postDoc.data();
        // Extract userId from the document path: posts/{userId}/post/{postId}
        final pathSegments = postDoc.reference.path.split('/');
        final userId = pathSegments.length >= 2 ? pathSegments[1] : '';

        posts.add({'userId': userId, 'postId': postDoc.id, ...postData});
      }

      // Sort by createdAt descending (newest first)
      posts.sort((a, b) {
        final aTime = (a['createdAt'] as Timestamp?)?.toDate();
        final bTime = (b['createdAt'] as Timestamp?)?.toDate();
        if (aTime == null || bTime == null) return 0;
        return bTime.compareTo(aTime);
      });

      setState(() {
        _allPosts = posts;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  List<Map<String, dynamic>> _getFilteredPosts() {
    List<Map<String, dynamic>> filtered = _allPosts;

    // Apply location filters
    if (_filterDivision != null && _filterDivision!.isNotEmpty) {
      filtered = filtered.where((post) {
        return post['division'] == _filterDivision;
      }).toList();
    }

    if (_filterDistrict != null && _filterDistrict!.isNotEmpty) {
      filtered = filtered.where((post) {
        return post['district'] == _filterDistrict;
      }).toList();
    }

    // Apply preference filters only if enabled
    if (_matchPreferences) {
      filtered = filtered.where((post) {
        return _matchesPreference(post['smoker'], _filterSmoker) &&
            _matchesPreference(post['petLover'], _filterPetLover) &&
            _matchesPreference(post['cleanliness'], _filterCleanliness) &&
            _matchesPreference(post['preferredReligion'], _filterReligion) &&
            _matchesPreference(post['ageRange'], _filterAgeRange);
      }).toList();
    }

    return filtered;
  }

  bool _matchesPreference(String? postValue, String filterValue) {
    // If filter is 'Any', it matches everything
    if (filterValue == 'Any') return true;

    // If post value is 'Any', it matches everything
    if (postValue == 'Any') return true;

    // Otherwise, they must match exactly
    return postValue == filterValue;
  }

  @override
  Widget build(BuildContext context) {
    final filteredPosts = _getFilteredPosts();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Find Room'),
        elevation: 0,
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
      ),
      drawer: const MenuDrawer(),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                RefreshIndicator(
                  onRefresh: _loadAllPosts,
                  child: filteredPosts.isEmpty
                      ? _buildEmptyState()
                      : ListView.builder(
                          padding: const EdgeInsets.only(
                            left: 16,
                            right: 16,
                            top: 16,
                            bottom: 80, // Space for filter button
                          ),
                          itemCount: filteredPosts.length,
                          itemBuilder: (context, index) {
                            final post = filteredPosts[index];
                            return _buildPostCard(post);
                          },
                        ),
                ),
                // Filter button at bottom center
                Positioned(
                  bottom: 16,
                  left: 0,
                  right: 0,
                  child: Center(child: _buildFilterButton()),
                ),
              ],
            ),
    );
  }

  Widget _buildFilterButton() {
    return Container(
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(26),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        borderRadius: BorderRadius.circular(30),
        color: _matchPreferences ? Colors.green : Colors.blue.shade700,
        child: InkWell(
          borderRadius: BorderRadius.circular(30),
          onTap: () => _showFilterMenu(context),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _matchPreferences
                      ? Icons.filter_alt
                      : Icons.filter_alt_outlined,
                  color: Colors.white,
                  size: 22,
                ),
                const SizedBox(width: 8),
                Text(
                  _matchPreferences ? 'Matching Preferences' : 'Filter',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showFilterMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Container(
            padding: const EdgeInsets.all(24),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Filter Options',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade800,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Location Filters Section
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Location',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: _filterDivision,
                    decoration: InputDecoration(
                      labelText: 'Division',
                      prefixIcon: const Icon(Icons.map),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                    ),
                    items: [
                      const DropdownMenuItem(
                        value: null,
                        child: Text('All Divisions'),
                      ),
                      ...BangladeshLocations.divisions.map(
                        (division) => DropdownMenuItem(
                          value: division,
                          child: Text(division),
                        ),
                      ),
                    ],
                    onChanged: (value) {
                      setModalState(() {
                        _filterDivision = value;
                        _filterDistrict = null;
                        _availableDistricts = value != null
                            ? BangladeshLocations.getDistricts(value)
                            : [];
                      });
                      setState(() {
                        _filterDivision = value;
                        _filterDistrict = null;
                        _availableDistricts = value != null
                            ? BangladeshLocations.getDistricts(value)
                            : [];
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: _filterDistrict,
                    decoration: InputDecoration(
                      labelText: 'District',
                      prefixIcon: const Icon(Icons.location_city),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                    ),
                    items: [
                      const DropdownMenuItem(
                        value: null,
                        child: Text('All Districts'),
                      ),
                      ..._availableDistricts.map(
                        (district) => DropdownMenuItem(
                          value: district,
                          child: Text(district),
                        ),
                      ),
                    ],
                    onChanged: _filterDivision == null
                        ? null
                        : (value) {
                            setModalState(() {
                              _filterDistrict = value;
                            });
                            setState(() {
                              _filterDistrict = value;
                            });
                          },
                  ),
                  const SizedBox(height: 24),
                  const Divider(),
                  const SizedBox(height: 16),

                  // Preference Filters Section
                  ListTile(
                    leading: Icon(
                      _matchPreferences
                          ? Icons.check_circle
                          : Icons.circle_outlined,
                      color: _matchPreferences ? Colors.green : Colors.grey,
                    ),
                    title: const Text(
                      'Match Preferences',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      _matchPreferences
                          ? 'Showing posts matching your preferences'
                          : 'Show posts that match your preferences',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    onTap: () {
                      setState(() {
                        _matchPreferences = !_matchPreferences;
                      });
                      Navigator.pop(context);
                    },
                  ),
                  const Divider(),
                  ListTile(
                    leading: Icon(Icons.edit, color: Colors.blue.shade700),
                    title: const Text(
                      'Edit Preferences',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      'Adjust your filter preferences',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      _showEditPreferencesDialog();
                    },
                  ),
                  const SizedBox(height: 16),

                  // Clear Filters Button
                  if (_filterDivision != null || _filterDistrict != null)
                    TextButton.icon(
                      onPressed: () {
                        setState(() {
                          _filterDivision = null;
                          _filterDistrict = null;
                          _availableDistricts = [];
                        });
                        Navigator.pop(context);
                      },
                      icon: const Icon(Icons.clear),
                      label: const Text('Clear Location Filters'),
                      style: TextButton.styleFrom(foregroundColor: Colors.red),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showEditPreferencesDialog() {
    String tempSmoker = _filterSmoker;
    String tempPetLover = _filterPetLover;
    String tempReligion = _filterReligion;
    String tempAgeRange = _filterAgeRange;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Edit Filter Preferences'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildPreferenceDropdown(
                  label: 'Smoker',
                  value: tempSmoker,
                  items: const ['Any', 'Yes', 'No'],
                  onChanged: (value) {
                    setDialogState(() {
                      tempSmoker = value!;
                    });
                  },
                ),
                const SizedBox(height: 16),
                _buildPreferenceDropdown(
                  label: 'Pet Lover',
                  value: tempPetLover,
                  items: const ['Any', 'Yes', 'No'],
                  onChanged: (value) {
                    setDialogState(() {
                      tempPetLover = value!;
                    });
                  },
                ),
                const SizedBox(height: 16),
                // Cleanliness preference removed
                _buildPreferenceDropdown(
                  label: 'Religion',
                  value: tempReligion,
                  items: const [
                    'Any',
                    'Islam',
                    'Hindu',
                    'Christian',
                    'Buddhist',
                  ],
                  onChanged: (value) {
                    setDialogState(() {
                      tempReligion = value!;
                    });
                  },
                ),
                const SizedBox(height: 16),
                _buildPreferenceDropdown(
                  label: 'Age Range',
                  value: tempAgeRange,
                  items: const ['Any', '<20', '<30', '<40'],
                  onChanged: (value) {
                    setDialogState(() {
                      tempAgeRange = value!;
                    });
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _filterSmoker = tempSmoker;
                  _filterPetLover = tempPetLover;
                  _filterReligion = tempReligion;
                  _filterAgeRange = tempAgeRange;
                });
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Filter preferences updated'),
                    duration: Duration(seconds: 2),
                  ),
                );
              },
              child: const Text('Apply'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreferenceDropdown({
    required String label,
    required String value,
    required List<String> items,
    required Function(String?) onChanged,
  }) {
    return DropdownButtonFormField<String>(
      value: value,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
      ),
      items: items.map((item) {
        return DropdownMenuItem(value: item, child: Text(item));
      }).toList(),
      onChanged: onChanged,
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(48.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.search_off, size: 80, color: Colors.grey.shade400),
              const SizedBox(height: 24),
              Text(
                'No rooms available',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade700,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Check back later for new listings',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPostCard(Map<String, dynamic> data) {
    final location = data['location'] ?? 'Unknown location';
    final division = data['division'] ?? '';
    final district = data['district'] ?? '';
    final address = data['address'] ?? '';
    final roomType = data['roomType'] ?? 'N/A';
    final floor = data['floor'] ?? 'N/A';
    final totalCost = data['totalCost']?.toDouble() ?? 0.0;
    final mainRoomImageUrl = data['mainRoomImageUrl'] as String?;
    final createdAt = (data['createdAt'] as Timestamp?)?.toDate();

    // Build location display
    String locationDisplay = '';
    if (division.isNotEmpty && district.isNotEmpty) {
      locationDisplay = '$district, $division';
      if (address.isNotEmpty) {
        locationDisplay = '$address, $locationDisplay';
      }
    } else if (location.isNotEmpty) {
      locationDisplay = location;
    } else {
      locationDisplay = 'Unknown location';
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => RoomDetailsPage(postData: data),
            ),
          );
        },
        borderRadius: BorderRadius.circular(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Large image at the top
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(16),
              ),
              child: mainRoomImageUrl != null
                  ? Image.network(
                      mainRoomImageUrl,
                      width: double.infinity,
                      height: 200,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          width: double.infinity,
                          height: 200,
                          color: Colors.grey.shade300,
                          child: Icon(
                            Icons.image_not_supported,
                            size: 64,
                            color: Colors.grey.shade600,
                          ),
                        );
                      },
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return Container(
                          width: double.infinity,
                          height: 200,
                          color: Colors.grey.shade200,
                          child: Center(
                            child: CircularProgressIndicator(
                              value: loadingProgress.expectedTotalBytes != null
                                  ? loadingProgress.cumulativeBytesLoaded /
                                        loadingProgress.expectedTotalBytes!
                                  : null,
                            ),
                          ),
                        );
                      },
                    )
                  : Container(
                      width: double.infinity,
                      height: 200,
                      color: Colors.grey.shade300,
                      child: Icon(
                        Icons.home,
                        size: 64,
                        color: Colors.grey.shade600,
                      ),
                    ),
            ),

            // Content section below image
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Location
                  Row(
                    children: [
                      Icon(
                        Icons.location_on,
                        color: Colors.blue.shade700,
                        size: 20,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          locationDisplay,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Room details row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Room Type
                      _buildInfoChip(
                        Icons.bed,
                        roomType == 'Shared' ? 'Shared' : 'Single',
                        Colors.purple,
                      ),

                      // Floor
                      _buildInfoChip(
                        Icons.layers,
                        'Floor: $floor',
                        Colors.orange,
                      ),

                      // Total Cost
                      _buildInfoChip(
                        Icons.payments,
                        '৳${totalCost.toStringAsFixed(0)}',
                        Colors.green,
                      ),
                    ],
                  ),

                  // Posted date
                  if (createdAt != null) ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Icon(
                          Icons.access_time,
                          size: 14,
                          color: Colors.grey.shade600,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Posted ${DateFormat('MMM d, y').format(createdAt)}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withAlpha(26),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withAlpha(77), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
