import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import '../models/auction_item.dart';
import '../services/auction_service.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final AuctionService _auctionService = AuctionService();
  final ImagePicker _picker = ImagePicker();

  void _showEditProfileDialog(String currentUsername, String currentPhotoUrl) {
    final usernameController = TextEditingController(text: currentUsername);
    File? newProfileImage;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Edit Profile'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                GestureDetector(
                  onTap: () async {
                    final XFile? picked = await _picker.pickImage(
                      source: ImageSource.gallery,
                      maxWidth: 400,
                      maxHeight: 400,
                      imageQuality: 70,
                    );
                    if (picked != null) {
                      setDialogState(() {
                        newProfileImage = File(picked.path);
                      });
                    }
                  },
                  child: CircleAvatar(
                    radius: 40,
                    backgroundColor: Colors.deepPurple[100],
                    child: newProfileImage != null
                        ? ClipOval(
                      child: Image.file(newProfileImage!,
                          width: 80, height: 80, fit: BoxFit.cover),
                    )
                        : _buildProfileImageWidget(currentPhotoUrl, radius: 40),
                  ),
                ),
                const SizedBox(height: 8),
                const Text('Tap avatar to change photo',
                    style: TextStyle(fontSize: 12, color: Colors.grey)),
                const SizedBox(height: 16),
                TextField(
                  controller: usernameController,
                  decoration: const InputDecoration(
                    labelText: 'User ID / Username',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final User? user = FirebaseAuth.instance.currentUser;
                if (user != null) {
                  await _auctionService.updateUserProfile(
                    userId: user.uid,
                    username: usernameController.text.trim(),
                    imageFile: newProfileImage,
                  );
                }
                if (mounted) Navigator.pop(dialogContext);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  void _showItemDetailsDialog(BuildContext context, AuctionItem item) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  color: Colors.black12,
                  child: ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                    child: _buildItemImage(item.imageUrl, width: double.infinity, height: 200),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.name,
                        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Actual / Starting Price:', style: TextStyle(fontSize: 14)),
                          Text(
                            '\$${item.startingPrice.toStringAsFixed(2)}',
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Winning Price:', style: TextStyle(fontSize: 14)),
                          Text(
                            '\$${item.currentBid.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontSize: 18,
                              color: Colors.green,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 24),
                      Text('Winning Bidder:',
                          style: TextStyle(color: Colors.grey[700], fontSize: 13)),
                      const SizedBox(height: 2),
                      Text(
                        item.highestBidder,
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      TextButton.icon(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        label: const Text('Delete', style: TextStyle(color: Colors.red)),
                        onPressed: () async {
                          await _auctionService.deleteAuction(item.id);
                          if (dialogContext.mounted) Navigator.pop(dialogContext);
                        },
                      ),
                      TextButton(
                        onPressed: () => Navigator.of(dialogContext).pop(),
                        child: const Text('Close', style: TextStyle(fontSize: 16)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final User? currentUser = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Auction Dashboard & Earnings'),
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(currentUser?.uid ?? '')
            .snapshots(),
        builder: (context, userSnapshot) {
          String username = currentUser?.email ?? 'User';
          String photoUrl = '';
          double profileEarnings = 0.0;

          if (userSnapshot.hasData && userSnapshot.data?.data() != null) {
            var userData = userSnapshot.data!.data() as Map<String, dynamic>;
            username = userData['username'] ?? username;
            photoUrl = userData['photoUrl'] ?? photoUrl;
            profileEarnings = (userData['totalEarnings'] ?? 0.0).toDouble();
          }

          return StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('auctions')
                .where('isSold', isEqualTo: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Center(
                    child: Text(
                      'Firestore Error: ${snapshot.error}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                    ),
                  ),
                );
              }

              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              List<AuctionItem> soldItems = [];
              double calculatedSoldSum = 0.0;

              if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
                soldItems = snapshot.data!.docs
                    .map((doc) => AuctionItem.fromFirestore(doc))
                    .toList();

                for (var item in soldItems) {
                  if (item.sellerId == currentUser?.uid || item.sellerId == 'anonymous') {
                    calculatedSoldSum += item.currentBid;
                  }
                }
              }

              // Use profile earnings if present; otherwise fallback to sum of sold items
              double totalDisplayEarnings =
              profileEarnings > 0 ? profileEarnings : calculatedSoldSum;

              return Column(
                children: [
                  // User Profile & Total Earnings Banner
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.all(16),
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Colors.deepPurple, Colors.indigo],
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _buildProfileImageWidget(photoUrl, radius: 35),
                            const SizedBox(width: 12),
                            IconButton(
                              icon: const Icon(Icons.edit, color: Colors.white70),
                              tooltip: 'Edit Profile',
                              onPressed: () => _showEditProfileDialog(username, photoUrl),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          username,
                          style: const TextStyle(
                              color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Total Money Earned',
                          style: TextStyle(color: Colors.white70, fontSize: 14),
                        ),
                        Text(
                          '\$${totalDisplayEarnings.toStringAsFixed(2)}',
                          style: const TextStyle(
                            color: Colors.greenAccent,
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Sold Auction Items (Tap for Details)',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  Expanded(
                    child: soldItems.isEmpty
                        ? const Center(child: Text('No completed auctions yet.'))
                        : ListView.builder(
                      itemCount: soldItems.length,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemBuilder: (context, index) {
                        final item = soldItems[index];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          clipBehavior: Clip.antiAlias,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 3,
                          child: InkWell(
                            onTap: () => _showItemDetailsDialog(context, item),
                            child: Padding(
                              padding: const EdgeInsets.all(12.0),
                              child: Row(
                                children: [
                                  Container(
                                    width: 60,
                                    height: 60,
                                    color: Colors.black12,
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: _buildItemImage(item.imageUrl,
                                          width: 60, height: 60),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          item.name,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          'Actual: \$${item.startingPrice.toStringAsFixed(2)}',
                                          style: TextStyle(
                                              color: Colors.grey[700], fontSize: 12),
                                        ),
                                        Text(
                                          'Winner: ${item.highestBidder}',
                                          style: TextStyle(
                                              color: Colors.grey[600], fontSize: 12),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        '\$${item.currentBid.toStringAsFixed(2)}',
                                        style: const TextStyle(
                                          color: Colors.green,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15,
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.delete_outline,
                                            color: Colors.redAccent, size: 22),
                                        onPressed: () async {
                                          await _auctionService.deleteAuction(item.id);
                                        },
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildProfileImageWidget(String photoUrl, {required double radius}) {
    if (photoUrl.startsWith('data:image')) {
      try {
        final base64Str = photoUrl.split(',').last;
        return CircleAvatar(
          radius: radius,
          backgroundImage: MemoryImage(base64Decode(base64Str)),
        );
      } catch (_) {}
    } else if (photoUrl.isNotEmpty) {
      return CircleAvatar(
        radius: radius,
        backgroundImage: NetworkImage(photoUrl),
      );
    }
    return CircleAvatar(
      radius: radius,
      backgroundColor: Colors.white24,
      child: Icon(Icons.person, size: radius * 1.1, color: Colors.white),
    );
  }

  static Widget _buildItemImage(String imageUrl,
      {required double width, required double height}) {
    if (imageUrl.startsWith('data:image')) {
      try {
        final base64Str = imageUrl.split(',').last;
        return Image.memory(
          base64Decode(base64Str),
          width: width,
          height: height,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) =>
              Container(width: width, height: height, color: Colors.grey[300], child: const Icon(Icons.image)),
        );
      } catch (_) {
        return Container(width: width, height: height, color: Colors.grey[300], child: const Icon(Icons.image));
      }
    }
    return Image.network(
      imageUrl,
      width: width,
      height: height,
      fit: BoxFit.contain,
      errorBuilder: (context, error, stackTrace) =>
          Container(width: width, height: height, color: Colors.grey[300], child: const Icon(Icons.image)),
    );
  }
}