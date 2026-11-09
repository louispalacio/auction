import 'package:cloud_firestore/cloud_firestore.dart';

class AuctionItem {
  final String id;
  final String name;
  final String imageUrl;
  final double currentBid;
  final String highestBidder;
  final String sellerId;
  final bool isSold;
  final DateTime createdAt;

  AuctionItem({
    required this.id,
    required this.name,
    required this.imageUrl,
    required this.currentBid,
    required this.highestBidder,
    required this.sellerId,
    required this.isSold,
    required this.createdAt,
  });

  factory AuctionItem.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return AuctionItem(
      id: doc.id,
      name: data['name'] ?? '',
      imageUrl: data['imageUrl'] ?? '',
      currentBid: (data['currentBid'] ?? 0.0).toDouble(),
      highestBidder: data['highestBidder'] ?? 'No bids',
      sellerId: data['sellerId'] ?? '',
      isSold: data['isSold'] ?? false,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
    );
  }
}