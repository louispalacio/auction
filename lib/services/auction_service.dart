import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class AuctionService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<String> uploadImage(File imageFile) async {
    String fileName = DateTime.now().millisecondsSinceEpoch.toString();
    Reference ref = _storage.ref().child('auction_images/$fileName.jpg');
    UploadTask uploadTask = ref.putFile(imageFile);
    TaskSnapshot snapshot = await uploadTask;
    return await snapshot.ref.getDownloadURL();
  }

  Future<String> createAuction({
    required String name,
    required double startingPrice,
    required File imageFile,
  }) async {
    String imageUrl = await uploadImage(imageFile);
    String userId = _auth.currentUser?.uid ?? 'anonymous';

    DocumentReference docRef = await _db.collection('auctions').add({
      'name': name,
      'imageUrl': imageUrl,
      'currentBid': startingPrice,
      'highestBidder': 'Initial Price',
      'sellerId': userId,
      'isSold': false,
      'createdAt': FieldValue.serverTimestamp(),
    });

    return docRef.id;
  }

  Future<void> placeBid(String itemId, double newBid, String bidderEmail) async {
    await _db.collection('auctions').doc(itemId).update({
      'currentBid': newBid,
      'highestBidder': bidderEmail,
    });
  }

  Future<void> finalizeAuction(String itemId, String itemName, double finalPrice, String buyerEmail) async {
    String userId = _auth.currentUser?.uid ?? '';

    await _db.collection('auctions').doc(itemId).update({'isSold': true});

    DocumentReference userRef = _db.collection('users').doc(userId);
    await _db.runTransaction((transaction) async {
      DocumentSnapshot snapshot = await transaction.get(userRef);
      if (!snapshot.exists) {
        transaction.set(userRef, {'totalEarnings': finalPrice});
      } else {
        double currentEarnings = (snapshot.get('totalEarnings') ?? 0.0).toDouble();
        transaction.update(userRef, {'totalEarnings': currentEarnings + finalPrice});
      }
    });

    await sendWinnerEmail(buyerEmail, itemName, finalPrice);
  }

  Future<void> sendWinnerEmail(String recipientEmail, String itemName, double price) async {
    const String apiUrl = 'https://api.sendgrid.com/v3/mail/send';
    const String apiKey = 'YOUR_SENDGRID_API_KEY';

    try {
      await http.post(
        Uri.parse(apiUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $apiKey',
        },
        body: jsonEncode({
          'personalizations': [
            {
              'to': [{'email': recipientEmail}],
              'subject': 'Auction Victory: $itemName'
            }
          ],
          'from': {'email': 'no-reply@auctionapp.com'},
          'content': [
            {
              'type': 'text/plain',
              'value': 'Congratulations! You won the auction for "$itemName" with a final bid of \$${price.toStringAsFixed(2)}.'
            }
          ]
        }),
      );
    } catch (e) {
      debugPrint('Email delivery exception: $e');
    }
  }
}