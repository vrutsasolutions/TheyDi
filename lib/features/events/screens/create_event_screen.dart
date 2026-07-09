import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

import '../../../core/services/cloudflare_upload.dart';
import '../../../core/services/location_service.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/screens/image_cropper_screen.dart';
import '../../../shared/widgets/gradient_button.dart';
import '../../../core/utils/picker_theme_helper.dart';

const _kCategories = [
  'Music',
  'Tech',
  'Sports',
  'Art',
  'Food',
  'Networking',
  'Gaming',
  'Fitness',
  'Comedy',
  'Workshop',
  'Party',
  'Social',
  'Adult Party',
  'Other',
];

const _kAdultAgeGroups = [
  'Young Adults (18–25)',
  'Adults (26–40)',
  'Middle Age (41–60)',
  'Seniors (60+)',
];
const List<String> _kStates = [
  'Andhra Pradesh',
  'Arunachal Pradesh',
  'Assam',
  'Bihar',
  'Chhattisgarh',
  'Goa',
  'Gujarat',
  'Haryana',
  'Himachal Pradesh',
  'Jharkhand',
  'Karnataka',
  'Kerala',
  'Madhya Pradesh',
  'Maharashtra',
  'Manipur',
  'Meghalaya',
  'Mizoram',
  'Nagaland',
  'Odisha',
  'Punjab',
  'Rajasthan',
  'Sikkim',
  'Tamil Nadu',
  'Telangana',
  'Tripura',
  'Uttar Pradesh',
  'Uttarakhand',
  'West Bengal',
];


final Map<String, List<String>> _stateCities = {
  'Andhra Pradesh': [
    'Visakhapatnam',
    'Vijayawada',
    'Tirupati',
    'Guntur',
    'Nellore',
    'Kurnool',
    'Rajahmundry',
    'Kakinada',
    'Anantapur',
    'Kadapa',
  ],

  'Arunachal Pradesh': [
    'Itanagar',
    'Naharlagun',
    'Pasighat',
    'Tawang',
    'Ziro',
    'Bomdila',
    'Tezu',
    'Roing',
    'Khonsa',
    'Along',
  ],

  'Assam': [
    'Guwahati',
    'Silchar',
    'Dibrugarh',
    'Jorhat',
    'Nagaon',
    'Tezpur',
    'Tinsukia',
    'Sivasagar',
    'Bongaigaon',
    'Goalpara',
  ],

  'Bihar': [
    'Patna',
    'Gaya',
    'Muzaffarpur',
    'Bhagalpur',
    'Darbhanga',
    'Purnia',
    'Ara',
    'Begusarai',
    'Katihar',
    'Munger',
  ],

  'Chhattisgarh': [
    'Raipur',
    'Bhilai',
    'Bilaspur',
    'Korba',
    'Raigarh',
    'Jagdalpur',
    'Ambikapur',
    'Dhamtari',
    'Rajnandgaon',
    'Mahasamund',
  ],

  'Goa': [
    'Panaji',
    'Margao',
    'Vasco da Gama',
    'Mapusa',
    'Ponda',
    'Bicholim',
    'Curchorem',
    'Canacona',
    'Sanquelim',
    'Valpoi',
  ],

  'Gujarat': [
    'Ahmedabad',
    'Surat',
    'Vadodara',
    'Rajkot',
    'Bhavnagar',
    'Jamnagar',
    'Junagadh',
    'Anand',
    'Gandhinagar',
    'Morbi',
  ],

  'Haryana': [
    'Gurugram',
    'Faridabad',
    'Panipat',
    'Ambala',
    'Hisar',
    'Karnal',
    'Rohtak',
    'Sonipat',
    'Yamunanagar',
    'Panchkula',
  ],

  'Himachal Pradesh': [
    'Shimla',
    'Manali',
    'Dharamshala',
    'Solan',
    'Mandi',
    'Hamirpur',
    'Una',
    'Bilaspur',
    'Kullu',
    'Chamba',
  ],

  'Jharkhand': [
    'Ranchi',
    'Jamshedpur',
    'Dhanbad',
    'Bokaro',
    'Deoghar',
    'Hazaribagh',
    'Giridih',
    'Ramgarh',
    'Chaibasa',
    'Medininagar',
  ],

  'Karnataka': [
    'Bengaluru',
    'Mysuru',
    'Mangaluru',
    'Hubballi',
    'Belagavi',
    'Shivamogga',
    'Davanagere',
    'Ballari',
    'Udupi',
    'Kalaburagi',
  ],

  'Kerala': [
    'Kochi',
    'Thiruvananthapuram',
    'Kozhikode',
    'Thrissur',
    'Kollam',
    'Kannur',
    'Alappuzha',
    'Palakkad',
    'Kottayam',
    'Malappuram',
  ],

  'Madhya Pradesh': [
    'Bhopal',
    'Indore',
    'Gwalior',
    'Jabalpur',
    'Ujjain',
    'Sagar',
    'Satna',
    'Ratlam',
    'Rewa',
    'Dewas',
  ],

  'Maharashtra': [
    'Mumbai',
    'Pune',
    'Nagpur',
    'Nashik',
    'Thane',
    'Aurangabad',
    'Kolhapur',
    'Solapur',
    'Amravati',
    'Navi Mumbai',
  ],

  'Manipur': [
    'Imphal',
    'Thoubal',
    'Bishnupur',
    'Ukhrul',
    'Churachandpur',
    'Kakching',
    'Senapati',
    'Tamenglong',
    'Jiribam',
    'Moirang',
  ],

  'Meghalaya': [
    'Shillong',
    'Tura',
    'Jowai',
    'Nongpoh',
    'Baghmara',
    'Williamnagar',
    'Resubelpara',
    'Mawkyrwat',
    'Nongstoin',
    'Khliehriat',
  ],

  'Mizoram': [
    'Aizawl',
    'Lunglei',
    'Champhai',
    'Kolasib',
    'Serchhip',
    'Saiha',
    'Mamit',
    'Lawngtlai',
    'Saitual',
    'Khawzawl',
  ],

  'Nagaland': [
    'Kohima',
    'Dimapur',
    'Mokokchung',
    'Tuensang',
    'Mon',
    'Wokha',
    'Zunheboto',
    'Phek',
    'Kiphire',
    'Longleng',
  ],

  'Odisha': [
    'Bhubaneswar',
    'Cuttack',
    'Rourkela',
    'Puri',
    'Sambalpur',
    'Balasore',
    'Berhampur',
    'Jharsuguda',
    'Baripada',
    'Jeypore',
  ],

  'Punjab': [
    'Ludhiana',
    'Amritsar',
    'Jalandhar',
    'Patiala',
    'Bathinda',
    'Mohali',
    'Pathankot',
    'Moga',
    'Hoshiarpur',
    'Kapurthala',
  ],

  'Rajasthan': [
    'Jaipur',
    'Jodhpur',
    'Udaipur',
    'Kota',
    'Ajmer',
    'Bikaner',
    'Alwar',
    'Bharatpur',
    'Sikar',
    'Pali',
  ],

  'Sikkim': [
    'Gangtok',
    'Namchi',
    'Gyalshing',
    'Mangan',
    'Rangpo',
    'Singtam',
    'Jorethang',
    'Ravangla',
    'Pakyong',
    'Soreng',
  ],

  'Tamil Nadu': [
    'Chennai',
    'Coimbatore',
    'Madurai',
    'Salem',
    'Tiruchirappalli',
    'Tirunelveli',
    'Erode',
    'Vellore',
    'Thoothukudi',
    'Kanchipuram',
  ],

  'Telangana': [
    'Hyderabad',
    'Warangal',
    'Karimnagar',
    'Nizamabad',
    'Khammam',
    'Ramagundam',
    'Mahbubnagar',
    'Siddipet',
    'Adilabad',
    'Nalgonda',
  ],

  'Tripura': [
    'Agartala',
    'Udaipur',
    'Dharmanagar',
    'Kailasahar',
    'Belonia',
    'Ambassa',
    'Khowai',
    'Sabroom',
    'Teliamura',
    'Sonamura',
  ],

  'Uttar Pradesh': [
    'Lucknow',
    'Kanpur',
    'Noida',
    'Ghaziabad',
    'Agra',
    'Varanasi',
    'Prayagraj',
    'Meerut',
    'Bareilly',
    'Gorakhpur',
  ],

  'Uttarakhand': [
    'Dehradun',
    'Haridwar',
    'Rishikesh',
    'Haldwani',
    'Roorkee',
    'Nainital',
    'Rudrapur',
    'Kashipur',
    'Almora',
    'Pithoragarh',
  ],

  'West Bengal': [
    'Kolkata',
    'Howrah',
    'Durgapur',
    'Siliguri',
    'Asansol',
    'Kharagpur',
    'Bardhaman',
    'Malda',
    'Haldia',
    'Darjeeling',
  ],
};

const _kAgeGroups = [
  'All Ages',
  'Kids (0–12)',
  'Teens (13–17)',
  'Young Adults (18–25)',
  'Adults (26–40)',
  'Middle Age (41–60)',
  'Seniors (60+)',
];

