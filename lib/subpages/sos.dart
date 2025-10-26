import 'package:flutter/material.dart';
import 'package:roommate/subpages/menubar.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';

class SOSPage extends StatefulWidget {
  const SOSPage({super.key});

  @override
  State<SOSPage> createState() => _SOSPageState();
}

class _SOSPageState extends State<SOSPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String? _selectedRoomId;
  Map<String, dynamic>? _selectedRoomData;
  bool _isLoading = false;
  int _currentCallIndex = 0;
  List<Map<String, dynamic>> _callableMembers = [];

  Future<void> _makeCall(String phoneNumber, String name) async {
    try {
      final Uri phoneUri = Uri.parse('tel:$phoneNumber');
      
      final bool launched = await launchUrl(
        phoneUri,
        mode: LaunchMode.externalApplication,
      );
      
      if (!launched) {
        throw Exception('Failed to make call');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not call $name: ${e.toString()}'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> _getCallableMembersFromFirestore() async {
    if (_selectedRoomData == null) return [];
    
    final currentUserEmail = FirebaseAuth.instance.currentUser?.email ?? '';
    final users = _selectedRoomData?['users'] as List? ?? [];
    
    List<Map<String, dynamic>> callableMembers = [];
    
    for (var user in users) {
      final email = user['gmail'] ?? '';
      if (email == currentUserEmail) continue;
      
      // Fetch user data from Firestore to get mobileNumber
      try {
        final userQuery = await _firestore
            .collection('users')
            .where('email', isEqualTo: email)
            .limit(1)
            .get();
        
        if (userQuery.docs.isNotEmpty) {
          final userData = userQuery.docs.first.data();
          final mobileNumber = userData['mobileNumber']?.toString() ?? '';
          
          if (mobileNumber.isNotEmpty) {
            callableMembers.add({
              'name': user['name'] ?? 'Unknown',
              'phone': mobileNumber,
              'gmail': email,
              'uid': userQuery.docs.first.id,
            });
          }
        }
      } catch (e) {
        // Handle errors if needed
      }
    }
    
    return callableMembers;
  }

  Future<void> _callNext() async {
    if (_selectedRoomData == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a room first'),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      _callableMembers = await _getCallableMembersFromFirestore();

      if (_callableMembers.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No members with phone numbers found'),
              backgroundColor: Colors.orange,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        return;
      }

      if (_currentCallIndex >= _callableMembers.length) {
        _currentCallIndex = 0;
      }

      final member = _callableMembers[_currentCallIndex];

      await _makeCall(member['phone'], member['name']);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.phone, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('Calling ${member['name']}...'),
                ),
              ],
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );

        setState(() {
          _currentCallIndex++;
        });
      }
    } catch (e) {
      // Error already handled in _makeCall
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _callRandom() async {
    if (_selectedRoomData == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a room first'),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final callableMembers = await _getCallableMembersFromFirestore();

      if (callableMembers.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No members with phone numbers found'),
              backgroundColor: Colors.orange,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        return;
      }

      final randomMember = (callableMembers..shuffle()).first;
      final name = randomMember['name'] ?? 'Unknown';
      final phone = randomMember['phone'].toString();

      await _makeCall(phone, name);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.phone, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('Calling $name...'),
                ),
              ],
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      // Error already handled in _makeCall
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const MenuAppBar(title: 'Emergency SOS', backgroundColor: Color.fromARGB(255, 206, 53, 42)),
      drawer: const MenuDrawer(),
      body: Column(
        children: [
          // Room Selection Header
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.red[700]!,
                  Colors.red[500]!,
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

          // SOS Content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Warning Card
                  Card(
                    color: Colors.red[50],
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: Colors.red[200]!, width: 2),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Icon(Icons.warning_amber_rounded, 
                            color: Colors.red[700], 
                            size: 40,
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Emergency SOS',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.red[900],
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Use this feature only in case of emergency',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.red[700],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Available Members
                  if (_selectedRoomData != null) ...[
                    const Text(
                      'Available Members',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildMembersList(),
                    const SizedBox(height: 32),
                  ],

                  // Call Next Button
                  SizedBox(
                    width: double.infinity,
                    height: 100,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _callNext,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red[600],
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 4,
                      ),
                      child: _isLoading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.phone, size: 40),
                                const SizedBox(height: 8),
                                Text(
                                  _currentCallIndex == 0 
                                    ? 'Call First Member'
                                    : 'Call Next Member',
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Call Random Button
                  SizedBox(
                    width: double.infinity,
                    height: 80,
                    child: OutlinedButton(
                      onPressed: _isLoading ? null : _callRandom,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red[700],
                        side: BorderSide(color: Colors.red[700]!, width: 2),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.shuffle, size: 30, color: Colors.red[700]),
                          const SizedBox(height: 8),
                          Text(
                            'Call Random Member',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.red[700],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Reset Button
                  if (_currentCallIndex > 0)
                    Center(
                      child: TextButton.icon(
                        onPressed: () {
                          setState(() {
                            _currentCallIndex = 0;
                          });
                        },
                        icon: const Icon(Icons.refresh),
                        label: const Text('Reset Call Queue'),
                      ),
                    ),
                ],
              ),
            ),
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
                _currentCallIndex = 0;
                if (value != null) {
                  final selectedRoom = rooms.firstWhere((r) => r.id == value);
                  _selectedRoomData = selectedRoom.data() as Map<String, dynamic>;
                }
              });
            },
          ),
        );
      },
    );
  }

  Widget _buildMembersList() {
    final currentUserEmail = FirebaseAuth.instance.currentUser?.email ?? '';
    final users = _selectedRoomData?['users'] as List? ?? [];
    final otherUsers = users
        .where((u) => u['gmail'] != currentUserEmail)
        .toList();

    if (otherUsers.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Center(
          child: Text(
            'No other members in this room',
            style: TextStyle(color: Colors.grey),
          ),
        ),
      );
    }

    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _getCallableMembersFromFirestore(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: CircularProgressIndicator(),
            ),
          );
        }

        final membersWithPhone = snapshot.data ?? [];
        
        return Card(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Column(
            children: otherUsers.asMap().entries.map((entry) {
              final index = entry.key;
              final user = entry.value;
              final name = user['name'] ?? 'Unknown';
              final email = user['gmail'] ?? '';
              
              // Find phone number from Firestore data
              final memberData = membersWithPhone.firstWhere(
                (m) => m['gmail'] == email,
                orElse: () => {},
              );
              final phone = memberData['phone']?.toString() ?? 'No phone';
              final hasPhone = memberData.isNotEmpty && 
                               memberData['phone']?.toString().isNotEmpty == true;

              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: hasPhone 
                    ? (index == _currentCallIndex ? Colors.green : Colors.blue)
                    : Colors.grey,
                  child: hasPhone
                    ? (index == _currentCallIndex 
                        ? const Icon(Icons.phone_in_talk, color: Colors.white, size: 20)
                        : Text('${index + 1}', style: const TextStyle(color: Colors.white)))
                    : const Icon(Icons.phone_disabled, color: Colors.white, size: 20),
                ),
                title: Text(
                  name,
                  style: TextStyle(
                    fontWeight: index == _currentCallIndex 
                      ? FontWeight.bold 
                      : FontWeight.normal,
                  ),
                ),
                subtitle: Text(
                  phone,
                  style: TextStyle(
                    fontSize: 12,
                    color: hasPhone ? Colors.grey[600] : Colors.red[300],
                  ),
                ),
                trailing: hasPhone
                  ? IconButton(
                      icon: const Icon(Icons.phone, color: Colors.green),
                      onPressed: _isLoading 
                        ? null 
                        : () => _makeCall(phone, name),
                    )
                  : null,
              );
            }).toList(),
          ),
        );
      },
    );
  }
}
