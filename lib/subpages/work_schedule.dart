import 'package:flutter/material.dart';
import 'package:roommate/subpages/menubar.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

class WorkSchedulePage extends StatefulWidget {
  const WorkSchedulePage({super.key});

  @override
  State<WorkSchedulePage> createState() => _WorkSchedulePageState();
}

class _WorkSchedulePageState extends State<WorkSchedulePage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String? _selectedRoomId;
  Map<String, dynamic>? _selectedRoomData;
  String? _currentUserName;

  @override
  void initState() {
    super.initState();
    _loadCurrentUserName();
    _loadSelectedRoom();
  }

  Future<void> _loadSelectedRoom() async {
    final prefs = await SharedPreferences.getInstance();
    final savedRoomId = prefs.getString('work_schedule_selected_room');
    if (savedRoomId != null && mounted) {
      // Load the room data
      try {
        final roomDoc = await _firestore.collection('rooms').doc(savedRoomId).get();
        if (roomDoc.exists && mounted) {
          setState(() {
            _selectedRoomId = savedRoomId;
            _selectedRoomData = roomDoc.data();
          });
        }
      } catch (e) {
        // Room doesn't exist anymore, clear saved preference
        await prefs.remove('work_schedule_selected_room');
      }
    }
  }

  Future<void> _saveSelectedRoom(String? roomId) async {
    final prefs = await SharedPreferences.getInstance();
    if (roomId != null) {
      await prefs.setString('work_schedule_selected_room', roomId);
    } else {
      await prefs.remove('work_schedule_selected_room');
    }
  }

  void _loadCurrentUserName() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        final userDoc = await _firestore
            .collection('users')
            .doc(user.uid)
            .get();
        if (userDoc.exists && mounted) {
          final userData = userDoc.data();
          setState(() {
            _currentUserName = userData?['nidName'] ?? 'Unknown';
          });
        }
      } catch (e) {
        setState(() {
          _currentUserName = 'Unknown';
        });
      }
    }
  }

  Future<void> _deleteWork(String workId) async {
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete Work'),
          content: const Text(
            'Are you sure you want to delete this work? This action cannot be undone.',
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
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    try {
      await _firestore
          .collection('rooms')
          .doc(_selectedRoomId)
          .collection('work')
          .doc(workId)
          .delete();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 8),
                Text('Work deleted successfully'),
              ],
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting work: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _markAsDone(String workId, String currentAssignee) async {
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Confirm Completion'),
          content: const Text(
            'Are you sure you want to mark this work as done? It will be assigned to the next roommate.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
              child: const Text('Confirm'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    try {
      final users = _selectedRoomData?['users'] as List? ?? [];

      // Find current user index
      int currentIndex = users.indexWhere((u) => u['name'] == currentAssignee);

      // Get next user (circular rotation)
      int nextIndex = (currentIndex + 1) % users.length;
      String nextAssignee = users[nextIndex]['name'] ?? 'Unknown';

      // Update work document
      await _firestore
          .collection('rooms')
          .doc(_selectedRoomId)
          .collection('work')
          .doc(workId)
          .update({
            'assignedTo': nextAssignee,
            'isDone': false,
            'lastCompletedBy': currentAssignee,
            'lastCompletedAt': FieldValue.serverTimestamp(),
          });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 8),
                Text('Work marked as done! Assigned to $nextAssignee'),
              ],
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const MenuAppBar(title: 'Work Schedule'),
      drawer: const MenuDrawer(),
      body: Column(
        children: [
          // Room Selection Dropdown
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color.fromARGB(255, 0, 107, 194),
                  Colors.blue[700]!,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: _buildRoomSelector(),
            ),
          ),

          // Work Schedule List
          Expanded(
            child: _selectedRoomId == null
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.arrow_upward,
                          size: 60,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Select a room to view work schedule',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  )
                : _buildWorkSchedule(),
          ),
        ],
      ),
    );
  }

  Widget _buildRoomSelector() {
    final currentUserEmail = FirebaseAuth.instance.currentUser?.email ?? '';

    return StreamBuilder<QuerySnapshot>(
      stream: _firestore.collection('rooms').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Text(
            'Error loading rooms',
            style: TextStyle(color: Colors.white),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: Colors.white),
          );
        }

        final allRooms = snapshot.data?.docs ?? [];
        final rooms = allRooms.where((doc) {
          final roomData = doc.data() as Map<String, dynamic>;
          final users = roomData['users'] as List? ?? [];
          return users.any((user) => user['gmail'] == currentUserEmail);
        }).toList();

        if (rooms.isEmpty) {
          return const Text(
            'No rooms available',
            style: TextStyle(color: Colors.white),
          );
        }

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
          child: DropdownButton<String>(
            value: _selectedRoomId,
            hint: const Text('Select a room'),
            isExpanded: true,
            underline: const SizedBox(),
            items: rooms.map((room) {
              final roomData = room.data() as Map<String, dynamic>;
              return DropdownMenuItem(
                value: room.id,
                child: Text(roomData['roomName'] ?? 'Unnamed Room'),
              );
            }).toList(),
            onChanged: (value) {
              setState(() {
                _selectedRoomId = value;
                if (value != null) {
                  final selectedRoom = rooms.firstWhere((r) => r.id == value);
                  _selectedRoomData =
                      selectedRoom.data() as Map<String, dynamic>;
                }
              });
              _saveSelectedRoom(value);
            },
          ),
        );
      },
    );
  }

  Widget _buildWorkSchedule() {
    if (_selectedRoomId == null || _selectedRoomData == null) {
      return const SizedBox();
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Room Info Card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.blue[600]!, Colors.blue[800]!],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _selectedRoomData?['roomName'] ?? 'Unnamed Room',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(
                      Icons.location_on,
                      color: Colors.white70,
                      size: 16,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _selectedRoomData?['location'] ?? 'No location',
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Work List
          const Text(
            'Work Schedule',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),

          StreamBuilder<QuerySnapshot>(
            stream: _firestore
                .collection('rooms')
                .doc(_selectedRoomId)
                .collection('work')
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}'));
              }

              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final workDocs = snapshot.data?.docs ?? [];

              if (workDocs.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      children: [
                        Icon(
                          Icons.work_off_outlined,
                          size: 64,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No work assigned yet',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }

              return Column(
                children: workDocs.map((doc) {
                  final workData = doc.data() as Map<String, dynamic>;
                  final workName = workData['workName'] ?? 'Unnamed Work';
                  final assignedTo = workData['assignedTo'] ?? 'Unknown';
                  final createdBy = workData['createdBy'] ?? '';
                  final workId = doc.id;

                  return _buildWorkCard(
                    workId,
                    workName,
                    assignedTo,
                    createdBy,
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildWorkCard(
    String workId,
    String workName,
    String assignedTo,
    String createdBy,
  ) {
    final canMarkDone = _currentUserName == assignedTo;
    final currentUserEmail = FirebaseAuth.instance.currentUser?.email ?? '';
    final isCreator = currentUserEmail == createdBy;

    return GestureDetector(
      onLongPress: isCreator
          ? () {
              // Show bottom sheet with delete option
              showModalBottomSheet(
                context: context,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(20),
                  ),
                ),
                builder: (context) {
                  return SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 40,
                            height: 4,
                            margin: const EdgeInsets.only(bottom: 20),
                            decoration: BoxDecoration(
                              color: Colors.grey[300],
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          ListTile(
                            leading: const Icon(
                              Icons.delete_outline,
                              color: Colors.red,
                              size: 28,
                            ),
                            title: const Text(
                              'Delete Work',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: Text(
                              'Remove "$workName" from schedule',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[600],
                              ),
                            ),
                            onTap: () {
                              Navigator.pop(context);
                              _deleteWork(workId);
                            },
                          ),
                          const SizedBox(height: 8),
                        ],
                      ),
                    ),
                  );
                },
              );
            }
          : null,
      child: Card(
        margin: const EdgeInsets.only(bottom: 12),
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Work Icon
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(
                    context,
                  ).colorScheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.work_outline,
                  color: Theme.of(context).colorScheme.primary,
                  size: 24,
                ),
              ),

              const SizedBox(width: 16),

              // Work Details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      workName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.person_outline,
                          size: 16,
                          color: Colors.grey[600],
                        ),
                        const SizedBox(width: 4),
                        Text(
                          assignedTo,
                          style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Mark Done Button
              if (canMarkDone)
                ElevatedButton.icon(
                  onPressed: () => _markAsDone(workId, assignedTo),
                  icon: const Icon(Icons.check, size: 18),
                  label: const Text('Done'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Pending',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[700],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