const _kDefaultAmenities = [
  {'label': 'Parking', 'icon': Icons.local_parking_outlined},
  {'label': 'Food & Drinks', 'icon': Icons.fastfood_outlined},
  {'label': 'DJ / Music', 'icon': Icons.music_note_outlined},
  {'label': 'AC', 'icon': Icons.ac_unit_outlined},
  {'label': 'Seating', 'icon': Icons.chair_outlined},
  {'label': 'Security', 'icon': Icons.security_outlined},
];

const _kImageSuggestions = {
  'Indoor': [
    'House / room setup',
    'Living room / hall interior',
    'Decorated space'
  ],
  'Outdoor': ['Park / open space', 'Outdoor area', 'Garden / rooftop'],
  'Venue': ['Club / hall interior', 'Rooftop venue', 'Stage / event space'],
};

// ── Geocoded result ────────────────────────────────────────────────────────────
class _GeoResult {
  final double lat;
  final double lng;
  final String displayAddress;
  const _GeoResult(
      {required this.lat, required this.lng, required this.displayAddress});
}

class CreateEventScreen extends StatefulWidget {
  const CreateEventScreen({super.key});

  @override
  State<CreateEventScreen> createState() => _CreateEventScreenState();
}

class _CreateEventScreenState extends State<CreateEventScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  final _venueController = TextEditingController();
  final _maxAttendeesController = TextEditingController(text: '50');
  final _priceController = TextEditingController(text: '0');
  final _customAmenityController = TextEditingController();
  final _additionalAddressController = TextEditingController();

  // Map
  GoogleMapController? _mapController;
  bool _updatingVenueProgrammatically = false;
  double _currentZoom = 15;
  LatLng _currentCenter = const LatLng(20.5937, 78.9629);
  Timer? _geocodeDebounce;

  // Location state
  double? _pinnedLat;
  double? _pinnedLng;
  String? _pinnedAddress;
  bool _isGeocoding = false;
  bool _showMapPreview = false;
  List<_GeoResult> _geoResults = []; // multiple results
  bool _showResultPicker = false;

String? _selectedCategory;
String? _selectedState;
String? _selectedCity;
final String _selectedCountry = 'India';

DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  bool _isFree = true;
  bool _isLoading = false;
  int _userAge = 99;

  String _eventType = 'Indoor';
  int _durationHours = 2;

  String _genderBalance = 'Open';
  double _malePercent = 50;
  double _femalePercent = 25;
  double _otherPercent = 25;

  String _ageGroup = 'All Ages';
  String _approvalType = 'Host Approval';

  final Set<String> _selectedAmenities = {};
  final List<String> _customAmenities = [];

  final List<_UploadedImage> _eventImages = [];
  bool _isUploadingImage = false;
  static const int _maxImages = 8;

  @override
  void initState() {
    super.initState();
    _loadUserAge();
    _venueController.addListener(_onVenueChanged);
  }

  @override
  void dispose() {
    _geocodeDebounce?.cancel();
    _venueController.removeListener(_onVenueChanged);
    _titleController.dispose();
    _descController.dispose();
    _venueController.dispose();
    _maxAttendeesController.dispose();
    _priceController.dispose();
    _customAmenityController.dispose();
    _additionalAddressController.dispose();
    super.dispose();
  }

  // ── Venue debounced geocoding ────────────────────────────────────────────────
  void _onVenueChanged() {
    if (_updatingVenueProgrammatically) return;

    _geocodeDebounce?.cancel();

    final text = _venueController.text.trim();

    if (text.length < 4) return;

    _geocodeDebounce = Timer(
      const Duration(milliseconds: 700),
      () {
        _geocodeVenue(text);
      },
    );
  }

  Future<void> _geocodeVenue(String query) async {
    // Append city for better accuracy
    final fullQuery = _selectedCity != null
        ? '$query, $_selectedCity, India'
        : '$query, India';

    setState(() {
      _isGeocoding = true;
      _showResultPicker = false;
      _geoResults = [];
    });

    try {
      final encodedQuery = Uri.encodeComponent(fullQuery);
      // Photon is a free, fast search autocomplete API for OpenStreetMap
      final url =
          Uri.parse('https://photon.komoot.io/api/?q=$encodedQuery&limit=5');

      final response = await http.get(url);

      if (!mounted) return;

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        final List<dynamic> features = data['features'] ?? [];

        if (features.isEmpty) {
          setState(() {
            _isGeocoding = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                  'Could not find location coordinates. Try adjusting the pin manually.'),
              backgroundColor: Colors.amber,
            ),
          );
          return;
        }

        final geoList = <_GeoResult>[];
        for (final feature in features) {
          final geometry = feature['geometry'] ?? {};
          final List<dynamic> coords = geometry['coordinates'] ?? [];
          final properties = feature['properties'] ?? {};

          if (coords.length >= 2) {
            // GeoJSON coordinates are [longitude, latitude]
            final lng = (coords[0] as num).toDouble();
            final lat = (coords[1] as num).toDouble();

            final name = properties['name'] ?? '';
            final street = properties['street'] ?? '';
            final city = properties['city'] ?? '';
            final state = properties['state'] ?? '';

            final parts = [name, street, city, state]
                .where((s) => s != null && s.toString().trim().isNotEmpty)
                .join(', ');

            geoList.add(_GeoResult(
              lat: lat,
              lng: lng,
              displayAddress: parts.isNotEmpty ? parts : fullQuery,
            ));
          }
        }

        if (geoList.isEmpty) {
          setState(() {
            _isGeocoding = false;
          });
          return;
        }

        if (geoList.length == 1) {
          _applyGeoResult(geoList.first);
        } else {
          setState(() {
            _geoResults = geoList;
            _showResultPicker = true;
            _isGeocoding = false;
          });
        }
      } else {
        setState(() {
          _isGeocoding = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isGeocoding = false;
        });
      }
    }
  }

  void _applyGeoResult(_GeoResult result) {
    setState(() {
      _pinnedLat = result.lat;
      _pinnedLng = result.lng;
      _pinnedAddress = result.displayAddress;
      _venueController.text = result.displayAddress;
      _showMapPreview = true;
      _showResultPicker = false;
      _geoResults = [];
      _isGeocoding = false;
    });

    // Move map
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _currentCenter = LatLng(result.lat, result.lng);
      _currentZoom = 15;

      _mapController?.animateCamera(
        CameraUpdate.newLatLngZoom(
          _currentCenter,
          _currentZoom,
        ),
      );
    });
  }

  // ── Reverse geocode after pin drag ──────────────────────────────────────────
  Future<void> _reverseGeocode(double lat, double lng) async {
    try {
      final apiKey = dotenv.env['GOOGLE_MAPS_API_KEY'];

      final url = 'https://maps.googleapis.com/maps/api/geocode/json'
          '?latlng=$lat,$lng'
          '&key=$apiKey';

      final response = await http.get(Uri.parse(url));
     

      if (response.statusCode != 200) return;

      final data = jsonDecode(response.body);

      if (data['results'] == null || data['results'].isEmpty) return;

      final result = data['results'][0];

      final formattedAddress = result['formatted_address'];

      String venue = "";
      String city = "";
      String additional = "";

      for (final component in result['address_components']) {
        final types = List<String>.from(component['types']);

        if (venue.isEmpty &&
            (types.contains('premise') ||
                types.contains('point_of_interest') ||
                types.contains('establishment'))) {
          venue = component['long_name'];
        }

        if (additional.isEmpty &&
            (types.contains('route') ||
                types.contains('sublocality') ||
                types.contains('sublocality_level_1'))) {
          additional = component['long_name'];
        }

        // Highest priority
        if (city.isEmpty && types.contains('locality')) {
          city = component['long_name'];
        }

        // Second priority
        else if (city.isEmpty && types.contains('postal_town')) {
          city = component['long_name'];
        }

        // Third priority
        else if (city.isEmpty &&
            types.contains('administrative_area_level_3')) {
          city = component['long_name'];
        }

        // Last priority
        else if (city.isEmpty &&
            types.contains('administrative_area_level_2')) {
          city = component['long_name'];
        }
      }

      if (!mounted) return;

      setState(() {
        _pinnedLat = lat;
        _pinnedLng = lng;

        _pinnedAddress = formattedAddress;

        _venueController.text = venue.isNotEmpty ? venue : formattedAddress;

        _updatingVenueProgrammatically = true;

        _venueController.text = venue.isNotEmpty ? venue : formattedAddress;

        _updatingVenueProgrammatically = false;

        _additionalAddressController.text = additional;

        String normalize(String value) {
          return value
              .toLowerCase()
              .replaceAll(' division', '')
              .replaceAll(' district', '')
              .replaceAll(' municipal corporation', '')
              .trim();
        }

        final normalizedCity = normalize(city);

        final allCities = _stateCities.values.expand((cities) => cities).toList();

final matchedCity = allCities.firstWhere(
  (c) {
    final item = normalize(c);
    return item.startsWith(normalizedCity);
  },
  orElse: () => '',
);

        if (matchedCity.isNotEmpty) {
          _selectedCity = matchedCity;
        }

        if (matchedCity.isNotEmpty) {
          _selectedCity = matchedCity;
        }
      });
    } catch (e) {
      debugPrint(e.toString());
    }
  }

  Future<void> _useCurrentLocation() async {
    setState(() => _isGeocoding = true);

    try {
      final position = await LocationService.getCurrentPosition();

      if (position == null) {
        if (!mounted) return;

        setState(() => _isGeocoding = false);

        _showError("Unable to get current location.");
        return;
      }

      await _reverseGeocode(
        position.latitude,
        position.longitude,
      );

      setState(() {
        _pinnedLat = position.latitude;
        _pinnedLng = position.longitude;
        _showMapPreview = true;
        _isGeocoding = false;
      });

      _currentCenter = LatLng(
        position.latitude,
        position.longitude,
      );

      _currentZoom = 15;

      _mapController?.animateCamera(
        CameraUpdate.newLatLngZoom(
          _currentCenter,
          _currentZoom,
        ),
      );
    } catch (e) {
      if (!mounted) return;

      setState(() => _isGeocoding = false);

      _showError(e.toString());
    }
  }

  void _clearLocation() {
    setState(() {
      _pinnedLat = null;
      _pinnedLng = null;
      _pinnedAddress = null;
      _showMapPreview = false;
      _showResultPicker = false;
      _geoResults = [];
    });
  }

  // ── User age ────────────────────────────────────────────────────────────────
  Future<void> _loadUserAge() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;
      final doc =
          await FirebaseFirestore.instance.collection('users').doc(uid).get();
      if (doc.exists) {
        final data = doc.data()!;
        final dob = data['dob'];
        DateTime? birthDate;
        if (dob is Timestamp) {
          birthDate = dob.toDate();
        } else if (dob is String && dob.isNotEmpty)
          birthDate = DateTime.tryParse(dob);
        if (birthDate != null && mounted) {
          final today = DateTime.now();
          int age = today.year - birthDate.year;
          if (today.month < birthDate.month ||
              (today.month == birthDate.month && today.day < birthDate.day)) {
            age--;
          }
          setState(() {
            _userAge = age;
          });
        } else if (mounted) {}
      }
    } catch (_) {}
  }

  bool get _isAdultParty => _selectedCategory == 'Adult Party';

  // ── Date picker (FIXED) ───────────────────────────────────────────────────
  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: PickerTheme.wrap, // ← replaces the old dark Theme block
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  // ── Time picker (FIXED) ──────────────────────────────────────────────────
  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
      builder: PickerTheme.wrap, // ← replaces ColorScheme.dark
    );
    if (picked != null) setState(() => _selectedTime = picked);
  }

  // ── Images ──────────────────────────────────────────────────────────────────
  Future<void> _pickImage(ImageSource source) async {
    if (_eventImages.length >= _maxImages) {
      _showError('Maximum $_maxImages images allowed');
      return;
    }
    setState(() => _isUploadingImage = true);
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
          source: source, maxWidth: 1080, maxHeight: 1080, imageQuality: 85);
      if (picked == null) {
        setState(() => _isUploadingImage = false);
        return;
      }

      final initialBytes = await picked.readAsBytes();
      if (!mounted) return;
      final bytes = await Navigator.push<Uint8List>(
        context,
        MaterialPageRoute(
          builder: (context) => ImageCropperScreen(
            imageBytes: initialBytes,
            aspectRatio: 16 / 9,
            title: 'Crop Event Cover Photo',
          ),
        ),
      );

      if (bytes == null) {
        setState(() => _isUploadingImage = false);
        return;
      }

      final tempId = DateTime.now().millisecondsSinceEpoch.toString();

      setState(() => _eventImages.add(_UploadedImage(
          id: tempId, bytes: bytes, url: null, isUploading: true)));

      final imageUrl = await CloudflareUpload.uploadBytes(
        bytes,
        "event_images/temp_$tempId.jpg",
      );

      if (imageUrl == null) {
        throw Exception("Cloudflare upload failed");
      }

      if (mounted) {
        setState(() {
          final idx = _eventImages.indexWhere(
            (img) => img.id == tempId,
          );

          if (idx != -1) {
            _eventImages[idx] = _UploadedImage(
              id: tempId,
              bytes: bytes,
              url: imageUrl,
              isUploading: false,
            );
          }
        });
      }

      if (mounted) {
        setState(() {
          final idx = _eventImages.indexWhere((img) => img.id == tempId);
          if (idx != -1) {
            _eventImages[idx] = _UploadedImage(
                id: tempId, bytes: bytes, url: imageUrl, isUploading: false);
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _eventImages.removeWhere((img) => img.isUploading));
        _showError('Failed to upload image: $e');
      }
    } finally {
      if (mounted) setState(() => _isUploadingImage = false);
    }
  }

  void _removeImage(String id) =>
      setState(() => _eventImages.removeWhere((img) => img.id == id));

  void _showImageSourceSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: TheyDiColors.card,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: TheyDiColors.divider,
                    borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 16),
            Text('Add Photo', style: TheyDiTextStyles.headlineMedium),
            const SizedBox(height: 16),
            Row(children: [
              Expanded(
                  child: GestureDetector(
                onTap: () {
                  Navigator.pop(ctx);
                  _pickImage(ImageSource.gallery);
                },
                child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                        color: TheyDiColors.inputFill,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: TheyDiColors.divider)),
                    child: Column(children: [
                      const Icon(Icons.photo_library_outlined,
                          color: TheyDiColors.primary, size: 28),
                      const SizedBox(height: 8),
                      Text('Gallery', style: TheyDiTextStyles.labelMedium)
                    ])),
              )),
              const SizedBox(width: 12),
              Expanded(
                  child: GestureDetector(
                onTap: () {
                  Navigator.pop(ctx);
                  _pickImage(ImageSource.camera);
                },
                child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                        color: TheyDiColors.inputFill,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: TheyDiColors.divider)),
                    child: Column(children: [
                      const Icon(Icons.camera_alt_outlined,
                          color: TheyDiColors.primary, size: 28),
                      const SizedBox(height: 8),
                      Text('Camera', style: TheyDiTextStyles.labelMedium)
                    ])),
              )),
            ]),
            const SizedBox(height: 8),
          ]),
        ),
      ),
    );
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(msg),
        backgroundColor: TheyDiColors.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16)));
  }

  void _onCategoryChanged(String? cat) {
    setState(() {
      _selectedCategory = cat;
      if (cat == 'Party' || cat == 'Adult Party') _eventType = 'Indoor';
      if (cat == 'Adult Party') _ageGroup = 'Young Adults (18–25)';
    });
  }

  void _updateGenderRatio() {
    _otherPercent = (100 - _malePercent - _femalePercent).clamp(0, 100);
  }

  void _addCustomAmenity() {
    final val = _customAmenityController.text.trim();
    if (val.isEmpty) return;
    if (_customAmenities.contains(val) ||
        _kDefaultAmenities.any((a) => a['label'] == val)) {
      return;
    }
    setState(() {
      _customAmenities.add(val);
      _selectedAmenities.add(val);
      _customAmenityController.clear();
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedDate == null) {
      _showError('Please pick a date');
      return;
    }
    if (_selectedTime == null) {
      _showError('Please pick a time');
      return;
    }
    if (_pinnedLat == null || _pinnedLng == null) {
      _showError('Please set a location for your event');
      return;
    }
    if (_eventImages.any((img) => img.isUploading)) {
      _showError('Please wait for images to finish uploading');
      return;
    }

    if (_selectedCategory == 'Adult Party') {
      if (_eventType == 'Outdoor') {
        _showError('Adult Party events must be Indoor');
        return;
      }
      if (!_kAdultAgeGroups.contains(_ageGroup)) {
        _showError('Adult Party requires an 18+ age group');
        return;
      }
    }

    setState(() => _isLoading = true);
    try {
      final user = FirebaseAuth.instance.currentUser!;
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();

      if (!_isFree) {
        final data = userDoc.data() ?? {};
        if (data['razorpayXFundAccountId'] == null || data['razorpayXFundAccountId'].toString().isEmpty) {
          Map<String, dynamic> bankData = {};
          try {
            final bankDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).collection('private').doc('bankDetails').get();
            bankData = bankDoc.data() ?? {};
            
            if (bankData.isEmpty) {
              if (data['bankAccountName'] != null || data['bankAccountNumber'] != null) {
                bankData = {
                  'payoutMethod': 'bank',
                  'bankAccountName': data['bankAccountName'],
                  'bankIfsc': data['bankIfsc'],
                  'bankAccountNumber': data['bankAccountNumber'],
                };
              }
            }
          } catch (e) {
            debugPrint('Error fetching bank details: $e');
          }
          setState(() => _isLoading = false);
          _showBankAccountSetupDialog(existingData: bankData);
          return;
        }
      }

      final dateTime = DateTime(_selectedDate!.year, _selectedDate!.month,
          _selectedDate!.day, _selectedTime!.hour, _selectedTime!.minute);

      String creatorName = user.displayName ?? 'Anonymous';
      try {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
        if (userDoc.exists) {
          creatorName = userDoc.data()?['displayName'] ?? creatorName;
        }
      } catch (_) {}

      final imageUrls = _eventImages
          .where((img) => img.url != null)
          .map((img) => img.url!)
          .toList();

      final eventData = {
        'title': _titleController.text.trim(),
        'description': _descController.text.trim(),
        'category': _selectedCategory ?? 'Other',
'state': _selectedState ?? '',
'country': _selectedCountry,
'city': _selectedCity ?? '',
'venue': _venueController.text.trim(),
        'additionalAddress': _additionalAddressController.text.trim(),
        'dateTime': Timestamp.fromDate(dateTime),
        'creatorUid': user.uid,
        'creatorName': creatorName,
        'imageUrl': imageUrls.isNotEmpty ? imageUrls.first : null,
        'imageUrls': imageUrls,
        'maxAttendees': int.tryParse(_maxAttendeesController.text) ?? 50,
        'attendeeUids': <String>[],
        'pendingUids': <String>[],
        'isFree': _isFree,
        'price':
            _isFree ? 0.0 : (double.tryParse(_priceController.text) ?? 0.0),
        'createdAt': FieldValue.serverTimestamp(),
        'latitude': _pinnedLat!,
        'longitude': _pinnedLng!,
        'address': _pinnedAddress ?? '',
        'tags': <String>[],
        'eventType': _eventType,
        'durationHours': _durationHours,
        'genderBalance': _genderBalance,
        'genderRatio': _genderBalance == 'Ratio'
            ? {
                'male': _malePercent,
                'female': _femalePercent,
                'other': _otherPercent
              }
            : null,
        'ageGroup': _ageGroup,
        'minAge': _isAdultParty ? 18 : 0,
        'approvalType': _approvalType,
        'amenities': _selectedAmenities.toList(),
      };

      final docRef = await FirebaseFirestore.instance.collection('events').add(eventData);
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({'eventsCreated': FieldValue.increment(1)});

      // ── Email: confirm event creation to host ──
      await NotificationService.notifyEventCreatedEmail(
        hostUid: user.uid,
        eventTitle: _titleController.text.trim(),
        eventDate: DateFormat('EEE, MMM d \u00b7 h:mm a').format(dateTime),
        eventVenue: _venueController.text.trim(),
        eventId: docRef.id,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: const Text('Event created! 🎉'),
            backgroundColor: TheyDiColors.success,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.all(16)));
        context.pop();
      }
    } catch (e) {
      _showError('Failed to create event. Please try again.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showBankAccountSetupDialog({Map<String, dynamic>? existingData}) {
    String _payoutMethod = existingData?['payoutMethod'] ?? 'bank';
    final nameCtrl = TextEditingController(
      text: existingData?['bankAccountName'] as String?
          ?? FirebaseAuth.instance.currentUser?.displayName
          ?? '',
    );
    final ifscCtrl = TextEditingController(
      text: (existingData?['bankIfsc'] ?? '') as String,
    );
    final accCtrl = TextEditingController(
      text: (existingData?['bankAccountNumber'] ?? '') as String,
    );
    final upiCtrl = TextEditingController(
      text: (existingData?['upiId'] ?? '') as String,
    );
    bool isSaving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: TheyDiColors.card,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          return Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom, left: 24, right: 24, top: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Setup Host Payouts', style: TheyDiTextStyles.headlineMedium),
                const SizedBox(height: 8),
                Text('You are creating a paid event. Please add your payout details to receive earnings.', style: TheyDiTextStyles.bodySmall.copyWith(color: TheyDiColors.textSecondary)),
                const SizedBox(height: 20),
                
                Container(
                  decoration: BoxDecoration(
                    color: TheyDiColors.divider.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setModalState(() => _payoutMethod = 'bank'),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 250),
                            curve: Curves.easeInOut,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: _payoutMethod == 'bank' ? TheyDiColors.primary : Colors.transparent,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Center(
                              child: Text('Bank Account', style: TextStyle(
                                color: _payoutMethod == 'bank' ? Colors.white : TheyDiColors.textPrimary,
                                fontWeight: FontWeight.w600,
                              )),
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setModalState(() => _payoutMethod = 'upi'),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 250),
                            curve: Curves.easeInOut,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: _payoutMethod == 'upi' ? TheyDiColors.primary : Colors.transparent,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Center(
                              child: Text('UPI', style: TextStyle(
                                color: _payoutMethod == 'upi' ? Colors.white : TheyDiColors.textPrimary,
                                fontWeight: FontWeight.w600,
                              )),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  transitionBuilder: (Widget child, Animation<double> animation) {
                    return FadeTransition(opacity: animation, child: SizeTransition(sizeFactor: animation, child: child));
                  },
                  child: _payoutMethod == 'bank'
                      ? Column(
                          key: const ValueKey('bank'),
                          children: [
                            TextFormField(
                              controller: nameCtrl,
                              style: TheyDiTextStyles.bodyMedium,
                              decoration: const InputDecoration(labelText: 'Account Holder Name', prefixIcon: Icon(Icons.person_outline)),
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: ifscCtrl,
                              style: TheyDiTextStyles.bodyMedium,
                              decoration: const InputDecoration(labelText: 'IFSC Code', hintText: 'e.g. HDFC0001234', prefixIcon: Icon(Icons.account_balance_outlined)),
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: accCtrl,
                              style: TheyDiTextStyles.bodyMedium,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(labelText: 'Account Number', prefixIcon: Icon(Icons.numbers_outlined)),
                            ),
                          ],
                        )
                      : Column(
                          key: const ValueKey('upi'),
                          children: [
                            TextFormField(
                              controller: upiCtrl,
                              style: TheyDiTextStyles.bodyMedium,
                              decoration: const InputDecoration(labelText: 'UPI ID (VPA)', hintText: 'e.g. username@bank', prefixIcon: Icon(Icons.payment)),
                            ),
                          ],
                        ),
                ),
                const SizedBox(height: 24),
                
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: isSaving ? null : () async {
                      if (_payoutMethod == 'bank') {
                        if (nameCtrl.text.trim().isEmpty || ifscCtrl.text.trim().isEmpty || accCtrl.text.trim().isEmpty) {
                          ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Please fill all bank fields')));
                          return;
                        }
                      } else {
                        if (upiCtrl.text.trim().isEmpty) {
                          ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Please enter your UPI ID')));
                          return;
                        }
                      }

                      setModalState(() => isSaving = true);
                      try {
                        final HttpsCallable callable = FirebaseFunctions.instanceFor(region: 'asia-south1').httpsCallable('createRazorpayXContact');
                        await callable.call({
                          'payoutMethod': _payoutMethod,
                          'upiId': upiCtrl.text.trim(),
                          'name': nameCtrl.text.trim(),
                          'ifsc': ifscCtrl.text.trim(),
                          'accountNumber': accCtrl.text.trim(),
                        });
                        
                        final uid = FirebaseAuth.instance.currentUser?.uid;
                        if (uid != null) {
                          await FirebaseFirestore.instance.collection('users').doc(uid).collection('private').doc('bankDetails').set({
                            'payoutMethod': _payoutMethod,
                            'upiId': upiCtrl.text.trim(),
                            'bankAccountName': nameCtrl.text.trim(),
                            'bankIfsc': ifscCtrl.text.trim(),
                            'bankAccountNumber': accCtrl.text.trim(),
                          }, SetOptions(merge: true));
                        }
                        if (mounted) {
                          Navigator.pop(ctx);
                          _submit(); // Resume event creation
                        }
                      } catch (e) {
                        setModalState(() => isSaving = false);
                        if (mounted) {
                          ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('Error: $e')));
                        }
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: TheyDiColors.primary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: isSaving 
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Text('Save & Continue', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final suggestions =
        _kImageSuggestions[_eventType] ?? _kImageSuggestions['Indoor']!;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
            gradient: LinearGradient(
                colors: [Color(0xFFFFFFFF), Color(0xFFF3F4F6)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter)),
        child: SafeArea(
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
              child: Row(children: [
                IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new, size: 20),
                    color: TheyDiColors.textPrimary,
                    onPressed: () => context.pop()),
                Expanded(
                    child: Text(
  'Create Event',
  style: TheyDiTextStyles.displayMedium,
  textAlign: TextAlign.center,
)),
                const SizedBox(width: 40),
              ]),
            ),
            Expanded(
                child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
              child: Form(
                key: _formKey,
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Title ──
                      const _Label('Event Title *'),
                      const SizedBox(height: 8),
                      TextFormField(
                              controller: _titleController,
                              style: TheyDiTextStyles.bodyMedium,
                              textCapitalization: TextCapitalization.words,
                              decoration: const InputDecoration(
                                  hintText: 'e.g. Rooftop Mixer',
                                  prefixIcon: Icon(Icons.title_outlined)),
                              validator: (v) => (v == null || v.trim().isEmpty)
                                  ? 'Title is required'
                                  : null)
                          .animate(delay: 60.ms)
                          .fade(duration: 300.ms),

                      const SizedBox(height: 16),

                      // ── Description ──
                      const _Label('Description *'),
                      const SizedBox(height: 8),
                      TextFormField(
                              controller: _descController,
                              style: TheyDiTextStyles.bodyMedium,
                              maxLines: 3,
                              decoration: const InputDecoration(
                                  hintText:
                                      'Tell people what this event is about...',
                                  alignLabelWithHint: true),
                              validator: (v) => (v == null || v.trim().isEmpty)
                                  ? 'Description is required'
                                  : null)
                          .animate(delay: 80.ms)
                          .fade(duration: 300.ms),

                      const SizedBox(height: 16),

                      // ── Category ──
                      const _Label('Category'),
                      const SizedBox(height: 8),
                      _DropdownField<String>(
                              hint: 'Select category',
                              value: _selectedCategory,
                              items: _kCategories
                                  .where((c) =>
                                      c != 'Adult Party' || _userAge >= 18)
                                  .map((c) => DropdownMenuItem(
                                      value: c,
                                      child: Row(children: [
                                        Text(c,
                                            style: TheyDiTextStyles.bodyMedium),
                                        if (c == 'Adult Party') ...[
                                          const SizedBox(width: 6),
                                          Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 6,
                                                      vertical: 2),
                                              decoration: BoxDecoration(
                                                  color: Colors.red
                                                      .withValues(alpha: 0.15),
                                                  borderRadius:
                                                      BorderRadius.circular(6)),
                                              child: Text('🔞 18+',
                                                  style: TheyDiTextStyles
                                                      .caption
                                                      .copyWith(
                                                          color: Colors.red,
                                                          fontSize: 10,
                                                          fontWeight: FontWeight
                                                              .w600))),
                                        ],
                                      ])))
                                  .toList(),
                              onChanged: _onCategoryChanged,
                              icon: Icons.category_outlined)
                          .animate(delay: 100.ms)
                          .fade(duration: 300.ms),

                      const SizedBox(height: 16),

                      // ── Event Type ──
                      const _Label('Event Type'),
                      const SizedBox(height: 8),
                      Row(children: [
                        _PillButton(
                            label: 'Indoor',
                            icon: Icons.home_outlined,
                            isSelected: _eventType == 'Indoor',
                            onTap: () => setState(() => _eventType = 'Indoor')),
                        const SizedBox(width: 10),
                        _PillButton(
                            label: 'Outdoor',
                            icon: Icons.park_outlined,
                            isSelected: _eventType == 'Outdoor',
                            onTap: _isAdultParty
                                ? null
                                : () => setState(() => _eventType = 'Outdoor'),
                            disabled: _isAdultParty),
                      ]).animate(delay: 110.ms).fade(duration: 300.ms),

                      const SizedBox(height: 16),

                      // House/Room + State
// ── House / Room ─────────────────────────────────────
const _Label('House/Room/Floor/Additional'),
const SizedBox(height: 8),

TextFormField(
  controller: _additionalAddressController,
  style: TheyDiTextStyles.bodyMedium,
  decoration: const InputDecoration(
    hintText: 'e.g. Room 4B, 3rd Floor',
    prefixIcon: Icon(Icons.info_outline),
  ),
).animate(delay: 120.ms).fade(duration: 300.ms),

const SizedBox(height: 16),
                      // ── Venue + Country ─────────────────────────────────────────────
Row(
  crossAxisAlignment: CrossAxisAlignment.start,
  children: [
    Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _Label('Venue *'),
          const SizedBox(height: 8),
          TextFormField(
            controller: _venueController,
            style: TheyDiTextStyles.bodyMedium,
            decoration: InputDecoration(
              hintText: 'e.g. Sky Lounge, MG Road',
              prefixIcon: const Icon(Icons.place_outlined),
              suffixIcon: _isGeocoding
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: TheyDiColors.primary,
                        ),
                      ),
                    )
                  : _pinnedLat != null
                      ? const Icon(
                          Icons.check_circle,
                          color: Colors.green,
                          size: 20,
                        )
                      : null,
            ),
            validator: (v) =>
                (v == null || v.trim().isEmpty)
                    ? 'Venue is required'
                    : null,
          ),
        ],
      ),
    ),

    const SizedBox(width: 16),

    Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _Label('Country'),
          const SizedBox(height: 8),
          TextFormField(
            initialValue: 'India',
            enabled: false,
            style: TheyDiTextStyles.bodyMedium,
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.flag_outlined),
            ),
          ),
        ],
      ),
    ),
  ],
).animate(delay: 140.ms).fade(duration: 300.ms),

                      // ── Multiple results picker ──
                      if (_showResultPicker && _geoResults.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Container(
                          decoration: BoxDecoration(
                            color: TheyDiColors.card,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: TheyDiColors.primary
                                    .withValues(alpha: 0.4)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding:
                                    const EdgeInsets.fromLTRB(14, 10, 14, 4),
                                child: Row(children: [
                                  const Icon(Icons.location_on_outlined,
                                      size: 14, color: TheyDiColors.primary),
                                  const SizedBox(width: 6),
                                  Text('Select matching location',
                                      style: TheyDiTextStyles.caption.copyWith(
                                          color: TheyDiColors.primary,
                                          fontWeight: FontWeight.w600)),
                                ]),
                              ),
                              const Divider(
                                  height: 1, color: TheyDiColors.divider),
                              ..._geoResults.asMap().entries.map((entry) {
                                final i = entry.key;
                                final r = entry.value;
                                return GestureDetector(
                                  onTap: () => _applyGeoResult(r),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 14, vertical: 12),
                                    decoration: BoxDecoration(
                                      border: i < _geoResults.length - 1
                                          ? const Border(
                                              bottom: BorderSide(
                                                  color: TheyDiColors.divider))
                                          : null,
                                    ),
                                    child: Row(children: [
                                      Container(
                                        width: 28,
                                        height: 28,
                                        decoration: BoxDecoration(
                                            color: TheyDiColors.primary
                                                .withValues(alpha: 0.12),
                                            shape: BoxShape.circle),
                                        child: Center(
                                            child: Text('${i + 1}',
                                                style: TheyDiTextStyles.caption
                                                    .copyWith(
                                                        color: TheyDiColors
                                                            .primary,
                                                        fontWeight:
                                                            FontWeight.w700))),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                          child: Text(r.displayAddress,
                                              style: TheyDiTextStyles.bodySmall
                                                  .copyWith(
                                                      color: TheyDiColors
                                                          .textSecondary))),
                                      const Icon(Icons.chevron_right,
                                          size: 16,
                                          color: TheyDiColors.textMuted),
                                    ]),
                                  ),
                                );
                              }),
                            ],
                          ),
                        ),
                      ],

                      const SizedBox(height: 12),

                      const SizedBox(height: 16),

