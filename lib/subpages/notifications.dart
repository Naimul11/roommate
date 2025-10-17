import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:roommate/subpages/roomdetails.dart';

class NotificationsPage extends StatelessWidget {
  const NotificationsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Notifications'),
          backgroundColor: Colors.blue.shade700,
          foregroundColor: Colors.white,
        ),
        body: const Center(
          child: Text('Please log in to view notifications'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.done_all),
            tooltip: 'Mark all as read',
            onPressed: () => _markAllAsRead(context, currentUser.uid),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(currentUser.uid)
            .collection('notifications')
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.notifications_none,
                    size: 80,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No notifications yet',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            );
          }

          return Stack(
            children: [
              ListView.builder(
                padding: const EdgeInsets.only(left: 8, right: 8, top: 8, bottom: 80),
                itemCount: snapshot.data!.docs.length,
                itemBuilder: (context, index) {
                  final doc = snapshot.data!.docs[index];
                  final data = doc.data() as Map<String, dynamic>;
                  final notificationId = doc.id;

                  // Check if this is a received request or a response
                  if (data['requesterId'] != null) {
                    // This is a contact request received by poster
                    return _buildContactRequest(
                      context,
                      currentUser.uid,
                      notificationId,
                      data,
                    );
                  } else if (data['type'] == 'sent_request' && data['status'] == 'approved') {
                    // This is an approved response to requester
                    return _buildApprovedResponse(context, notificationId, data);
                  } else if (data['type'] == 'sent_request' && data['status'] == 'pending') {
                    // This is a pending request from requester's side
                    return _buildPendingRequest(context, data);
                  }

                  return const SizedBox.shrink();
                },
              ),
              // Floating Delete All Button
              Positioned(
                bottom: 16,
                left: 0,
                right: 0,
                child: Center(
                  child: FloatingActionButton.extended(
                    onPressed: () => _showDeleteAllConfirmation(context, currentUser.uid),
                    backgroundColor: Colors.red,
                    icon: const Icon(Icons.delete_sweep),
                    label: const Text('Delete All'),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildContactRequest(
    BuildContext context,
    String currentUserId,
    String notificationId,
    Map<String, dynamic> data,
  ) {
    final requesterName = data['requesterName'] ?? 'Someone';
    final status = data['status'] ?? 'pending';

    // If already processed, show as allowed
    if (status == 'allowed') {
      return Card(
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        color: Colors.green.shade50,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: Colors.green,
                child: const Icon(Icons.check, color: Colors.white),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$requesterName wants your contact information',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Request allowed',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.green.shade700,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (status != 'pending') {
      return const SizedBox.shrink();
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: InkWell(
        onTap: () => _showRequesterDetails(context, data, currentUserId, notificationId),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: Colors.blue.shade700,
                    child: const Icon(Icons.person, color: Colors.white),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '$requesterName wants your contact information',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Tap to view details',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right, color: Colors.grey.shade600),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _handleApprove(
                        context,
                        currentUserId,
                        notificationId,
                        data,
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                      icon: const Icon(Icons.check),
                      label: const Text('Allow'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _handleReject(
                        context,
                        currentUserId,
                        notificationId,
                        data,
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                      ),
                      icon: const Icon(Icons.close),
                      label: const Text('Reject'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildApprovedResponse(
    BuildContext context,
    String notificationId,
    Map<String, dynamic> data,
  ) {
    final posterName = data['posterName'] ?? 'Poster';
    final postId = data['postId'] ?? '';
    final postOwnerId = data['postOwnerId'] ?? '';
    
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      color: Colors.green.shade50,
      child: InkWell(
        onTap: () => _openPost(context, postId, postOwnerId),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: Colors.green,
                    child: const Icon(Icons.check, color: Colors.white),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '$posterName allowed your request',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                  ),
                  Icon(Icons.chevron_right, color: Colors.grey.shade600),
                ],
              ),
             
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPendingRequest(BuildContext context, Map<String, dynamic> data) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      color: Colors.orange.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: Colors.orange,
              child: const Icon(Icons.schedule, color: Colors.white),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Request pending',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'Waiting for poster response',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }


  Future<void> _handleApprove(
    BuildContext context,
    String currentUserId,
    String notificationId,
    Map<String, dynamic> data,
  ) async {
    try {
      // Get poster's contact info
      final posterDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUserId)
          .get();

      if (!posterDoc.exists) {
        throw Exception('Poster data not found');
      }

      final posterData = posterDoc.data()!;

        // Update requester's notification with poster contact info
        await FirebaseFirestore.instance
            .collection('users')
            .doc(data['requesterId'])
            .collection('notifications')
            .where('posterId', isEqualTo: currentUserId)
            .where('postId', isEqualTo: data['postId'])
            .where('status', isEqualTo: 'pending')
            .get()
            .then((snapshot) async {
          for (var doc in snapshot.docs) {
            await doc.reference.update({
              'status': 'approved',
              'posterEmail': posterData['email'] ?? 'N/A',
              'posterPhone': posterData['mobileNumber'] ?? 'N/A',
              'posterWhatsapp': posterData['whatsappNumber'] ?? 'N/A',
              'posterName': posterData['nidName'] ?? 'N/A',
              'postOwnerId': currentUserId,
              'isRead': false,
              'approvedAt': FieldValue.serverTimestamp(),
            });
          }
        });

      // Update the notification status in poster's collection instead of deleting
      await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUserId)
          .collection('notifications')
          .doc(notificationId)
          .update({
            'status': 'allowed',
            'allowedAt': FieldValue.serverTimestamp(),
          });

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Request approved! Contact info shared.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _handleReject(
    BuildContext context,
    String currentUserId,
    String notificationId,
    Map<String, dynamic> data,
  ) async {
    try {
      // Delete requester's notification
      await FirebaseFirestore.instance
          .collection('users')
          .doc(data['requesterId'])
          .collection('notifications')
          .where('posterId', isEqualTo: currentUserId)
          .where('postId', isEqualTo: data['postId'])
          .where('status', isEqualTo: 'pending')
          .get()
          .then((snapshot) async {
        for (var doc in snapshot.docs) {
          await doc.reference.delete();
        }
      });

      // Delete the notification from poster's collection
      await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUserId)
          .collection('notifications')
          .doc(notificationId)
          .delete();

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Request rejected'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _markAllAsRead(BuildContext context, String userId) async {
    try {
      final notifications = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('notifications')
          .get();

      for (var doc in notifications.docs) {
        await doc.reference.update({'isRead': true});
      }

      if (context.mounted) {
        // Navigate to profile page
        Navigator.pushNamedAndRemoveUntil(context, '/profile', (route) => false);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showRequesterDetails(
    BuildContext context,
    Map<String, dynamic> data,
    String currentUserId,
    String notificationId,
  ) async {
    // Fetch full user data
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(data['requesterId'])
          .get();

      if (!userDoc.exists || !context.mounted) return;

      final userData = userDoc.data()!;

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Row(
            children: [
              Icon(Icons.person, color: Colors.blue.shade700),
              const SizedBox(width: 8),
              const Expanded(child: Text('Requester Details')),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildDetailItem('Name', userData['nidName'] ?? 'N/A'),
                _buildDetailItem('Email', userData['email'] ?? 'N/A'),
                _buildDetailItem('Phone', userData['mobileNumber'] ?? 'N/A'),
                _buildDetailItem('WhatsApp', userData['whatsappNumber'] ?? 'N/A'),
                _buildDetailItem('Date of Birth', userData['dateOfBirth'] ?? 'N/A'),
                _buildDetailItem('Gender', userData['gender'] ?? 'N/A'),
                _buildDetailItem('Religion', userData['religion'] ?? 'N/A'),
                _buildDetailItem('Occupation', userData['occupation'] ?? 'N/A'),
                _buildDetailItem('Age Range', userData['ageRange'] ?? 'N/A'),
                _buildDetailItem('Blood Group', userData['bloodGroup'] ?? 'N/A'),
                _buildDetailItem('Smoker', userData['isSmoker'] == true ? 'Yes' : 'No'),
                _buildDetailItem('Pet Lover', userData['isPetLover'] == true ? 'Yes' : 'No'),
                _buildDetailItem('Sleeping Habit', userData['sleepingHabit'] ?? 'N/A'),
                _buildDetailItem('Cleanliness', userData['cleanliness'] ?? 'N/A'),
                _buildDetailItem('Roommate Type', userData['roommateType'] ?? 'N/A'),
                if (userData['bio'] != null && userData['bio'].toString().isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Bio:',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey.shade700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          userData['bio'],
                          style: const TextStyle(fontSize: 14),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading details: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildDetailItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade700,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openPost(BuildContext context, String postId, String postOwnerId) async {
    if (postId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Post not found'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      DocumentSnapshot? postDoc;
      
      // Try to fetch the post using postOwnerId if available
      if (postOwnerId.isNotEmpty) {
        postDoc = await FirebaseFirestore.instance
            .collection('posts')
            .doc(postOwnerId)
            .collection('post')
            .doc(postId)
            .get();
      }

      // If not found, search through all users
      if (postDoc == null || !postDoc.exists) {
        final usersSnapshot = await FirebaseFirestore.instance
            .collection('posts')
            .get();

        // Search through each user's posts
        for (var userDoc in usersSnapshot.docs) {
          final userPostDoc = await FirebaseFirestore.instance
              .collection('posts')
              .doc(userDoc.id)
              .collection('post')
              .doc(postId)
              .get();
          
          if (userPostDoc.exists) {
            postDoc = userPostDoc;
            break;
          }
        }
      }

      if (postDoc == null || !postDoc.exists || !context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Post no longer exists'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      final postData = postDoc.data() as Map<String, dynamic>;
      postData['postId'] = postId; // Add postId to the data

      // Navigate to RoomDetailsPage
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => RoomDetailsPage(postData: postData),
        ),
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error opening post: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _showDeleteAllConfirmation(BuildContext context, String userId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Text('Delete All Notifications?'),
          ],
        ),
        content: const Text(
          'Are you sure you want to delete all notifications? This action cannot be undone.',
          style: TextStyle(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete All'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      try {
        final notifications = await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .collection('notifications')
            .get();

        for (var doc in notifications.docs) {
          await doc.reference.delete();
        }

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('All notifications deleted'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error deleting notifications: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }
}
