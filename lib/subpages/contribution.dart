import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ContributionPage extends StatefulWidget {
  const ContributionPage({super.key});

  @override
  State<ContributionPage> createState() => _ContributionPageState();
}

class _ContributionPageState extends State<ContributionPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String? _selectedRoomId;
  Map<String, dynamic>? _selectedRoomData;
  String? _userName;
  String? _userEmail;

  final List<Map<String, TextEditingController>> _billFields = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _addBillField();
    _loadUserInfo();
  }

  void _loadUserInfo() async {
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
            _userName = userData?['nidName'] ?? 'Unknown';
            _userEmail = user.email ?? '';
          });
        }
      } catch (e) {
        setState(() {
          _userName = 'Unknown';
          _userEmail = user.email ?? '';
        });
      }
    }
  }

  void _addBillField() {
    setState(() {
      _billFields.add({
        'description': TextEditingController(),
        'amount': TextEditingController(),
      });
    });
  }

  void _removeBillField(int index) {
    setState(() {
      _billFields[index]['description']?.dispose();
      _billFields[index]['amount']?.dispose();
      _billFields.removeAt(index);
    });
  }

  Future<void> _submitContribution() async {
    // Validate fields
    bool hasValidBill = false;
    for (var field in _billFields) {
      final desc = field['description']?.text.trim() ?? '';
      final amount = field['amount']?.text.trim() ?? '';
      if (desc.isNotEmpty && amount.isNotEmpty) {
        if (double.tryParse(amount) != null && double.parse(amount) > 0) {
          hasValidBill = true;
          break;
        }
      }
    }

    if (!hasValidBill) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please add at least one valid contribution'),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
        ),
      );
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

    setState(() {
      _isLoading = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('User not authenticated');

      // Get user details from room data
      final users = _selectedRoomData?['users'] as List? ?? [];
      final currentUserData = users.firstWhere(
        (u) => u['gmail'] == user.email,
        orElse: () => {'name': 'Unknown', 'gmail': user.email},
      );

      // Prepare contributions list
      final List<Map<String, dynamic>> contributions = [];
      double totalAmount = 0;

      for (var field in _billFields) {
        final desc = field['description']?.text.trim() ?? '';
        final amountStr = field['amount']?.text.trim() ?? '';
        final amount = double.tryParse(amountStr);

        if (desc.isNotEmpty && amount != null && amount > 0) {
          contributions.add({'description': desc, 'amount': amount});
          totalAmount += amount;
        }
      }

      // Create contribution document inside the room as a subcollection
      final contributionData = {
        'userName': currentUserData['name'] ?? 'Unknown',
        'userEmail': user.email ?? '',
        'contributions': contributions,
        'totalAmount': totalAmount,
        'createdAt': FieldValue.serverTimestamp(),
      };

      // Save contribution inside the room's contributions subcollection
      await _firestore
          .collection('rooms')
          .doc(_selectedRoomId)
          .collection('contributions')
          .add(contributionData);

      if (mounted) {
        // Clear fields
        for (var field in _billFields) {
          field['description']?.clear();
          field['amount']?.clear();
        }

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 8),
                Text('Contribution added successfully!'),
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
    for (var field in _billFields) {
      field['description']?.dispose();
      field['amount']?.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'My Contributions',
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
            return Center(child: Text('Error: ${snapshot.error}'));
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
                    style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                  ),
                ],
              ),
            );
          }

          // Set initial selection if not set
          if (_selectedRoomId == null && rooms.isNotEmpty) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                setState(() {
                  _selectedRoomId = rooms[0].id;
                  _selectedRoomData = rooms[0].data() as Map<String, dynamic>;
                });
              }
            });
          }

          return SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // User Details Card
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Theme.of(
                          context,
                        ).colorScheme.primary.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 28,
                          backgroundColor: Theme.of(
                            context,
                          ).colorScheme.primary,
                          child: Text(
                            _userName?.isNotEmpty == true
                                ? _userName![0].toUpperCase()
                                : '?',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _userName ?? 'Loading...',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onPrimaryContainer,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _userEmail ?? '',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onPrimaryContainer
                                      .withValues(alpha: 0.7),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Room Dropdown
                  _buildSectionHeader('Select Room', Icons.meeting_room),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        isExpanded: true,
                        value: _selectedRoomId,
                        hint: const Text('Select a room'),
                        icon: const Icon(Icons.arrow_drop_down),
                        items: rooms.map((roomDoc) {
                          final roomData =
                              roomDoc.data() as Map<String, dynamic>;
                          final roomName =
                              roomData['roomName'] ?? 'Unnamed Room';
                          final location = roomData['location'] ?? '';
                          return DropdownMenuItem<String>(
                            value: roomDoc.id,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  roomName,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 16,
                                  ),
                                ),
                                if (location.isNotEmpty)
                                  Text(
                                    location,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                              ],
                            ),
                          );
                        }).toList(),
                        onChanged: (String? newValue) {
                          setState(() {
                            _selectedRoomId = newValue;
                            final selectedRoom = rooms.firstWhere(
                              (room) => room.id == newValue,
                            );
                            _selectedRoomData =
                                selectedRoom.data() as Map<String, dynamic>;
                          });
                        },
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Room Details Card (Total Bill & Your Dues)
                  if (_selectedRoomData != null) ...[
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Theme.of(context).colorScheme.primary,
                            Theme.of(
                              context,
                            ).colorScheme.primary.withValues(alpha: 0.7),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildDuesItem(
                            'Total Bill',
                            (_selectedRoomData?['bills']?['totalBill'] ?? 0)
                                .toDouble(),
                          ),
                          Container(
                            width: 1,
                            height: 40,
                            color: Colors.white30,
                          ),
                          _buildDuesItem(
                            'Your Dues',
                            ((_selectedRoomData?['bills']?['totalBill'] ?? 0)
                                    .toDouble() /
                                ((_selectedRoomData?['users'] as List?)
                                        ?.length ??
                                    1)),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],

                  // Add Contribution Section
                  _buildSectionHeader(
                    'Add Contribution',
                    Icons.add_circle_outline,
                  ),
                  const SizedBox(height: 16),

                  // Bill Fields
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _billFields.length,
                    itemBuilder: (context, index) {
                      return _buildBillField(index);
                    },
                  ),

                  const SizedBox(height: 12),

                  // Add More Button
                  TextButton.icon(
                    onPressed: _addBillField,
                    icon: const Icon(Icons.add),
                    label: const Text('Add More'),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Submit Button
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _isLoading ? null : _submitContribution,
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                              ),
                            )
                          : const Text(
                              'Submit Contribution',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Contribution History
                  _buildSectionHeader('Contribution History', Icons.history),
                  const SizedBox(height: 16),

                  if (_selectedRoomId != null)
                    _buildContributionHistory(_selectedRoomId!),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildDuesItem(String label, double amount) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Colors.white70),
        ),
        const SizedBox(height: 4),
        Text(
          '৳${amount.toStringAsFixed(2)}',
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _buildBillField(int index) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Item ${index + 1}',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
              if (_billFields.length > 1)
                IconButton(
                  onPressed: () => _removeBillField(index),
                  icon: const Icon(Icons.remove_circle, color: Colors.red),
                  tooltip: 'Remove',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
            ],
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _billFields[index]['description'],
            decoration: InputDecoration(
              labelText: 'Description',
              hintText: 'e.g., Electricity bill',
              prefixIcon: const Icon(Icons.description),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 8,
              ),
            ),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _billFields[index]['amount'],
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: 'Amount',
              hintText: '0.00',
              prefixIcon: const Icon(Icons.money),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 8,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContributionHistory(String roomId) {
    final currentUserEmail = FirebaseAuth.instance.currentUser?.email ?? '';

    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('rooms')
          .doc(roomId)
          .collection('contributions')
          .where('userEmail', isEqualTo: currentUserEmail)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.red[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.red[300]!),
            ),
            child: Center(
              child: Column(
                children: [
                  Icon(Icons.error_outline, size: 48, color: Colors.red[400]),
                  const SizedBox(height: 8),
                  Text(
                    'Error loading contributions',
                    style: TextStyle(color: Colors.red[600]),
                  ),
                ],
              ),
            ),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final contributions = snapshot.data?.docs ?? [];

        // Sort contributions by createdAt (newest first)
        final sortedContributions = contributions.toList()
          ..sort((a, b) {
            final aTime =
                (a.data() as Map<String, dynamic>)['createdAt'] as Timestamp?;
            final bTime =
                (b.data() as Map<String, dynamic>)['createdAt'] as Timestamp?;
            if (aTime == null && bTime == null) return 0;
            if (aTime == null) return 1;
            if (bTime == null) return -1;
            return bTime.compareTo(aTime); // Descending order
          });

        if (sortedContributions.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: Center(
              child: Column(
                children: [
                  Icon(Icons.history, size: 48, color: Colors.grey[400]),
                  const SizedBox(height: 8),
                  Text(
                    'No contribution added',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
          );
        }

        // Calculate total contributed and remaining
        double totalContributed = 0;
        for (var doc in sortedContributions) {
          final data = doc.data() as Map<String, dynamic>;
          totalContributed += (data['totalAmount'] ?? 0).toDouble();
        }

        final splitAmount =
            (_selectedRoomData?['bills']?['totalBill'] ?? 0).toDouble() /
            ((_selectedRoomData?['users'] as List?)?.length ?? 1);
        final remaining = splitAmount - totalContributed;

        return Column(
          children: [
            // Summary Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: remaining > 0
                      ? [Colors.orange[400]!, Colors.orange[600]!]
                      : [Colors.green[400]!, Colors.green[600]!],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildSummaryItem('Contributed', totalContributed),
                  Container(width: 1, height: 40, color: Colors.white30),
                  _buildSummaryItem('Remaining', remaining.abs()),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Contribution List
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: sortedContributions.length,
              itemBuilder: (context, index) {
                final contributionDoc = sortedContributions[index];
                final contributionData =
                    contributionDoc.data() as Map<String, dynamic>;
                return _buildContributionItem(contributionData);
              },
            ),
          ],
        );
      },
    );
  }

  Widget _buildSummaryItem(String label, double amount) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Colors.white70),
        ),
        const SizedBox(height: 4),
        Text(
          '৳${amount.toStringAsFixed(2)}',
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ],
    );
  }

  Widget _buildContributionItem(Map<String, dynamic> data) {
    final contributions = data['contributions'] as List? ?? [];
    final totalAmount = (data['totalAmount'] ?? 0).toDouble();
    final timestamp = data['createdAt'] as Timestamp?;
    final date = timestamp?.toDate();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                date != null
                    ? '${date.day}/${date.month}/${date.year}'
                    : 'Unknown date',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '৳${totalAmount.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.green[700],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 12),
          ...contributions.map((item) {
            final desc = item['description'] ?? 'Unknown';
            final amount = (item['amount'] ?? 0).toDouble();
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Icon(Icons.check_circle, size: 16, color: Colors.green[600]),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(desc, style: const TextStyle(fontSize: 14)),
                  ),
                  Text(
                    '৳${amount.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[700],
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }
}