Row(
  crossAxisAlignment: CrossAxisAlignment.start,
  children: [
    Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _Label('State'),
          const SizedBox(height: 8),
          _DropdownField<String>(
            hint: 'Select state',
            value: _selectedState,
            items: _kStates.map((s) {
              return DropdownMenuItem<String>(
                value: s,
                child: Text(
                  s,
                  style: TheyDiTextStyles.bodyMedium,
                ),
              );
            }).toList(),
            onChanged: (v) {
              setState(() {
                _selectedState = v;
                _selectedCity = null;
              });
            },
            icon: Icons.map_outlined,
          ),
        ],
      ),
    ),

  const SizedBox(width: 12),

    Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _Label('City'),
          const SizedBox(height: 8),
          _DropdownField<String>(
            hint: 'Select city',
            value: _selectedCity,
            items: (_selectedState == null
                    ? <String>[]
                    : _stateCities[_selectedState] ?? [])
                .map((city) => DropdownMenuItem<String>(
                      value: city,
                      child: Text(
                        city,
                        style: TheyDiTextStyles.bodyMedium,
                      ),
                    ))
                .toList(),
            onChanged: (v) {
              setState(() => _selectedCity = v);

              if (_venueController.text.trim().isNotEmpty) {
                _geocodeVenue(_venueController.text.trim());
              }
            },
            icon: Icons.location_city_outlined,
          ),
        ],
      ),
    ),
  ],
).animate(delay: 150.ms).fade(duration: 300.ms),

