import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:roommate/subpages/createnew.dart';
import 'package:roommate/subpages/menubar.dart';
import 'package:intl/intl.dart';

class FindRoommatePage extends StatefulWidget {
  const FindRoommatePage({super.key});

  @override
  State<FindRoommatePage> createState() => _FindRoommatePageState();
}

class _FindRoommatePageState extends State<FindRoommatePage> {
  final User? currentUser = FirebaseAuth.instance.currentUser;
  bool _isLoading = true;
  bool _canPostToday = true;
  DateTime? _lastPostDate;

  @override
  void initState() {
    super.initState();
    _checkPostEligibility();
  }

  Future<void> _checkPostEligibility() async {
    if (currentUser == null) return;

    setState(() => _isLoading = true);

    try {
      // Check if user has posted today by checking the document with today's date
      final now = DateTime.now();
      final todayDate =
          "${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";

      final docSnapshot = await FirebaseFirestore.instance
          .collection('posts')
          .doc(currentUser!.uid)
          .collection('post')
          .doc(todayDate)
          .get();

      if (docSnapshot.exists) {
        final data = docSnapshot.data();
        final createdAt = (data?['createdAt'] as Timestamp?)?.toDate();

        setState(() {
          _canPostToday = false;
          _lastPostDate = createdAt;
        });
      } else {
        setState(() {
          _canPostToday = true;
          _lastPostDate = null;
        });
      }
    } catch (e) {
      _showSnackBar('Error checking post eligibility: $e', isError: true);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _navigateToCreatePost({String? postId}) async {
    if (postId == null && !_canPostToday) {
      _showSnackBar(
        'You can only post once per day. Your last post was at ${DateFormat('h:mm a').format(_lastPostDate!)}',
        isError: true,
      );
      return;
    }

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CreateNewPostPage(postId: postId),
      ),
    );

    if (result == true) {
      // Refresh the page after creating/editing a post
      _checkPostEligibility();
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red.shade400 : Colors.green.shade400,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Find Roommate'),
        elevation: 0,
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
      ),
      drawer: const MenuDrawer(),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _checkPostEligibility,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildCreatePostButton(),
                      const SizedBox(height: 24),
                      _buildYourPostsSection(),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildCreatePostButton() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: _canPostToday
              ? [Colors.blue.shade600, Colors.blue.shade800]
              : [Colors.grey.shade400, Colors.grey.shade600],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: _canPostToday
                ? Colors.blue.withAlpha(76)
                : Colors.grey.withAlpha(76),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _canPostToday ? () => _navigateToCreatePost() : null,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              children: [
                Icon(
                  _canPostToday ? Icons.add_circle_outline : Icons.lock_clock,
                  size: 64,
                  color: Colors.white,
                ),
                const SizedBox(height: 16),
                Text(
                  _canPostToday ? 'Create New Post' : 'Post Limit Reached',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _canPostToday
                      ? 'Share your room details with potential roommates'
                      : 'You can post again tomorrow at 12:00 AM',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white.withAlpha(230),
                  ),
                ),
                if (!_canPostToday && _lastPostDate != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Last post: ${DateFormat('MMM d, y \'at\' h:mm a').format(_lastPostDate!)}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withAlpha(204),
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildYourPostsSection() {
    if (currentUser == null) {
      return const Center(child: Text('Please log in to see your posts'));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.article_outlined, color: Colors.blue.shade700, size: 28),
            const SizedBox(width: 8),
            const Text(
              'Your Posts',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 16),
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('posts')
              .doc(currentUser!.uid)
              .collection('post')
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(child: Text('Error: ${snapshot.error}'));
            }

            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(32.0),
                  child: CircularProgressIndicator(),
                ),
              );
            }

            // Get posts and sort by document ID (date) in descending order
            final posts = snapshot.data?.docs ?? [];
            posts.sort(
              (a, b) => b.id.compareTo(a.id),
            ); // Sort dates descending (newest first)

            if (posts.isEmpty) {
              return Container(
                padding: const EdgeInsets.all(48),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Column(
                  children: [
                    Icon(Icons.post_add, size: 64, color: Colors.grey.shade400),
                    const SizedBox(height: 16),
                    Text(
                      'No posts yet',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Create your first post to find roommates',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
              );
            }

            return ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: posts.length,
              itemBuilder: (context, index) {
                final post = posts[index];
                final data = post.data() as Map<String, dynamic>;
                final dateDocId = post.id;
                return _buildPostCard(dateDocId, data);
              },
            );
          },
        ),
      ],
    );
  }

  Widget _buildPostCard(String postId, Map<String, dynamic> data) {
  final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
  final location = data['location'] ?? 'Unknown location';
  final roomType = data['roomType'] ?? 'N/A';
  final floor = data['floor'] ?? 'N/A';
  final totalCost = data['totalCost']?.toDouble() ?? 0.0;
  final mainRoomImageUrl = data['mainRoomImageUrl'] as String?;

    // Check if this post was created today
    final isToday =
        createdAt != null && DateTime.now().difference(createdAt).inHours < 24;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: () => _showPostDetails(postId, data),
        borderRadius: BorderRadius.circular(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Large image at the top with edit button overlay
            Stack(
              children: [
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
                                  value:
                                      loadingProgress.expectedTotalBytes != null
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

                // Edit button in top right corner
                if (isToday)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: ElevatedButton.icon(
                      onPressed: () => _navigateToCreatePost(postId: postId),
                      icon: const Icon(Icons.edit, size: 16),
                      label: const Text('Edit', style: TextStyle(fontSize: 13)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue.shade700,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        elevation: 4,
                      ),
                    ),
                  ),
              ],
            ),

            // Content section below image
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Left side - Location
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
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
                                location,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(width: 16),

                  // Right side - Room info
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      // Room Type
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.bed,
                            color: Colors.grey.shade600,
                            size: 16,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            roomType == 'Shared' ? 'Shared' : 'Single',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),

                      // Floor
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.layers,
                            color: Colors.grey.shade600,
                            size: 16,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Floor: $floor',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),

                      // Total Cost
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '৳${totalCost.toStringAsFixed(0)}/mo',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.green.shade700,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showPostDetails(String postId, Map<String, dynamic> data) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (context, scrollController) {
          return Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: SingleChildScrollView(
              controller: scrollController,
              padding: const EdgeInsets.all(24),
              child: _buildDetailedPostView(postId, data),
            ),
          );
        },
      ),
    );
  }

  Widget _buildDetailedPostView(String postId, Map<String, dynamic> data) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Handle bar
        Center(
          child: Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),

        // Title
        Text(
          data['location'] ?? 'Room Details',
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),

        // Images
        if (data['mainRoomImageUrl'] != null)
          _buildDetailImage('Main Room', data['mainRoomImageUrl']),
        if (data['mainSpotImageUrl'] != null)
          _buildDetailImage('Main Spot', data['mainSpotImageUrl']),
        if (data['differentAngleImageUrl'] != null)
          _buildDetailImage('Different Angle', data['differentAngleImageUrl']),

        const Divider(height: 32),

        // Location details
        _buildDetailRow('Location', data['location'] ?? 'N/A'),
        _buildDetailRow('Floor', data['floor']?.toString() ?? 'N/A'),

        const Divider(height: 32),

        // Room details
        _buildDetailRow('Room Type', data['roomType'] ?? 'N/A'),
        _buildDetailRow('Facilities', data['facilities'] ?? 'N/A'),

        const Divider(height: 32),

        // Cost breakdown
        const Text(
          'Cost Breakdown',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        _buildDetailRow('Rent', '৳${data['rent']?.toStringAsFixed(0) ?? '0'}'),
        _buildDetailRow('Food', '৳${data['food']?.toStringAsFixed(0) ?? '0'}'),
        _buildDetailRow(
          'Utilities',
          '৳${data['utilities']?.toStringAsFixed(0) ?? '0'}',
        ),
        _buildDetailRow(
          'Total',
          '৳${data['totalCost']?.toStringAsFixed(0) ?? '0'}',
          isBold: true,
        ),

        const Divider(height: 32),

        // Preferences
        const Text(
          'Preferences',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        _buildDetailRow('Gender', data['gender'] ?? 'N/A'),
        _buildDetailRow(
          'Preferred Religion',
          data['preferredReligion'] ?? 'N/A',
        ),
        _buildDetailRow(
          'Number of Roommates',
          data['numberOfRoommates']?.toString() ?? 'N/A',
        ),

        const SizedBox(height: 24),

        // Timestamps
        if (data['createdAt'] != null)
          Text(
            'Posted: ${DateFormat('MMM d, y \'at\' h:mm a').format((data['createdAt'] as Timestamp).toDate())}',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
        if (data['updatedAt'] != null)
          Text(
            'Updated: ${DateFormat('MMM d, y \'at\' h:mm a').format((data['updatedAt'] as Timestamp).toDate())}',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
      ],
    );
  }

  Widget _buildDetailImage(String title, String url) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.network(
            url,
            width: double.infinity,
            height: 200,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              return Container(
                height: 200,
                color: Colors.grey.shade300,
                child: Icon(
                  Icons.image_not_supported,
                  size: 48,
                  color: Colors.grey.shade600,
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildDetailRow(String label, String value, {bool isBold = false}) {
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
                fontSize: 14,
                color: Colors.grey.shade700,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 14,
                fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
