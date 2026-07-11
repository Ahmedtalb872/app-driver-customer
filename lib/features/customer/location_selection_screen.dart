import 'package:flutter/material.dart';
import '../../core/constants/colors.dart';
import '../../dummy_data/dummy_data.dart';
import 'trip_details_screen.dart';

class LocationSelectionScreen extends StatefulWidget {
  const LocationSelectionScreen({super.key});

  @override
  State<LocationSelectionScreen> createState() => _LocationSelectionScreenState();
}

class _LocationSelectionScreenState extends State<LocationSelectionScreen> {
  final _pickupController = TextEditingController(text: 'موقعي الحالي (تفرغ زينة - مجمع البيت)');
  final _destController = TextEditingController();
  List<LocationItem> _filteredLocations = [];
  bool _showSuggestions = false;

  @override
  void initState() {
    super.initState();
    _filteredLocations = List.from(DummyData.nouakchottLocations);
  }

  @override
  void dispose() {
    _pickupController.dispose();
    _destController.dispose();
    super.dispose();
  }

  void _filterSearch(String query) {
    if (query.isEmpty) {
      setState(() {
        _filteredLocations = List.from(DummyData.nouakchottLocations);
        _showSuggestions = false;
      });
    } else {
      setState(() {
        _filteredLocations = DummyData.nouakchottLocations
            .where((loc) => loc.name.contains(query) || loc.description.contains(query))
            .toList();
        _showSuggestions = true;
      });
    }
  }

  void _selectDestination(LocationItem item) {
    _destController.text = item.name;
    
    // Simulate navigation to details screen with dummy distance and rates
    // Distance ranges from 3.5km to 24km depending on airport
    double distance = item.name.contains('المطار') ? 24.5 : 5.8;
    int duration = (distance * 1.5 + 4).round();
    double price = distance * 40 + 50; // base price + per km
    price = double.parse(price.toStringAsFixed(0)); // rounded integer

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => TripDetailsScreen(
          pickup: _pickupController.text,
          destination: item.name,
          pickupLat: 18.1025, // Mock pickup
          pickupLng: -15.9754,
          destLat: item.lat,
          destLng: item.lng,
          distance: distance,
          duration: duration,
          price: price,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('حدد مسار الرحلة'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Search Input Panel
            Container(
              color: Colors.white,
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  // From: Pickup Location
                  Row(
                    children: [
                      const Icon(Icons.radio_button_checked_rounded, color: AppColors.success, size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _pickupController,
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                          decoration: const InputDecoration(
                            hintText: 'موقع الانطلاق الحلي...',
                            contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  // To: Destination Location
                  Row(
                    children: [
                      const Icon(Icons.location_on_rounded, color: AppColors.error, size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _destController,
                          autofocus: true,
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                          decoration: const InputDecoration(
                            hintText: 'إلى أين تريد الذهاب؟',
                            contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          ),
                          onChanged: _filterSearch,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            
            // Map selector shortcut
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              color: AppColors.primary.withOpacity(0.04),
              child: InkWell(
                onTap: () {
                  // Choose first dummy location as map selection
                  _selectDestination(DummyData.nouakchottLocations[0]);
                },
                child: Row(
                  children: const [
                    Icon(Icons.map_rounded, color: AppColors.primary, size: 20),
                    SizedBox(width: 12),
                    Text(
                      'تحديد موقع وجهتي على الخريطة',
                      style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 13, fontFamily: 'Cairo'),
                    ),
                    Spacer(),
                    Icon(Icons.chevron_left_rounded, color: AppColors.primary, size: 20),
                  ],
                ),
              ),
            ),
            
            // Results list or Saved Places
            Expanded(
              child: _showSuggestions
                  ? _buildSearchResults()
                  : _buildSavedPlaces(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchResults() {
    if (_filteredLocations.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              Icon(Icons.sentiment_dissatisfied_rounded, color: AppColors.secondaryText, size: 40),
              SizedBox(height: 12),
              Text(
                'لم نجد أماكن تطابق بحثك',
                style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, color: AppColors.darkText),
              ),
              SizedBox(height: 4),
              Text(
                'يرجى التأكد من كتابة اسم الحي أو المكان بشكل صحيح.',
                style: TextStyle(fontFamily: 'Cairo', fontSize: 11, color: AppColors.secondaryText),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(24),
      itemCount: _filteredLocations.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final loc = _filteredLocations[index];
        return ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.border.withOpacity(0.5),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.place_rounded, color: AppColors.secondaryText, size: 20),
          ),
          title: Text(
            loc.name,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.darkText, fontFamily: 'Cairo'),
          ),
          subtitle: Text(
            loc.description,
            style: const TextStyle(fontSize: 11, color: AppColors.secondaryText, fontFamily: 'Cairo'),
          ),
          trailing: const Icon(Icons.arrow_back_rounded, size: 16),
          onTap: () => _selectDestination(loc),
        );
      },
    );
  }

  Widget _buildSavedPlaces() {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const Text(
          'أماكن محفوظة ومقترحة',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.darkText, fontFamily: 'Cairo'),
        ),
        const SizedBox(height: 12),
        ...DummyData.nouakchottLocations.take(5).map((loc) {
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: ListTile(
              leading: const Icon(Icons.bookmark_added_rounded, color: AppColors.primary),
              title: Text(loc.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, fontFamily: 'Cairo')),
              subtitle: Text(loc.description, style: const TextStyle(fontSize: 11, fontFamily: 'Cairo')),
              onTap: () => _selectDestination(loc),
            ),
          );
        }).toList(),
      ],
    );
  }
}