const SizedBox(height: 16),

                      // ── Location Section ──
                      const _Label('Pin Location *'),
                      const SizedBox(height: 8),

                      // Status bar
                      if (_pinnedLat != null) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: Colors.green.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: Colors.green.withValues(alpha: 0.3)),
                          ),
                          child: Row(children: [
                            const Icon(Icons.check_circle,
                                color: Colors.green, size: 16),
                            const SizedBox(width: 8),
                            Expanded(
                                child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                  Text('📍 Location detected',
                                      style: TheyDiTextStyles.caption.copyWith(
                                          color: Colors.green,
                                          fontWeight: FontWeight.w600)),
                                  if (_pinnedAddress != null)
                                    Text(_pinnedAddress!,
                                        style: TheyDiTextStyles.caption
                                            .copyWith(
                                                color:
                                                    TheyDiColors.textSecondary),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis),
                                  Text(
                                      '${_pinnedLat!.toStringAsFixed(5)}, ${_pinnedLng!.toStringAsFixed(5)}',
                                      style: TheyDiTextStyles.caption.copyWith(
                                          color: TheyDiColors.textMuted,
                                          fontSize: 10)),
                                ])),
                            GestureDetector(
                              onTap: _clearLocation,
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                    color: TheyDiColors.card,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                        color: TheyDiColors.divider)),
                                child: const Icon(Icons.close,
                                    size: 14, color: TheyDiColors.textMuted),
                              ),
                            ),
                          ]),
                        ),
                        const SizedBox(height: 10),
                      ],

                      // GPS fallback button (shown when no location set)
                      if (_pinnedLat == null)
                        GestureDetector(
                          onTap: _isGeocoding ? null : _useCurrentLocation,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 12),
                            decoration: BoxDecoration(
                              color: TheyDiColors.inputFill,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: TheyDiColors.divider),
                            ),
                            child: Row(children: [
                              if (_isGeocoding)
                                const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                        color: TheyDiColors.primary,
                                        strokeWidth: 2))
                              else
                                const Icon(Icons.my_location_outlined,
                                    size: 18, color: TheyDiColors.primary),
                              const SizedBox(width: 10),
                              Text('Use GPS instead',
                                  style: TheyDiTextStyles.bodySmall.copyWith(
                                      color: TheyDiColors.textSecondary)),
                              const Spacer(),
                              Text('Optional',
                                  style: TheyDiTextStyles.caption
                                      .copyWith(color: TheyDiColors.textMuted)),
                            ]),
                          ),
                        ),

                      // ── MAP PREVIEW ──
                      if (_showMapPreview &&
                          _pinnedLat != null &&
                          _pinnedLng != null) ...[
                        const SizedBox(height: 12),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            height: 220,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                  color: TheyDiColors.primary
                                      .withValues(alpha: 0.3)),
                            ),
                            child: Stack(children: [
                              GoogleMap(
                                initialCameraPosition: CameraPosition(
                                  target: LatLng(_pinnedLat!, _pinnedLng!),
                                  zoom: 15,
                                ),
                                onMapCreated: (controller) {
                                  _mapController = controller;

                                  _currentCenter = LatLng(
                                    _pinnedLat!,
                                    _pinnedLng!,
                                  );
                                  _currentZoom = 15;
                                },
                                onTap: (LatLng position) {
                                  setState(() {
                                    _pinnedLat = position.latitude;
                                    _pinnedLng = position.longitude;

                                    _currentCenter = position;
                                  });

                                  _reverseGeocode(
                                    position.latitude,
                                    position.longitude,
                                  );
                                },
                                myLocationEnabled: true,
                                myLocationButtonEnabled: true,
                                compassEnabled: true,
                                markers: {
                                  Marker(
                                    markerId:
                                        const MarkerId("selected_location"),
                                    position: LatLng(
                                      _pinnedLat!,
                                      _pinnedLng!,
                                    ),
                                  ),
                                },
                              ),
                              // "Tap to adjust" overlay label
                              Positioned(
                                bottom: 10,
                                left: 0,
                                right: 0,
                                child: Center(
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 5),
                                    decoration: BoxDecoration(
                                      color:
                                          Colors.black.withValues(alpha: 0.65),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(Icons.touch_app_outlined,
                                              size: 13, color: Colors.white),
                                          const SizedBox(width: 5),
                                          Text('Tap map to adjust pin',
                                              style: TheyDiTextStyles.caption
                                                  .copyWith(
                                                      color: Colors.white,
                                                      fontSize: 11)),
                                        ]),
                                  ),
                                ),
                              ),

                              // Zoom in/out controls
                            ]),
                          ),
                        ),
                      ],

                      const SizedBox(height: 16),

                      // ── Date & Time ──
                      Row(children: [
                        Expanded(
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                              const _Label('Date'),
                              const SizedBox(height: 8),
                              _PickerTile(
                                  icon: Icons.calendar_today_outlined,
                                  label: _selectedDate != null
                                      ? DateFormat('d MMM yyyy')
                                          .format(_selectedDate!)
                                      : 'Pick date',
                                  onTap: _pickDate)
                            ])),
                        const SizedBox(width: 12),
                        Expanded(
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                              const _Label('Time'),
                              const SizedBox(height: 8),
                              _PickerTile(
                                  icon: Icons.access_time_outlined,
                                  label: _selectedTime != null
                                      ? _selectedTime!.format(context)
                                      : 'Pick time',
                                  onTap: _pickTime)
                            ])),
                      ]).animate(delay: 160.ms).fade(duration: 300.ms),

                      const SizedBox(height: 16),

                      // ── Duration ──
                      const _Label('Duration (hours)'),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                            color: TheyDiColors.inputFill,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: TheyDiColors.divider)),
                        child: Row(children: [
                          const Icon(Icons.timer_outlined,
                              size: 18, color: TheyDiColors.textMuted),
                          const SizedBox(width: 10),
                          Text(
                              '$_durationHours hr${_durationHours > 1 ? 's' : ''}',
                              style: TheyDiTextStyles.bodyMedium),
                          const Spacer(),
                          GestureDetector(
                              onTap: _durationHours > 1
                                  ? () => setState(() => _durationHours--)
                                  : null,
                              child: Container(
                                  width: 36,
                                  height: 36,
                                  decoration: BoxDecoration(
                                      color: _durationHours > 1
                                          ? TheyDiColors.primary
                                              .withValues(alpha: 0.2)
                                          : TheyDiColors.card,
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                          color: _durationHours > 1
                                              ? TheyDiColors.primary
                                              : TheyDiColors.divider)),
                                  child: Icon(Icons.remove,
                                      size: 18,
                                      color: _durationHours > 1
                                          ? TheyDiColors.primary
                                          : TheyDiColors.textMuted))),
                          const SizedBox(width: 8),
                          GestureDetector(
                              onTap: _durationHours < 24
                                  ? () => setState(() => _durationHours++)
                                  : null,
                              child: Container(
                                  width: 36,
                                  height: 36,
                                  decoration: BoxDecoration(
                                      color: TheyDiColors.primary
                                          .withValues(alpha: 0.2),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                          color: TheyDiColors.primary)),
                                  child: const Icon(Icons.add,
                                      size: 18, color: TheyDiColors.primary))),
                        ]),
                      ).animate(delay: 165.ms).fade(duration: 300.ms),

                      const SizedBox(height: 16),

                      // ── Max Attendees ──
                      const _Label('Max Attendees'),
                      const SizedBox(height: 8),
                      TextFormField(
                              controller: _maxAttendeesController,
                              style: TheyDiTextStyles.bodyMedium,
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly
                              ],
                              decoration: const InputDecoration(
                                  hintText: '50',
                                  prefixIcon: Icon(Icons.group_outlined)))
                          .animate(delay: 180.ms)
                          .fade(duration: 300.ms),

                      const SizedBox(height: 16),

                      // ── Gender Balance ──
                      const _Label('Gender Balance (Optional)'),
                      const SizedBox(height: 8),
                      Wrap(spacing: 8, runSpacing: 8, children: [
                        _PillButton(
                            label: 'Open',
                            icon: Icons.people_outline,
                            isSelected: _genderBalance == 'Open',
                            onTap: () =>
                                setState(() => _genderBalance = 'Open')),
                        _PillButton(
                            label: 'Ratio',
                            icon: Icons.tune,
                            isSelected: _genderBalance == 'Ratio',
                            onTap: () =>
                                setState(() => _genderBalance = 'Ratio')),
                        _PillButton(
                            label: 'Female Only',
                            icon: Icons.female,
                            isSelected: _genderBalance == 'Female Only',
                            onTap: () =>
                                setState(() => _genderBalance = 'Female Only')),
                        _PillButton(
                            label: 'Male Only',
                            icon: Icons.male,
                            isSelected: _genderBalance == 'Male Only',
                            onTap: () =>
                                setState(() => _genderBalance = 'Male Only')),
                      ]).animate(delay: 190.ms).fade(duration: 300.ms),

                      if (_genderBalance == 'Ratio') ...[
                        const SizedBox(height: 14),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                              color: TheyDiColors.card,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: TheyDiColors.divider)),
                          child: Column(children: [
                            _RatioSlider(
                                label: 'Male',
                                value: _malePercent,
                                color: Colors.blue,
                                onChanged: (v) => setState(() {
                                      _malePercent = v;
                                      _updateGenderRatio();
                                    })),
                            const SizedBox(height: 10),
                            _RatioSlider(
                                label: 'Female',
                                value: _femalePercent,
                                color: Colors.pink,
                                onChanged: (v) => setState(() {
                                      _femalePercent = v;
                                      _updateGenderRatio();
                                    })),
                            const SizedBox(height: 10),
                            Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('Other',
                                      style: TheyDiTextStyles.caption),
                                  Text('${_otherPercent.round()}%',
                                      style: TheyDiTextStyles.labelMedium
                                          .copyWith(color: Colors.green))
                                ]),
                            const SizedBox(height: 8),
                            ClipRRect(
                                borderRadius: BorderRadius.circular(6),
                                child: Row(children: [
                                  Expanded(
                                      flex: _malePercent.round().clamp(1, 100),
                                      child: Container(
                                          height: 8, color: Colors.blue)),
                                  Expanded(
                                      flex:
                                          _femalePercent.round().clamp(1, 100),
                                      child: Container(
                                          height: 8, color: Colors.pink)),
                                  if (_otherPercent > 0)
                                    Expanded(
                                        flex:
                                            _otherPercent.round().clamp(1, 100),
                                        child: Container(
                                            height: 8, color: Colors.green)),
                                ])),
                          ]),
                        ).animate(delay: 200.ms).fade(duration: 300.ms),
                      ],

                      const SizedBox(height: 16),

                      // ── Age Group ──
                      const _Label('Age Group'),
                      const SizedBox(height: 8),
                      _DropdownField<String>(
                              hint: 'Select age group',
                              value: _ageGroup,
                              items: (_isAdultParty
                                      ? _kAdultAgeGroups
                                      : _kAgeGroups)
                                  .map((a) => DropdownMenuItem(
                                      value: a,
                                      child: Text(a,
                                          style: TheyDiTextStyles.bodyMedium)))
                                  .toList(),
                              onChanged: (v) => setState(() => _ageGroup = v ??
                                  (_isAdultParty
                                      ? 'Young Adults (18–25)'
                                      : 'All Ages')),
                              icon: Icons.people_alt_outlined)
                          .animate(delay: 205.ms)
                          .fade(duration: 300.ms),

                      const SizedBox(height: 16),

                      // ── Approval Type ──
                      const _Label('Approval Type'),
                      const SizedBox(height: 8),
                      Row(children: [
                        Expanded(
                            child: _PillButton(
                                label: 'Host Approval',
                                icon: Icons.verified_user_outlined,
                                isSelected: _approvalType == 'Host Approval',
                                onTap: () => setState(
                                    () => _approvalType = 'Host Approval'))),
                        const SizedBox(width: 10),
                        Expanded(
                            child: _PillButton(
                                label: 'First Come',
                                icon: Icons.flash_on_outlined,
                                isSelected:
                                    _approvalType == 'First Come First Serve',
                                onTap: () => setState(() =>
                                    _approvalType = 'First Come First Serve'))),
                      ]).animate(delay: 210.ms).fade(duration: 300.ms),

                      const SizedBox(height: 20),

                      // ── Free / Paid ──
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                            color: TheyDiColors.card,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: TheyDiColors.divider)),
                        child: Column(children: [
                          Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(children: [
                                  const Icon(Icons.confirmation_number_outlined,
                                      size: 18,
                                      color: TheyDiColors.textSecondary),
                                  const SizedBox(width: 8),
                                  Text('Free Event',
                                      style: TheyDiTextStyles.bodyMedium)
                                ]),
                                Switch(
                                    value: _isFree,
                                    activeThumbColor: TheyDiColors.primary,
                                    onChanged: (v) =>
                                        setState(() => _isFree = v)),
                              ]),
                          if (!_isFree) ...[
                            const SizedBox(height: 12),
                            TextFormField(
                                controller: _priceController,
                                style: TheyDiTextStyles.bodyMedium,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                        decimal: true),
                                decoration: const InputDecoration(
                                    hintText: '299',
                                    prefixIcon:
                                        Icon(Icons.currency_rupee_outlined),
                                    labelText: 'Price (₹)'),
                                validator: (v) {
                                  if (!_isFree && (v == null || v.isEmpty)) {
                                    return 'Enter a price';
                                  }
                                  return null;
                                }),
                          ],
                        ]),
                      ).animate(delay: 220.ms).fade(duration: 300.ms),

                      const SizedBox(height: 20),

                      // ── Amenities ──
                      const _Label('Amenities (Optional)'),
                      const SizedBox(height: 4),
                      Text('Let attendees know what\'s available at your event',
                          style: TheyDiTextStyles.caption
                              .copyWith(color: TheyDiColors.textSecondary)),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                            color: TheyDiColors.card,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: TheyDiColors.divider)),
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Wrap(spacing: 8, runSpacing: 8, children: [
                                ..._kDefaultAmenities.map((amenity) {
                                  final label = amenity['label'] as String;
                                  final icon = amenity['icon'] as IconData;
                                  final isSelected =
                                      _selectedAmenities.contains(label);
                                  return GestureDetector(
                                    onTap: () => setState(() {
                                      if (isSelected) {
                                        _selectedAmenities.remove(label);
                                      } else {
                                        _selectedAmenities.add(label);
                                      }
                                    }),
                                    child: AnimatedContainer(
                                        duration:
                                            const Duration(milliseconds: 200),
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 12, vertical: 8),
                                        decoration: BoxDecoration(
                                            color: isSelected
                                                ? TheyDiColors.primary
                                                    .withValues(alpha: 0.18)
                                                : TheyDiColors.inputFill,
                                            borderRadius:
                                                BorderRadius.circular(20),
                                            border: Border.all(
                                                color: isSelected
                                                    ? TheyDiColors.primary
                                                    : TheyDiColors.divider)),
                                        child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(icon,
                                                  size: 15,
                                                  color: isSelected
                                                      ? TheyDiColors.primary
                                                      : TheyDiColors
                                                          .textSecondary),
                                              const SizedBox(width: 6),
                                              Text(label,
                                                  style: TheyDiTextStyles
                                                      .caption
                                                      .copyWith(
                                                          color: isSelected
                                                              ? TheyDiColors
                                                                  .primary
                                                              : TheyDiColors
                                                                  .textSecondary,
                                                          fontWeight: isSelected
                                                              ? FontWeight.w600
                                                              : FontWeight
                                                                  .normal))
                                            ])),
                                  );
                                }),
                                ..._customAmenities.map((label) {
                                  final isSelected =
                                      _selectedAmenities.contains(label);
                                  return GestureDetector(
                                    onTap: () => setState(() {
                                      if (isSelected) {
                                        _selectedAmenities.remove(label);
                                      } else {
                                        _selectedAmenities.add(label);
                                      }
                                    }),
                                    child: AnimatedContainer(
                                        duration:
                                            const Duration(milliseconds: 200),
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 12, vertical: 8),
                                        decoration: BoxDecoration(
                                            color: isSelected
                                                ? TheyDiColors.primary
                                                    .withValues(alpha: 0.18)
                                                : TheyDiColors.inputFill,
                                            borderRadius:
                                                BorderRadius.circular(20),
                                            border: Border.all(
                                                color: isSelected
                                                    ? TheyDiColors.primary
                                                    : TheyDiColors.divider)),
                                        child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              const Icon(
                                                  Icons.add_circle_outline,
                                                  size: 14,
                                                  color: TheyDiColors.primary),
                                              const SizedBox(width: 5),
                                              Text(label,
                                                  style: TheyDiTextStyles
                                                      .caption
                                                      .copyWith(
                                                          color: isSelected
                                                              ? TheyDiColors
                                                                  .primary
                                                              : TheyDiColors
                                                                  .textSecondary,
                                                          fontWeight: isSelected
                                                              ? FontWeight.w600
                                                              : FontWeight
                                                                  .normal)),
                                              const SizedBox(width: 4),
                                              GestureDetector(
                                                  onTap: () => setState(() {
                                                        _customAmenities
                                                            .remove(label);
                                                        _selectedAmenities
                                                            .remove(label);
                                                      }),
                                                  child: const Icon(Icons.close,
                                                      size: 13,
                                                      color: TheyDiColors
                                                          .textMuted))
                                            ])),
                                  );
                                }),
                              ]),
                              const SizedBox(height: 14),
                              const Divider(color: TheyDiColors.divider),
                              const SizedBox(height: 10),
                              Row(children: [
                                Expanded(
                                    child: TextFormField(
                                        controller: _customAmenityController,
                                        style: TheyDiTextStyles.bodySmall,
                                        textCapitalization:
                                            TextCapitalization.words,
                                        decoration: InputDecoration(
                                            hintText: 'Add custom amenity...',
                                            hintStyle: TheyDiTextStyles.caption
                                                .copyWith(
                                                    color:
                                                        TheyDiColors.textMuted),
                                            contentPadding:
                                                const EdgeInsets.symmetric(
                                                    horizontal: 12,
                                                    vertical: 10),
                                            border: OutlineInputBorder(
                                                borderRadius:
                                                    BorderRadius.circular(10),
                                                borderSide: const BorderSide(
                                                    color:
                                                        TheyDiColors.divider)),
                                            enabledBorder: OutlineInputBorder(
                                                borderRadius:
                                                    BorderRadius.circular(10),
                                                borderSide: const BorderSide(
                                                    color: TheyDiColors.divider)),
                                            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: TheyDiColors.primary)),
                                            filled: true,
                                            fillColor: TheyDiColors.inputFill),
                                        onFieldSubmitted: (_) => _addCustomAmenity())),
                                const SizedBox(width: 10),
                                GestureDetector(
                                    onTap: _addCustomAmenity,
                                    child: Container(
                                        width: 42,
                                        height: 42,
                                        decoration: BoxDecoration(
                                            gradient:
                                                TheyDiColors.gradientPrimary,
                                            borderRadius:
                                                BorderRadius.circular(12)),
                                        child: const Icon(Icons.add,
                                            color: Colors.white, size: 20))),
                              ]),
                            ]),
                      ).animate(delay: 228.ms).fade(duration: 300.ms),

                      const SizedBox(height: 24),

                      // ── Event Images ──
                      const _Label('Event Images'),
                      const SizedBox(height: 4),
                      Text(
                          'Add up to $_maxImages photos to showcase your event',
                          style: TheyDiTextStyles.caption
                              .copyWith(color: TheyDiColors.textSecondary)),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                            color: TheyDiColors.primary.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                                color: TheyDiColors.primary
                                    .withValues(alpha: 0.2))),
                        child: Row(children: [
                          const Icon(Icons.lightbulb_outline,
                              size: 14, color: TheyDiColors.primary),
                          const SizedBox(width: 8),
                          Expanded(
                              child: Text(
                                  'Suggestions for $_eventType: ${suggestions.join(' · ')}',
                                  style: TheyDiTextStyles.caption.copyWith(
                                      color: TheyDiColors.primary,
                                      fontSize: 11))),
                        ]),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 110,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          children: [
                            if (_eventImages.length < _maxImages)
                              GestureDetector(
                                onTap: _isUploadingImage
                                    ? null
                                    : _showImageSourceSheet,
                                child: Container(
                                  width: 90,
                                  height: 90,
                                  margin: const EdgeInsets.only(right: 10),
                                  decoration: BoxDecoration(
                                      color: TheyDiColors.inputFill,
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(
                                          color: TheyDiColors.primary
                                              .withValues(alpha: 0.4),
                                          width: 1.5)),
                                  child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Container(
                                            width: 32,
                                            height: 32,
                                            decoration: const BoxDecoration(
                                                gradient: TheyDiColors
                                                    .gradientPrimary,
                                                shape: BoxShape.circle),
                                            child: const Icon(
                                                Icons
                                                    .add_photo_alternate_outlined,
                                                color: Colors.white,
                                                size: 18)),
                                        const SizedBox(height: 6),
                                        Text('Add Photo',
                                            style: TheyDiTextStyles.caption
                                                .copyWith(
                                                    color: TheyDiColors.primary,
                                                    fontSize: 10)),
                                      ]),
                                ),
                              ),
                            ..._eventImages.map((img) => Container(
                                  width: 90,
                                  height: 90,
                                  margin: const EdgeInsets.only(right: 10),
                                  decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(14)),
                                  child: Stack(children: [
                                    ClipRRect(
                                        borderRadius: BorderRadius.circular(14),
                                        child: Image.memory(
                                            Uint8List.fromList(img.bytes),
                                            width: 90,
                                            height: 90,
                                            fit: BoxFit.cover)),
                                    if (img.isUploading)
                                      Container(
                                          width: 90,
                                          height: 90,
                                          decoration: BoxDecoration(
                                              color: Colors.black
                                                  .withValues(alpha: 0.5),
                                              borderRadius:
                                                  BorderRadius.circular(14)),
                                          child: const Center(
                                              child: SizedBox(
                                                  width: 24,
                                                  height: 24,
                                                  child:
                                                      CircularProgressIndicator(
                                                          color: Colors.white,
                                                          strokeWidth: 2)))),
                                    if (!img.isUploading)
                                      Positioned(
                                          top: 4,
                                          right: 4,
                                          child: GestureDetector(
                                              onTap: () => _removeImage(img.id),
                                              child: Container(
                                                  width: 22,
                                                  height: 22,
                                                  decoration: BoxDecoration(
                                                      color: Colors.black
                                                          .withValues(
                                                              alpha: 0.7),
                                                      shape: BoxShape.circle),
                                                  child: const Icon(Icons.close,
                                                      size: 12,
                                                      color: Colors.white)))),
                                    if (_eventImages.first.id == img.id &&
                                        !img.isUploading)
                                      Positioned(
                                          bottom: 0,
                                          left: 0,
                                          right: 0,
                                          child: Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      vertical: 3),
                                              decoration: BoxDecoration(
                                                  color: TheyDiColors.primary
                                                      .withValues(alpha: 0.8),
                                                  borderRadius: const BorderRadius.vertical(
                                                      bottom:
                                                          Radius.circular(14))),
                                              child: Text('Cover',
                                                  style: TheyDiTextStyles.caption
                                                      .copyWith(
                                                          color: Colors.white,
                                                          fontSize: 9,
                                                          fontWeight:
                                                              FontWeight.w600),
                                                  textAlign: TextAlign.center))),
                                  ]),
                                )),
                          ],
                        ),
                      ),
                      Align(
                          alignment: Alignment.centerRight,
                          child: Text(
                              '${_eventImages.length} / $_maxImages photos',
                              style: TheyDiTextStyles.caption.copyWith(
                                  color: TheyDiColors.textMuted,
                                  fontSize: 11))),

                      const SizedBox(height: 32),

                      if (_isLoading)
                        const Center(
                            child: CircularProgressIndicator(
                                color: TheyDiColors.primary))
                      else
                        GradientButton(
                                label: 'Create Event 🚀', onPressed: _submit)
                            .animate(delay: 250.ms)
                            .fade(duration: 300.ms),
                    ]),
              ),
            )),
          ]),
        ),
      ),
    );
  }
}

