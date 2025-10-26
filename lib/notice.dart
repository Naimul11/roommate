import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class NoticePage extends StatefulWidget {
  const NoticePage({super.key});

  @override
  State<NoticePage> createState() => _NoticePageState();
}

class _NoticePageState extends State<NoticePage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final _formKey = GlobalKey<FormState>();

  String? _selectedRoomId;
  Map<String, dynamic>? _selectedRoomData;
  final TextEditingController _messageController = TextEditingController();
  DateTime? _selectedTime;
  bool _sendToAll = true;
  final Set<String> _selectedMembers = {};
  bool _isLoading = false;

  Future<void> _selectTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );

    if (picked != null) {
      setState(() {
        final now = DateTime.now();
        _selectedTime = DateTime(
          now.year,
          now.month,
          now.day,
          picked.hour,
          picked.minute,
        );
      });
    }
  }

  Future<void> _sendNotice() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedRoomId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a room'),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (!_sendToAll && _selectedMembers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least one member'),
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
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('User not authenticated');

      final users = _selectedRoomData?['users'] as List? ?? [];

      // Determine recipients
      List<String> recipients = [];
      if (_sendToAll) {
        recipients = users
            .map((u) => u['gmail'] as String?)
            .where((email) => email != null && email != user.email)
            .cast<String>()
            .toList();
      } else {
        recipients = _selectedMembers.toList();
      }

      // Notification creation removed

      if (mounted) {
        _messageController.clear();
        setState(() {
          _selectedTime = null;
          _selectedMembers.clear();
          _sendToAll = true;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 8),
                Text('Notice sent to ${recipients.length} member(s)'),
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
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Send Notice',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: const Color.fromARGB(255, 0, 107, 194),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
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

          // Notice Form
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Message Field
                    const Text(
                      'Notice Message',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _messageController,
                      maxLines: 5,
                      decoration: InputDecoration(
                        hintText: 'Enter your notice message...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: Theme.of(context).colorScheme.primary,
                            width: 2,
                          ),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter a message';
                        }
                        return null;
                      },
                    ),

                    const SizedBox(height: 24),

                    // Time Selection (Optional)
                    const Text(
                      'Time (Optional)',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    InkWell(
                      onTap: _selectTime,
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey[300]!),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.access_time,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            const SizedBox(width: 12),
                            Text(
                              _selectedTime == null
                                  ? 'Select time'
                                  : '${_selectedTime!.hour.toString().padLeft(2, '0')}:${_selectedTime!.minute.toString().padLeft(2, '0')}',
                              style: TextStyle(
                                fontSize: 16,
                                color: _selectedTime == null
                                    ? Colors.grey[600]
                                    : Colors.black,
                              ),
                            ),
                            const Spacer(),
                            if (_selectedTime != null)
                              IconButton(
                                onPressed: () {
                                  setState(() {
                                    _selectedTime = null;
                                  });
                                },
                                icon: const Icon(Icons.clear, size: 20),
                                tooltip: 'Clear time',
                              ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Recipient Selection
                    const Text(
                      'Send To',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Send to all toggle
                    Card(
                      elevation: 1,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: SwitchListTile(
                        title: const Text('Send to all members'),
                        subtitle: const Text(
                          'Send notice to everyone in the room',
                        ),
                        value: _sendToAll,
                        onChanged: (value) {
                          setState(() {
                            _sendToAll = value;
                            if (value) {
                              _selectedMembers.clear();
                            }
                          });
                        },
                        activeThumbColor: Theme.of(context).colorScheme.primary,
                      ),
                    ),

                    // Member selection (if not sending to all)
                    if (!_sendToAll && _selectedRoomData != null) ...[
                      const SizedBox(height: 16),
                      const Text(
                        'Select Members',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _buildMemberSelection(),
                    ],

                    const SizedBox(height: 32),

                    // Send Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _isLoading ? null : _sendNotice,
                        icon: _isLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.send),
                        label: Text(
                          _isLoading ? 'Sending...' : 'Send Notice',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(
                            context,
                          ).colorScheme.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
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
                _selectedMembers.clear();
                if (value != null) {
                  final selectedRoom = rooms.firstWhere((r) => r.id == value);
                  _selectedRoomData =
                      selectedRoom.data() as Map<String, dynamic>;
                }
              });
            },
          ),
        );
      },
    );
  }

  Widget _buildMemberSelection() {
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

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        children: otherUsers.map((user) {
          final name = user['name'] ?? 'Unknown';
          final email = user['gmail'] ?? '';

          return CheckboxListTile(
            title: Text(name),
            subtitle: Text(
              email,
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
            value: _selectedMembers.contains(email),
            onChanged: (value) {
              setState(() {
                if (value == true) {
                  _selectedMembers.add(email);
                } else {
                  _selectedMembers.remove(email);
                }
              });
            },
            activeColor: Theme.of(context).colorScheme.primary,
          );
        }).toList(),
      ),
    );
  }
}
