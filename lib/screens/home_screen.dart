import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auction_service.dart';
import 'dashboard_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final AuctionService _auctionService = AuctionService();
  final ImagePicker _picker = ImagePicker();
  final _itemNameController = TextEditingController();
  final _startingPriceController = TextEditingController();

  File? _selectedImage;
  Timer? _biddingTimer;
  bool _isAuctionActive = false;
  bool _isCreating = false;
  String? _activeAuctionId;
  double _currentBid = 0.0;
  String _currentBidder = 'No Bids Yet';

  final List<String> _simulatedBidders = [
    'alex@auction.com',
    'sarah_bids@gmail.com',
    'pro_trader@yahoo.com',
    'collector_99@domain.com'
  ];

  Future<void> _pickImage(ImageSource source) async {
    final XFile? picked = await _picker.pickImage(source: source, imageQuality: 80);
    if (picked != null) {
      setState(() {
        _selectedImage = File(picked.path);
      });
    }
  }

  void _showImageSourceDialog() {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Take Photo from Camera'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Select from Gallery'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _startAuction() async {
    if (_selectedImage == null ||
        _itemNameController.text.trim().isEmpty ||
        _startingPriceController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please upload an image and fill out all item details.')),
      );
      return;
    }

    setState(() => _isCreating = true);

    try {
      double price = double.parse(_startingPriceController.text.trim());

      String newId = await _auctionService.createAuction(
        name: _itemNameController.text.trim(),
        startingPrice: price,
        imageFile: _selectedImage!,
      );

      if (!mounted) return;

      setState(() {
        _activeAuctionId = newId;
        _isAuctionActive = true;
        _currentBid = price;
        _currentBidder = 'Initial Starting Price';
      });

      _biddingTimer?.cancel();
      _biddingTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
        _processNextBid();
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Auction started successfully!')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error starting auction: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isCreating = false);
    }
  }

  void _processNextBid() {
    if (!_isAuctionActive || _activeAuctionId == null) return;

    final random = Random();
    double increment = (random.nextInt(15) + 5).toDouble();
    double updatedBid = _currentBid + increment;
    String nextBidder = _simulatedBidders[random.nextInt(_simulatedBidders.length)];

    setState(() {
      _currentBid = updatedBid;
      _currentBidder = nextBidder;
    });

    _auctionService.placeBid(_activeAuctionId!, updatedBid, nextBidder);
  }

  Future<void> _stopAuctionAndSolve() async {
    _biddingTimer?.cancel();
    if (_activeAuctionId != null) {
      await _auctionService.finalizeAuction(
        _activeAuctionId!,
        _itemNameController.text,
        _currentBid,
        _currentBidder,
      );
    }

    if (!mounted) return;

    setState(() {
      _isAuctionActive = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Auction Closed! Sold to $_currentBidder for \$${_currentBid.toStringAsFixed(2)}. Winner notified!')),
    );
  }

  @override
  void dispose() {
    _biddingTimer?.cancel();
    _itemNameController.dispose();
    _startingPriceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Live Auction House'),
        actions: [
          IconButton(
            icon: const Icon(Icons.dashboard),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const DashboardScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => FirebaseAuth.instance.signOut(),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            GestureDetector(
              onTap: _showImageSourceDialog,
              child: Container(
                height: 180,
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.deepPurple, width: 2),
                ),
                child: _selectedImage != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.file(_selectedImage!, fit: BoxFit.cover),
                      )
                    : const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_a_photo, size: 50, color: Colors.deepPurple),
                          SizedBox(height: 8),
                          Text('Tap to capture/select item image'),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _itemNameController,
              decoration: const InputDecoration(
                labelText: 'Auction Item Name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _startingPriceController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Starting Bid Amount (\$)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            _isCreating
                ? const Center(child: CircularProgressIndicator())
                : ElevatedButton.icon(
                    onPressed: _isAuctionActive ? null : _startAuction,
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('Start Live 5-Second Auction'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
            const SizedBox(height: 20),

            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              color: Colors.black87,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'LIVE BID SCREEN',
                          style: TextStyle(
                            color: Colors.greenAccent,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: _isAuctionActive ? Colors.red : Colors.grey,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            _isAuctionActive ? 'LIVE (5s Interval)' : 'STOPPED',
                            style: const TextStyle(color: Colors.white, fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                    const Divider(color: Colors.grey),
                    const SizedBox(height: 10),
                    Text(
                      '\$${_currentBid.toStringAsFixed(2)}',
                      style: const TextStyle(
                        color: Colors.amberAccent,
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Highest Bidder: $_currentBidder',
                      style: const TextStyle(color: Colors.white70, fontSize: 14),
                    ),
                    const SizedBox(height: 16),
                    if (_isAuctionActive)
                      ElevatedButton.icon(
                        onPressed: _stopAuctionAndSolve,
                        icon: const Icon(Icons.stop_circle),
                        label: const Text('STOP & SOLVE (Mark Sold)'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.redAccent,
                          foregroundColor: Colors.white,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}