// ── Map zoom button ───────────────────────────────────────────────────────────
class _MapButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _MapButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: TheyDiColors.divider),
        ),
        child: Icon(icon, size: 18, color: Colors.white),
      ),
    );
  }
}

// ── Uploaded image data class ─────────────────────────────────────────────────
class _UploadedImage {
  final String id;
  final List<int> bytes;
  final String? url;
  final bool isUploading;
  const _UploadedImage(
      {required this.id,
      required this.bytes,
      required this.url,
      required this.isUploading});
}

// ── Helper widgets ────────────────────────────────────────────────────────────

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);
  @override
  Widget build(BuildContext context) => Text(text,
      style: TheyDiTextStyles.labelMedium
          .copyWith(color: TheyDiColors.textSecondary));
}

class _DropdownField<T> extends StatelessWidget {
  final String hint;
  final T? value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;
  final IconData icon;
  const _DropdownField(
      {required this.hint,
      required this.value,
      required this.items,
      required this.onChanged,
      required this.icon});

  @override
  Widget build(BuildContext context) {
    return InputDecorator(
      decoration: InputDecoration(
        prefixIcon: Icon(icon, size: 18, color: TheyDiColors.textMuted),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 18, vertical: 13.5),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: TheyDiColors.divider),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: TheyDiColors.divider),
        ),
        fillColor: TheyDiColors.inputFill,
        filled: true,
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          isDense: true,
          hint: Text(
            hint,
            style: TheyDiTextStyles.bodyMedium
                .copyWith(color: TheyDiColors.textMuted),
          ),
          dropdownColor: TheyDiColors.card,
          isExpanded: true,
          icon: const Icon(Icons.keyboard_arrow_down,
              color: TheyDiColors.textMuted),
          items: items,
          onChanged: onChanged,
        ),
      ),
    );
  }
}

