import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:roommate/subpages/editroom.dart';

class RoomListPage extends StatefulWidget {
  const RoomListPage({super.key});

  @override
  State<RoomListPage> createState() => _RoomListPageState();
}

class _RoomListPageState extends State<RoomListPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'My Rooms',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: const Color.fromARGB(255, 0, 107, 194),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore.collection('rooms').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 60, color: Colors.red),
                  const SizedBox(height: 16),
                  Text(
                    'Error: ${snapshot.error}',
                    style: const TextStyle(color: Colors.red),
                  ),
                ],
              ),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          // Filter rooms where current user is a member
          final currentUserEmail =
              FirebaseAuth.instance.currentUser?.email ?? '';
          final allRooms = snapshot.data?.docs ?? [];
          final rooms = allRooms.where((doc) {
            final roomData = doc.data() as Map<String, dynamic>;
            final users = roomData['users'] as List? ?? [];
            return users.any((user) => user['gmail'] == currentUserEmail);
          }).toList();

          if (rooms.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.meeting_room_outlined,
                    size: 80,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No rooms found',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Create a room to get started',
                    style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: rooms.length,
            itemBuilder: (context, index) {
              final roomDoc = rooms[index];
              final roomData = roomDoc.data() as Map<String, dynamic>;
              return _buildRoomCard(roomData, roomDoc.id);
            },
          );
        },
      ),
    );
  }

  Widget _buildRoomCard(Map<String, dynamic> roomData, String roomId) {
    final String roomName = roomData['roomName'] ?? 'Unnamed Room';
    final String location = roomData['location'] ?? 'No location';
    final Map<String, dynamic> bills = roomData['bills'] ?? {};
    final double totalBill = (bills['totalBill'] ?? 0).toDouble();
    final List users = roomData['users'] ?? [];
    final int userCount = users.length;
    final double splitAmount = userCount > 0 ? totalBill / userCount : 0;

    // Check if current user is the creator
    final currentUserEmail = FirebaseAuth.instance.currentUser?.email ?? '';
    final String creatorEmail = roomData['creatorEmail'] ?? '';
    final bool isCreator = currentUserEmail == creatorEmail;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Room Name and Location with Edit Button
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.meeting_room,
                    color: Theme.of(context).colorScheme.primary,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        roomName,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.location_on,
                            size: 16,
                            color: Colors.grey[600],
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              location,
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[600],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isCreator)
                      IconButton(
                        onPressed: () =>
                            _showEditOptions(context, roomId, roomData),
                        icon: const Icon(Icons.edit),
                        color: Theme.of(context).colorScheme.primary,
                        tooltip: 'Edit Room',
                      ),
                    if (!isCreator)
                      IconButton(
                        onPressed: () =>
                            _confirmLeaveRoom(context, roomId, roomName),
                        icon: const Icon(Icons.exit_to_app),
                        color: Colors.red,
                        tooltip: 'Leave Room',
                      ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 16),

            // Total Bill and Split
            Row(
              children: [
                Expanded(
                  child: _buildInfoBox(
                    'Total Bill',
                    '৳${totalBill.toStringAsFixed(2)}',
                    Icons.receipt_long,
                    Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildInfoBox(
                    'Your Split',
                    '৳${splitAmount.toStringAsFixed(2)}',
                    Icons.person,
                    Colors.green,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Bill Details
            _buildSectionHeader('Bill Details', Icons.receipt),
            const SizedBox(height: 12),
            _buildBillDetails(bills),
            const SizedBox(height: 16),

            // Room Members
            _buildSectionHeader('Room Members', Icons.group),
            const SizedBox(height: 12),
            _buildMembersList(users),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoBox(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[700],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _buildBillDetails(Map<String, dynamic> bills) {
    final double totalRent = (bills['totalRent'] ?? 0).toDouble();
    final List foodBills = bills['food'] ?? [];
    final List utilityBills = bills['utilities'] ?? [];
    final List otherBills = bills['other'] ?? [];

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        children: [
          if (totalRent > 0) _buildBillRow('Total Rent', totalRent, Icons.home),
          if (foodBills.isNotEmpty) ...[
            const SizedBox(height: 8),
            _buildBillCategory('Food', foodBills, Icons.restaurant),
          ],
          if (utilityBills.isNotEmpty) ...[
            const SizedBox(height: 8),
            _buildBillCategory(
              'Utilities',
              utilityBills,
              Icons.electrical_services,
            ),
          ],
          if (otherBills.isNotEmpty) ...[
            const SizedBox(height: 8),
            _buildBillCategory('Other Bills', otherBills, Icons.more_horiz),
          ],
        ],
      ),
    );
  }

  Widget _buildBillRow(String label, double amount, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.grey[700]),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: TextStyle(fontSize: 14, color: Colors.grey[800]),
            ),
          ),
          Text(
            '৳${amount.toStringAsFixed(2)}',
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _buildBillCategory(
    String category,
    List bills,
    IconData categoryIcon,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(categoryIcon, size: 16, color: Colors.grey[700]),
            const SizedBox(width: 8),
            Text(
              category,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.grey[800],
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ...bills.map((bill) {
          final String name = bill['name'] ?? 'Unnamed';
          final double amount = (bill['amount'] ?? 0).toDouble();
          return Padding(
            padding: const EdgeInsets.only(left: 24, top: 4),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    name.isEmpty ? 'Unnamed' : name,
                    style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                  ),
                ),
                Text(
                  '৳${amount.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey[700],
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ],
    );
  }

  Widget _buildMembersList(List users) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        children: users.map((user) {
          final String name = user['name'] ?? 'Unknown';
          final String email = user['gmail'] ?? '';
          final String role = user['role'] ?? 'member';
          final bool isCreator = role == 'creator';

          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: isCreator
                      ? Theme.of(context).colorScheme.primary
                      : Colors.grey[400],
                  child: Text(
                    name.isNotEmpty ? name[0].toUpperCase() : '?',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              name,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          if (isCreator) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Theme.of(
                                  context,
                                ).colorScheme.primary.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'Creator',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        email,
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  void _showEditOptions(
    BuildContext context,
    String roomId,
    Map<String, dynamic> roomData,
  ) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              ListTile(
                leading: const Icon(Icons.edit, color: Colors.blue),
                title: const Text('Edit Room'),
                onTap: () {
                  Navigator.pop(context);
                  _editRoom(context, roomId, roomData);
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text(
                  'Delete Room',
                  style: TextStyle(color: Colors.red),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _confirmDelete(
                    context,
                    roomId,
                    roomData['roomName'] ?? 'this room',
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _editRoom(
    BuildContext context,
    String roomId,
    Map<String, dynamic> roomData,
  ) {
    // Navigate to edit page (we'll create this next)
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditRoomPage(roomId: roomId, roomData: roomData),
      ),
    );
  }

  void _confirmLeaveRoom(BuildContext context, String roomId, String roomName) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Leave Room'),
          content: Text(
            'Are you sure you want to leave "$roomName"? You will no longer have access to this room.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _leaveRoom(context, roomId);
              },
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Leave'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _leaveRoom(BuildContext context, String roomId) async {
    try {
      final currentUserEmail = FirebaseAuth.instance.currentUser?.email ?? '';
      final roomDoc = await _firestore.collection('rooms').doc(roomId).get();

      if (roomDoc.exists) {
        final roomData = roomDoc.data() as Map<String, dynamic>;
        final users = List<Map<String, dynamic>>.from(roomData['users'] ?? []);

        // Remove current user from the users list
        users.removeWhere((user) => user['gmail'] == currentUserEmail);

        // Update the room with the new users list
        await _firestore.collection('rooms').doc(roomId).update({
          'users': users,
        });

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.white),
                  SizedBox(width: 8),
                  Text('You have left the room'),
                ],
              ),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error, color: Colors.white),
                const SizedBox(width: 8),
                Text('Error: $e'),
              ],
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _confirmDelete(BuildContext context, String roomId, String roomName) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete Room'),
          content: Text(
            'Are you sure you want to delete "$roomName"? This action cannot be undone.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _deleteRoom(context, roomId);
              },
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _deleteRoom(BuildContext context, String roomId) async {
    try {
      await _firestore.collection('rooms').doc(roomId).delete();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 8),
                Text('Room deleted successfully'),
              ],
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(child: Text('Error deleting room: $e')),
              ],
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }
}
