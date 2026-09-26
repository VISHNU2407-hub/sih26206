import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/disaster_event_model.dart';
import '../../models/missing_person_alert_model.dart';
import '../../models/user_model.dart';
import '../../services/cloudinary_service.dart';
import '../../services/disaster_service.dart';
import '../../services/firestore_service.dart';
import '../../services/missing_person_alert_service.dart';
import '../../utils/helpers.dart';

class CreateMissingPersonAlertScreen extends StatefulWidget {
  final MissingPersonAlertModel? existingAlert;

  const CreateMissingPersonAlertScreen({super.key, this.existingAlert});

  @override
  State<CreateMissingPersonAlertScreen> createState() =>
      _CreateMissingPersonAlertScreenState();
}

class _CreateMissingPersonAlertScreenState
    extends State<CreateMissingPersonAlertScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _ageController = TextEditingController();
  final _lastSeenLocationController = TextEditingController();
  final _clothesController = TextEditingController();
  final _notesController = TextEditingController();
  final _guardianPhoneController = TextEditingController();
  final _whatsappController = TextEditingController();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirestoreService _firestoreService = FirestoreService();
  final CloudinaryService _cloudinaryService = CloudinaryService();
  final MissingPersonAlertService _alertService = MissingPersonAlertService();

  File? _selectedPhoto;
  UserModel? _currentUser;
  DateTime? _missingDateTime;
  String? _gender;
  String? _disasterId;
  bool _isSaving = false;
  bool get _isEditMode => widget.existingAlert != null;

  final List<String> _genderOptions = const ['Male', 'Female', 'Other'];

  @override
  void initState() {
    super.initState();
    _prefillForEdit();
    _loadCurrentUser();
  }

  void _prefillForEdit() {
    final alert = widget.existingAlert;
    if (alert == null) return;
    _fullNameController.text = alert.fullName;
    _ageController.text = alert.age.toString();
    _lastSeenLocationController.text = alert.lastSeenLocation;
    _clothesController.text = alert.clothesDescription;
    _notesController.text = alert.additionalNotes;
    _guardianPhoneController.text = alert.guardianContactNumber;
    _whatsappController.text = alert.whatsappNumber;
    _missingDateTime = alert.missingDateTime;
    _gender = alert.gender;
    _disasterId = alert.disasterId;
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _ageController.dispose();
    _lastSeenLocationController.dispose();
    _clothesController.dispose();
    _notesController.dispose();
    _guardianPhoneController.dispose();
    _whatsappController.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentUser() async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      final userData = await _firestoreService.getUser(user.uid);
      if (mounted) {
        setState(() => _currentUser = userData);
      }
    } catch (e) {
      if (mounted) {
        AppHelpers.showErrorSnackBar(context, 'Failed to load user data');
      }
    }
  }

  Future<void> _pickPhotoFromGallery() async {
    await _pickPhoto(() => _cloudinaryService.pickImageFromGallery());
  }

  Future<void> _pickPhotoFromCamera() async {
    await _pickPhoto(() => _cloudinaryService.pickImageFromCamera());
  }

  Future<void> _pickPhoto(Future<File?> Function() picker) async {
    try {
      final photo = await picker();
      if (photo != null && mounted) {
        setState(() => _selectedPhoto = photo);
      }
    } catch (e) {
      if (mounted) {
        AppHelpers.showErrorSnackBar(context, _cleanError(e));
      }
    }
  }

  Future<void> _selectMissingDateTime() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: _missingDateTime ?? now,
      firstDate: DateTime(now.year - 5),
      lastDate: now,
    );
    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: _missingDateTime == null
          ? TimeOfDay.now()
          : TimeOfDay.fromDateTime(_missingDateTime!),
    );
    if (time == null) return;

    final selected = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );

    if (selected.isAfter(DateTime.now())) {
      if (mounted) {
        AppHelpers.showErrorSnackBar(
          context,
          'Missing date and time cannot be in the future',
        );
      }
      return;
    }

    setState(() => _missingDateTime = selected);
  }

  Future<void> _submitAlert() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedPhoto == null && !_isEditMode) {
      AppHelpers.showErrorSnackBar(context, 'Please upload a clear photo');
      return;
    }

    if (_missingDateTime == null) {
      AppHelpers.showErrorSnackBar(context, 'Please select missing date/time');
      return;
    }

    if (_gender == null || _gender!.isEmpty) {
      AppHelpers.showErrorSnackBar(context, 'Please select a gender');
      return;
    }

    if (_currentUser == null || _auth.currentUser == null) {
      AppHelpers.showErrorSnackBar(
        context,
        'User data not loaded. Please try again.',
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      String photoUrl = widget.existingAlert?.photoUrl ?? '';
      if (_selectedPhoto != null) {
        photoUrl = await _cloudinaryService.uploadImage(_selectedPhoto!);
      }
      final alertId = widget.existingAlert?.id ?? AppHelpers.generateUniqueId();
      final alert = MissingPersonAlertModel(
        id: alertId,
        createdBy: widget.existingAlert?.createdBy ?? _auth.currentUser!.uid,
        createdByName:
            widget.existingAlert?.createdByName ?? _currentUser!.name,
        userVillage: widget.existingAlert?.userVillage ?? _currentUser!.village,
        userMandal: widget.existingAlert?.userMandal ?? _currentUser!.mandal,
        userDistrict: widget.existingAlert?.userDistrict ?? _currentUser!.district,
        photoUrl: photoUrl,
        fullName: _fullNameController.text.trim(),
        age: int.parse(_ageController.text.trim()),
        gender: _gender ?? '',
        lastSeenLocation: _lastSeenLocationController.text.trim(),
        missingDateTime: _missingDateTime!,
        clothesDescription: _clothesController.text.trim(),
        additionalNotes: _notesController.text.trim(),
        guardianContactNumber: _digitsOnly(_guardianPhoneController.text),
        whatsappNumber: _digitsOnly(_whatsappController.text),
        status: widget.existingAlert?.status ?? 'active',
        createdAt: widget.existingAlert?.createdAt ?? DateTime.now(),
        foundAt: widget.existingAlert?.foundAt,
        disasterId: _disasterId,
      );

      if (_isEditMode) {
        await _alertService.updateAlert(alert);
      } else {
        await _alertService.createAlert(alert);
      }

      if (mounted) {
        AppHelpers.showSuccessSnackBar(
          context,
          _isEditMode
              ? 'Missing person alert updated'
              : 'Missing person alert created',
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        AppHelpers.showErrorSnackBar(
          context,
          'Failed to create alert: ${_cleanError(e)}',
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  String? _validateAge(String? value) {
    final text = value?.trim() ?? '';
    final age = int.tryParse(text);
    if (age == null || age < 0 || age > 120) {
      return 'Enter a valid age';
    }
    return null;
  }

  String? _validatePhone(String? value) {
    final digits = _digitsOnly(value ?? '');
    if (digits.length != 10) {
      return 'Enter a valid 10-digit number';
    }
    return null;
  }

  String _digitsOnly(String value) => value.replaceAll(RegExp(r'[^\d]'), '');

  String _cleanError(Object error) {
    return error.toString().replaceFirst('Exception: ', '');
  }

  @override
  Widget build(BuildContext context) {
    const alertRed = Color(0xFFD32F2F);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: alertRed),
          onPressed: _isSaving ? null : () => Navigator.pop(context),
        ),
        title: Text(
          _isEditMode ? 'Edit Missing Alert' : 'Create Missing Alert',
          style: TextStyle(color: alertRed, fontWeight: FontWeight.bold),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(),
                const SizedBox(height: 20),
                _buildPhotoPicker(),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _fullNameController,
                  decoration: const InputDecoration(
                    labelText: 'Full name',
                    prefixIcon: Icon(Icons.person),
                  ),
                  textCapitalization: TextCapitalization.words,
                  validator: (value) =>
                      AppHelpers.validateRequired(value, 'Full name'),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _ageController,
                        decoration: const InputDecoration(
                          labelText: 'Age',
                          prefixIcon: Icon(Icons.cake),
                        ),
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        validator: _validateAge,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _gender,
                        decoration: const InputDecoration(
                          labelText: 'Gender',
                          prefixIcon: Icon(Icons.wc),
                        ),
                        items: _genderOptions
                            .map(
                              (gender) => DropdownMenuItem(
                                value: gender,
                                child: Text(gender),
                              ),
                            )
                            .toList(),
                        onChanged: _isSaving
                            ? null
                            : (value) => setState(() => _gender = value),
                        validator: (value) =>
                            value == null ? 'Select gender' : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _lastSeenLocationController,
                  decoration: const InputDecoration(
                    labelText: 'Last seen location',
                    prefixIcon: Icon(Icons.location_on),
                  ),
                  textCapitalization: TextCapitalization.sentences,
                  validator: (value) =>
                      AppHelpers.validateRequired(value, 'Last seen location'),
                ),
                const SizedBox(height: 16),
                _buildDateTimeField(),
                const SizedBox(height: 16),
                _buildDisasterLinkField(),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _clothesController,
                  decoration: const InputDecoration(
                    labelText: 'Clothes description',
                    prefixIcon: Icon(Icons.checkroom),
                    alignLabelWithHint: true,
                  ),
                  maxLines: 3,
                  textCapitalization: TextCapitalization.sentences,
                  validator: (value) =>
                      AppHelpers.validateRequired(value, 'Clothes description'),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _notesController,
                  decoration: const InputDecoration(
                    labelText: 'Additional notes',
                    prefixIcon: Icon(Icons.notes),
                    alignLabelWithHint: true,
                  ),
                  maxLines: 3,
                  textCapitalization: TextCapitalization.sentences,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _guardianPhoneController,
                  decoration: const InputDecoration(
                    labelText: 'Guardian/family contact number',
                    prefixIcon: Icon(Icons.call),
                  ),
                  keyboardType: TextInputType.phone,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  validator: _validatePhone,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _whatsappController,
                  decoration: const InputDecoration(
                    labelText: 'WhatsApp number',
                    prefixIcon: Icon(Icons.chat),
                  ),
                  keyboardType: TextInputType.phone,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  validator: _validatePhone,
                ),
                const SizedBox(height: 28),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _isSaving ? null : _submitAlert,
                    icon: _isSaving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.warning_amber),
                    label: Text(
                      _isSaving ? 'Creating Alert...' : 'Create Alert',
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: alertRed,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF3CD),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFFC107)),
      ),
      child: const Row(
        children: [
          Icon(Icons.priority_high, color: Color(0xFFD32F2F)),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'Use clear, accurate details so nearby villagers can respond quickly.',
              style: TextStyle(
                color: Color(0xFF6D4C00),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPhotoPicker() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Photo upload',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          if (_selectedPhoto != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.file(
                _selectedPhoto!,
                width: double.infinity,
                height: 220,
                fit: BoxFit.cover,
              ),
            )
          else
            Container(
              width: double.infinity,
              height: 180,
              decoration: BoxDecoration(
                color: const Color(0xFFFFEBEE),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE57373)),
              ),
              child: const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_a_photo, color: Color(0xFFD32F2F), size: 42),
                  SizedBox(height: 8),
                  Text('Add a clear recent photo'),
                ],
              ),
            ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _isSaving ? null : _pickPhotoFromGallery,
                  icon: const Icon(Icons.photo_library),
                  label: const Text('Gallery'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _isSaving ? null : _pickPhotoFromCamera,
                  icon: const Icon(Icons.photo_camera),
                  label: const Text('Camera'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDateTimeField() {
    final text = _missingDateTime == null
        ? 'Select missing date/time'
        : AppHelpers.formatDateTime(_missingDateTime);

    return InkWell(
      onTap: _isSaving ? null : _selectMissingDateTime,
      borderRadius: BorderRadius.circular(14),
      child: InputDecorator(
        decoration: const InputDecoration(
          labelText: 'Missing date/time',
          prefixIcon: Icon(Icons.schedule),
        ),
        child: Text(
          text,
          style: TextStyle(
            color: _missingDateTime == null
                ? Colors.grey.shade600
                : Colors.black87,
          ),
        ),
      ),
    );
  }

  /// Phase 5: optional association with an active disaster so responders
  /// can see the disaster context. Manual choice — never automatic — and
  /// existing non-disaster alerts are unaffected.
  Widget _buildDisasterLinkField() {
    final service = DisasterService();
    return StreamBuilder<List<DisasterEventModel>>(
      stream: service.getActiveDisastersStream(),
      builder: (context, snapshot) {
        // Until the active-disaster list arrives we cannot know whether
        // `_disasterId` is one of the offered items. Passing a `value` that is
        // absent from `items` trips Flutter's
        // "There should be exactly one item with DropdownButton's value"
        // assertion, so hold the value back until the list has loaded.
        final isLoading = snapshot.connectionState == ConnectionState.waiting;
        final events = (snapshot.data ?? const <DisasterEventModel>[])
            .where((e) => e.isActive)
            .toList();

        final items = <DropdownMenuItem<String>>[
          const DropdownMenuItem(
              value: null, child: Text('— Not disaster related —')),
          for (final e in events)
            DropdownMenuItem(
              value: e.id,
              child: Text(
                '${DisasterEventModel.typeLabel(e.type)} — ${e.title}',
                overflow: TextOverflow.ellipsis,
              ),
            ),
        ];

        final selected = isLoading ? null : _disasterId;
        // If the linked disaster is no longer active/available, keep the saved
        // id as a visible placeholder instead of silently dropping it.
        final hasSelected = selected != null &&
            items.any((i) => i.value == selected);
        if (selected != null && !hasSelected) {
          items.add(DropdownMenuItem(
            value: selected,
            child: Text('Linked disaster (no longer active)',
                overflow: TextOverflow.ellipsis),
          ));
        }

        if (snapshot.hasError) {
          // Targeting list unavailable — keep the existing linkage editable
          // without pretending the list loaded successfully.
          items.removeWhere((i) => i.value != null);
        }

        return DropdownButtonFormField<String>(
          // `selected` is guaranteed to be present in `items` by the
          // placeholder entry added above, so the assertion cannot trip.
          value: selected,
          decoration: InputDecoration(
            labelText: 'Linked disaster (optional)',
            prefixIcon: const Icon(Icons.warning_amber_rounded),
            helperText: snapshot.hasError
                ? 'Active disasters could not be loaded'
                : null,
          ),
          items: items,
          onChanged: _isSaving || snapshot.hasError
              ? null
              : (v) => setState(() => _disasterId = v),
        );
      },
    );
  }
}