class _PickerTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _PickerTile(
      {required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
              color: TheyDiColors.inputFill,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: TheyDiColors.divider)),
          child: Row(children: [
            Icon(icon, size: 16, color: TheyDiColors.textMuted),
            const SizedBox(width: 8),
            Expanded(
                child: Text(label,
                    style: TheyDiTextStyles.bodySmall
                        .copyWith(color: TheyDiColors.textPrimary),
                    overflow: TextOverflow.ellipsis))
          ])),
    );
  }
}

class _PillButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback? onTap;
  final bool disabled;
  const _PillButton(
      {required this.label,
      required this.icon,
      required this.isSelected,
      required this.onTap,
      this.disabled = false});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: disabled
                ? TheyDiColors.card.withValues(alpha: 0.5)
                : isSelected
                    ? TheyDiColors.primary.withValues(alpha: 0.2)
                    : TheyDiColors.card,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
                color: disabled
                    ? TheyDiColors.divider.withValues(alpha: 0.4)
                    : isSelected
                        ? TheyDiColors.primary
                        : TheyDiColors.divider),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon,
                size: 16,
                color: disabled
                    ? TheyDiColors.textMuted
                    : isSelected
                        ? TheyDiColors.primary
                        : TheyDiColors.textSecondary),
            const SizedBox(width: 6),
            Text(label,
                style: TheyDiTextStyles.caption.copyWith(
                    color: disabled
                        ? TheyDiColors.textMuted
                        : isSelected
                            ? TheyDiColors.primary
                            : TheyDiColors.textSecondary,
                    fontWeight:
                        isSelected ? FontWeight.w600 : FontWeight.normal)),
            if (disabled) ...[
              const SizedBox(width: 4),
              const Icon(Icons.lock_outline,
                  size: 11, color: TheyDiColors.textMuted)
            ],
          ])),
    );
  }
}

class _RatioSlider extends StatelessWidget {
  final String label;
  final double value;
  final Color color;
  final ValueChanged<double> onChanged;
  const _RatioSlider(
      {required this.label,
      required this.value,
      required this.color,
      required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      SizedBox(width: 55, child: Text(label, style: TheyDiTextStyles.caption)),
      Expanded(
          child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                  activeTrackColor: color,
                  inactiveTrackColor: color.withValues(alpha: 0.2),
                  thumbColor: color,
                  trackHeight: 4,
                  thumbShape:
                      const RoundSliderThumbShape(enabledThumbRadius: 7)),
              child: Slider(
                  value: value,
                  min: 0,
                  max: 100,
                  divisions: 20,
                  onChanged: onChanged))),
      SizedBox(
          width: 40,
          child: Text('${value.round()}%',
              style: TheyDiTextStyles.labelMedium.copyWith(color: color),
              textAlign: TextAlign.right)),
    ]);
  }
}
