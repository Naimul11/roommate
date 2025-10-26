import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'report.dart';

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

  Future<DocumentSnapshot?> _checkApprovedRequest(String posterId) async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return null;

      final postId = postData['postId'] ?? '';
      if (postId.isEmpty) return null;

      // Check if there's an approved request for this post
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .collection('notifications')
          .where('posterId', isEqualTo: posterId)
          .where('postId', isEqualTo: postId)
          .where('status', isEqualTo: 'approved')
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        return snapshot.docs.first;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<int> _getReportCount(String email) async {
    try {
      final reportDoc = await FirebaseFirestore.instance
          .collection('reports')
          .doc(email)
          .get();
      
      if (reportDoc.exists) {
        return reportDoc.data()?['reportCount'] ?? 0;
      }
      return 0;
    } catch (e) {
      return 0;
    }
  }

  Future<void> _showReportsDialog(BuildContext context, String email) async {
    try {
      final reportsSnapshot = await FirebaseFirestore.instance
          .collection('reports')
          .doc(email)
          .collection('reports')
          .orderBy('timestamp', descending: true)
          .get();

      if (!context.mounted) return;

      if (reportsSnapshot.docs.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No reports found'),
            backgroundColor: Colors.blue,
          ),
        );
        return;
      }

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Row(
            children: [
              Icon(Icons.report, color: Colors.red.shade700),
              const SizedBox(width: 8),
              const Text('Reports'),
            ],
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: reportsSnapshot.docs.length,
              itemBuilder: (context, index) {
                final report = reportsSnapshot.docs[index].data();
                final timestamp = report['timestamp'] as Timestamp?;
                final dateStr = timestamp != null
                    ? DateFormat('MMM d, y').format(timestamp.toDate())
                    : 'N/A';

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                report['reporterName'] ?? 'Unknown',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                              ),
                            ),
                            Text(
                              dateStr,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Reason:',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade700,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          report['reason'] ?? 'No reason provided',
                          style: const TextStyle(fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading reports: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
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
                  _buildDetailRow('Floor', postData['floor']?.toString() ?? 'N/A', context),

                  const SizedBox(height: 24),

                  // Room Details
                  _buildSectionTitle('Room Information'),
                  const SizedBox(height: 12),
                  _buildDetailRow('Room Type', postData['roomType'] ?? 'N/A', context),
                  if (postData['roomType'] == 'Shared')
                    _buildDetailRow(
                      'Number of Roommates',
                      postData['numberOfRoommates']?.toString() ?? 'N/A',
                      context,
                    ),
                  _buildDetailRow('Facilities', postData['facilities'] ?? 'N/A', context),

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
                  _buildDetailRow('Gender', postData['gender'] ?? 'N/A', context),
                  _buildDetailRow('Preferred Religion', postData['preferredReligion'] ?? 'N/A', context),
                  _buildDetailRow('Smoker', postData['smoker'] ?? 'N/A', context),
                  _buildDetailRow('Pet Lover', postData['petLover'] ?? 'N/A', context),
                  _buildDetailRow('Cleanliness', postData['cleanliness'] ?? 'N/A', context),
                  _buildDetailRow('Age Range', postData['ageRange'] ?? 'N/A', context),

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
                  // Removed updated time

                  const SizedBox(height: 32),

                  // Contact Button
                  FutureBuilder<DocumentSnapshot?>(
                    future: _checkApprovedRequest(userId),
                    builder: (context, approvalSnapshot) {
                      // Check if there's an approved request
                      if (approvalSnapshot.hasData && 
                          approvalSnapshot.data != null && 
                          approvalSnapshot.data!.exists) {
                        final approvalData = approvalSnapshot.data!.data() as Map<String, dynamic>;
                        final posterEmail = approvalData['posterEmail'] ?? '';
                        final posterName = approvalData['posterName'] ?? 'Unknown';
                        
                        // Show contact info if approved
                        return FutureBuilder<int>(
                          future: _getReportCount(posterEmail),
                          builder: (context, reportSnapshot) {
                            final reportCount = reportSnapshot.data ?? 0;
                            
                            return Card(
                              color: Colors.green.shade50,
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(Icons.check_circle, color: Colors.green.shade700),
                                        const SizedBox(width: 8),
                                        const Expanded(
                                          child: Text(
                                            'Contact Information',
                                            style: TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                        if (reportCount > 0)
                                          GestureDetector(
                                            onTap: () => _showReportsDialog(context, posterEmail),
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                              decoration: BoxDecoration(
                                                color: Colors.red.shade100,
                                                borderRadius: BorderRadius.circular(12),
                                              ),
                                              child: Text(
                                                'Reported ${reportCount}x',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.red.shade900,
                                                ),
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                    const SizedBox(height: 16),
                                    _buildDetailRow('Email', posterEmail.isEmpty ? 'N/A' : posterEmail, context),
                                    _buildDetailRow('Phone', approvalData['posterPhone'] ?? 'N/A', context),
                                    _buildDetailRow('WhatsApp', approvalData['posterWhatsapp'] ?? 'N/A', context),
                                    const SizedBox(height: 16),
                                    SizedBox(
                                      width: double.infinity,
                                      child: OutlinedButton.icon(
                                        onPressed: () async {
                                          final result = await Navigator.of(context).push(
                                            MaterialPageRoute(
                                              builder: (_) => ReportPage(
                                                contactEmail: posterEmail,
                                                contactName: posterName,
                                              ),
                                            ),
                                          );
                                          // Refresh if report was submitted
                                          if (result == true && context.mounted) {
                                            // Force rebuild by calling setState in parent
                                            (context as Element).markNeedsBuild();
                                          }
                                        },
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: Colors.red.shade700,
                                          side: BorderSide(color: Colors.red.shade700),
                                          padding: const EdgeInsets.symmetric(vertical: 12),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                        ),
                                        icon: const Icon(Icons.report, size: 20),
                                        label: const Text(
                                          'Report This Contact',
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        );
                      }

                      // Show contact button if not approved
                      return FutureBuilder<Map<String, dynamic>?>(
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

  Widget _buildDetailRow(String label, String value, BuildContext context) {
    final isPhone = label == 'Phone' && value != 'N/A';
    final isWhatsApp = label == 'WhatsApp' && value != 'N/A';
    
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
            child: (isPhone || isWhatsApp)
                ? InkWell(
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: value));
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('$label copied to clipboard'),
                          duration: const Duration(seconds: 1),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    },
                    child: Row(
                      children: [
                        Flexible(
                          child: Text(
                            value,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(
                          Icons.copy,
                          size: 16,
                          color: Colors.blue.shade700,
                        ),
                      ],
                    ),
                  )
                : Text(
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

  void _showContactDialog(BuildContext context, Map<String, dynamic>? userData) async {
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

    final posterId = postData['userId'] ?? '';
    
    if (posterId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to identify poster'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Check if user is trying to contact themselves
    if (currentUser.uid == posterId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You cannot contact your own post'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    try {
      // Get current user's data (excluding NID)
      final currentUserDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .get();
      
      if (!currentUserDoc.exists) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Unable to load your profile'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      final currentUserData = currentUserDoc.data()!;
      
      // Get poster's data to include their name
      final posterDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(posterId)
          .get();
      
      final posterData = posterDoc.data() ?? {};
      
      // Prepare notification data (without NID)
      final notificationData = {
        'requesterId': currentUser.uid,
        'requesterName': currentUserData['nidName'] ?? 'Unknown',
        'requesterEmail': currentUserData['email'] ?? 'N/A',
        'requesterPhone': currentUserData['mobileNumber'] ?? 'N/A',
        'requesterWhatsapp': currentUserData['whatsappNumber'] ?? 'N/A',
        'posterName': posterData['nidName'] ?? 'Unknown', // Add poster name
        'posterEmail': posterData['email'] ?? 'N/A', // Add poster email
        'posterPhone': posterData['mobileNumber'] ?? 'N/A', // Add poster phone
        'posterWhatsapp': posterData['whatsappNumber'] ?? 'N/A', // Add poster whatsapp
        'postLocation': postData['location'] ?? 'Unknown',
        'postId': postData['postId'] ?? '',
        'postOwnerId': posterId, // Add post owner ID
        'status': 'pending',
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
      };

      // Create notification for poster
      await FirebaseFirestore.instance
          .collection('users')
          .doc(posterId)
          .collection('notifications')
          .add(notificationData);

      // Create notification for requester (to track request)
      await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .collection('notifications')
          .add({
        'posterId': posterId,
        'postOwnerId': posterId, // Add post owner ID
        'postLocation': postData['location'] ?? 'Unknown',
        'postId': postData['postId'] ?? '',
        'status': 'pending',
        'type': 'sent_request',
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Contact request sent successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error sending request: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
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
