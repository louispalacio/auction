import 'package:cloud_firestore/cloud_firestore.dart';

class AuctionItem {
  final String id;
  final String name;
  final String imageUrl;
  final double startingPrice;
  final double currentBid;
  final String highestBidder;
  final String sellerId;
  final bool isSold;
  final DateTime createdAt;

  AuctionItem({
    required this.id,
    required this.name,
    required this.imageUrl,
    required this.startingPrice,
    required this.currentBid,
    required this.highestBidder,
    required this.sellerId,
    required this.isSold,
    required this.createdAt,
  });

  factory AuctionItem.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>? ?? {};
    return AuctionItem(
      id: doc.id,
      name: data['name'] ?? '',
      imageUrl: data['imageUrl'] ?? '',
      // Fallback to currentBid if startingPrice field is missing in older documents
      startingPrice: (data['startingPrice'] ?? data['currentBid'] ?? 0.0).toDouble(),
      currentBid: (data['currentBid'] ?? 0.0).toDouble(),
      highestBidder: data['highestBidder'] ?? 'No bids',
      sellerId: data['sellerId'] ?? '',
      isSold: data['isSold'] ?? false,
      createdAt: data['createdAt'] != null
          ? (data['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }
}