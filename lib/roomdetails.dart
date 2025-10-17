import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class RoomDetailsPage extends StatelessWidget {
  final Map<String, dynamic> postData;

  const RoomDetailsPage({super.key, required this.postData});

  Future<Map<String, dynamic>?> _getUserInfo(String userId) async {
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();
      return userDoc.data();
    } catch (e) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final location = postData['location'] ?? 'Unknown location';
    final userId = postData['userId'] ?? '';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Room Details'),
        elevation: 0,
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Images Section
            _buildImagesSection(),

            // Main Content
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Location Title
                  Row(
                    children: [
                      Icon(Icons.location_on, color: Colors.blue.shade700, size: 28),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          location,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // Location & Floor Details
                  _buildSectionTitle('Location Details'),
                  const SizedBox(height: 12),
                  _buildDetailRow('Floor', postData['floor']?.toString() ?? 'N/A'),

                  const SizedBox(height: 24),

                  // Room Details
                  _buildSectionTitle('Room Information'),
                  const SizedBox(height: 12),
                  _buildDetailRow('Room Type', postData['roomType'] ?? 'N/A'),
                  if (postData['roomType'] == 'Shared')
                    _buildDetailRow(
                      'Number of Roommates',
                      postData['numberOfRoommates']?.toString() ?? 'N/A',
                    ),
                  _buildDetailRow('Facilities', postData['facilities'] ?? 'N/A'),

                  const SizedBox(height: 24),

                  // Cost Breakdown
                  _buildSectionTitle('Cost Breakdown'),
                  const SizedBox(height: 12),
                  _buildCostRow('Rent', postData['rent']?.toDouble() ?? 0),
                  _buildCostRow('Food', postData['food']?.toDouble() ?? 0),
                  _buildCostRow('Utilities', postData['utilities']?.toDouble() ?? 0),
                  const Divider(height: 24, thickness: 1),
                  _buildCostRow(
                    'Total Cost',
                    postData['totalCost']?.toDouble() ?? 0,
                    isBold: true,
                    isTotal: true,
                  ),

                  const SizedBox(height: 24),

                  // Preferences
                  _buildSectionTitle('Preferences'),
                  const SizedBox(height: 12),
                  _buildDetailRow('Gender', postData['gender'] ?? 'N/A'),
                  _buildDetailRow('Preferred Religion', postData['preferredReligion'] ?? 'N/A'),

                  const SizedBox(height: 24),

                  // Timestamps
                  if (postData['createdAt'] != null) ...[
                    Row(
                      children: [
                        Icon(Icons.access_time, size: 16, color: Colors.grey.shade600),
                        const SizedBox(width: 4),
                        Text(
                          'Posted: ${DateFormat('MMM d, y \'at\' h:mm a').format((postData['createdAt'] as Timestamp).toDate())}',
                          style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                  ],
                  if (postData['updatedAt'] != null)
                    Row(
                      children: [
                        Icon(Icons.update, size: 16, color: Colors.grey.shade600),
                        const SizedBox(width: 4),
                        Text(
                          'Updated: ${DateFormat('MMM d, y \'at\' h:mm a').format((postData['updatedAt'] as Timestamp).toDate())}',
                          style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                        ),
                      ],
                    ),

                  const SizedBox(height: 32),

                  // Contact Button
                  FutureBuilder<Map<String, dynamic>?>(
                    future: _getUserInfo(userId),
                    builder: (context, snapshot) {
                      return SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () => _showContactDialog(context, snapshot.data),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue.shade700,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 4,
                          ),
                          icon: const Icon(Icons.contact_phone, size: 24),
                          label: const Text(
                            'Contact the Person',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 20),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImagesSection() {
    final images = <String>[];
    if (postData['mainRoomImageUrl'] != null && postData['mainRoomImageUrl'].toString().isNotEmpty) {
      images.add(postData['mainRoomImageUrl']);
    }
    if (postData['mainSpotImageUrl'] != null && postData['mainSpotImageUrl'].toString().isNotEmpty) {
      images.add(postData['mainSpotImageUrl']);
    }
    if (postData['differentAngleImageUrl'] != null && postData['differentAngleImageUrl'].toString().isNotEmpty) {
      images.add(postData['differentAngleImageUrl']);
    }

    if (images.isEmpty) {
      return Container(
        height: 250,
        color: Colors.grey.shade300,
        child: Center(
          child: Icon(
            Icons.home,
            size: 80,
            color: Colors.grey.shade600,
          ),
        ),
      );
    }

    return SizedBox(
      height: 250,
      child: Stack(
        children: [
          PageView.builder(
            itemCount: images.length,
            itemBuilder: (context, index) {
              return GestureDetector(
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => _FullScreenGallery(
                        images: images,
                        initialIndex: index,
                      ),
                    ),
                  );
                },
                child: Image.network(
                  images[index],
                  width: double.infinity,
                  height: 250,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
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
                ),
              );
            },
          ),
          if (images.length > 1)
            Positioned(
              bottom: 12,
              right: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black.withAlpha(153),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${images.length} photos',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: Colors.black87,
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 15,
                color: Colors.grey.shade700,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCostRow(String label, double amount, {bool isBold = false, bool isTotal = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 15,
                color: isTotal ? Colors.black87 : Colors.grey.shade700,
                fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              '৳${amount.toStringAsFixed(0)}',
              style: TextStyle(
                fontSize: 15,
                fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
                color: isTotal ? Colors.green.shade700 : Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showContactDialog(BuildContext context, Map<String, dynamic>? userData) {
    final currentUser = FirebaseAuth.instance.currentUser;
    
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please log in to contact the person'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (userData == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to load contact information'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final name = userData['name'] ?? 'Unknown';
    final email = userData['email'] ?? 'N/A';
    final phone = userData['phone'] ?? 'N/A';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.person, color: Colors.blue.shade700),
            const SizedBox(width: 8),
            const Text('Contact Information'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildContactInfo(Icons.person_outline, 'Name', name),
            const SizedBox(height: 12),
            _buildContactInfo(Icons.email_outlined, 'Email', email),
            const SizedBox(height: 12),
            _buildContactInfo(Icons.phone_outlined, 'Phone', phone),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildContactInfo(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: Colors.grey.shade700),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// Full screen gallery widget
class _FullScreenGallery extends StatefulWidget {
  final List<String> images;
  final int initialIndex;
  const _FullScreenGallery({required this.images, required this.initialIndex});

  @override
  State<_FullScreenGallery> createState() => _FullScreenGalleryState();
}

class _FullScreenGalleryState extends State<_FullScreenGallery> {
  late PageController _pageController;
  late int _currentIndex;
  final TransformationController _transformationController = TransformationController();

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: _currentIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    _transformationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text('${_currentIndex + 1} / ${widget.images.length}'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: PageView.builder(
        controller: _pageController,
        itemCount: widget.images.length,
        onPageChanged: (index) {
          setState(() {
            _currentIndex = index;
            _transformationController.value = Matrix4.identity();
          });
        },
        itemBuilder: (context, index) {
          return InteractiveViewer(
            transformationController: _transformationController,
            minScale: 0.5,
            maxScale: 4.0,
            child: Center(
              child: Image.network(
                widget.images[index],
                fit: BoxFit.contain,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Center(
                    child: CircularProgressIndicator(
                      value: loadingProgress.expectedTotalBytes != null
                          ? loadingProgress.cumulativeBytesLoaded /
                              loadingProgress.expectedTotalBytes!
                          : null,
                      color: Colors.white,
                    ),
                  );
                },
                errorBuilder: (context, error, stackTrace) {
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.error_outline,
                          color: Colors.white,
                          size: 64,
                        ),
                        SizedBox(height: 16),
                        Text(
                          'Failed to load image',
                          style: TextStyle(color: Colors.white),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }
}
