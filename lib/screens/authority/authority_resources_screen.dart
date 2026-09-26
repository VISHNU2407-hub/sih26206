import 'package:flutter/material.dart';

import '../../models/resource_model.dart';
import '../../models/user_model.dart';
import '../../services/resource_service.dart';
import '../../theme/app_theme.dart';

/// SATS Disaster — Phase 5: authority relief/resource management.
///
/// Add resource requirements per village, update available / required /
/// allocated quantities and status. Realtime Firestore stream; validation
/// lives in [ResourceModel.validate].
class AuthorityResourcesScreen extends StatefulWidget {
  final UserModel user;

  const AuthorityResourcesScreen({super.key, required this.user});

  @override
  State<AuthorityResourcesScreen> createState() =>
      _AuthorityResourcesScreenState();
}

class _AuthorityResourcesScreenState extends State<AuthorityResourcesScreen> {
  final ResourceService _service = ResourceService();

  @override
  Widget build(BuildContext context) {
    final isDistrictLevel = widget.user.district.isNotEmpty &&
        (widget.user.role == 'district_authority' ||
            widget.user.role == 'admin');

    final stream = isDistrictLevel
        ? _service.getResourcesForDistrictStream(widget.user.district)
        : _service.getResourcesForMandalStream(widget.user.mandal);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Relief Resources',
          style: TextStyle(
            color: AppColors.primary,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showResourceEditor(context),
        icon: const Icon(Icons.add_box),
        label: const Text('Add Requirement'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: StreamBuilder<List<ResourceModel>>(
          stream: stream,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(child: Text('Error: ${snapshot.error}'));
            }
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final items =
                ResourceService.sortForAuthorityList(snapshot.data!);
            if (items.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.inventory_2_outlined,
                        size: 64, color: Colors.grey[400]),
                    const SizedBox(height: 12),
                    const Text(
                      'No resource requirements yet',
                      style: TextStyle(fontSize: 14, color: Colors.grey),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Add requirements with the button below',
                      style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                    ),
                  ],
                ),
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
              itemCount: items.length,
              itemBuilder: (context, index) {
                final item = items[index];
                return _ResourceCard(
                  item: item,
                  onTap: () => _showResourceEditor(context, existing: item),
                );
              },
            );
          },
        ),
      ),
    );
  }

  Future<void> _showResourceEditor(
    BuildContext context, {
    ResourceModel? existing,
  }) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _ResourceEditorSheet(
        user: widget.user,
        existing: existing,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
//  Resource card
// ─────────────────────────────────────────────────────────────────────────

class _ResourceCard extends StatelessWidget {
  final ResourceModel item;
  final VoidCallback onTap;

  const _ResourceCard({required this.item, required this.onTap});

  Color get _statusColor {
    if (item.isExhausted) return AppColors.danger;
    if (item.shortfall > 0) return AppColors.danger;
    if (item.isCovered) return AppColors.success;
    return AppColors.warning;
  }

  @override
  Widget build(BuildContext context) {
    final coverage = item.coverage;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          ResourceModel.resourceLabel(item.resourceType),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14.5,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: _statusColor.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(6),
                          border:
                              Border.all(color: _statusColor.withOpacity(0.5)),
                        ),
                        child: Text(
                          ResourceModel.statusLabel(item.status),
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.bold,
                            color: _statusColor,
                          ),
                        ),
                      ),
                      if (item.isDemoData) ...[
                        const SizedBox(width: 6),
                        const Text(
                          'DEMO',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: AppColors.warning,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.village,
                    style: TextStyle(fontSize: 12.5, color: Colors.grey[700]),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: coverage ?? 0,
                                minHeight: 6,
                                backgroundColor: Colors.grey.shade200,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  _statusColor,
                                ),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${item.quantity} of ${item.requiredQuantity} ${item.unit} available',
                              style: TextStyle(
                                  fontSize: 11.5, color: Colors.grey[700]),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            item.shortfall > 0
                                ? 'Short ${item.shortfall}'
                                : 'Covered',
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.bold,
                              color: _statusColor,
                            ),
                          ),
                          Text(
                            'Allocated: ${item.allocatedQuantity}',
                            style: TextStyle(
                                fontSize: 11, color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
//  Editor sheet
// ─────────────────────────────────────────────────────────────────────────

class _ResourceEditorSheet extends StatefulWidget {
  final UserModel user;
  final ResourceModel? existing;

  const _ResourceEditorSheet({required this.user, this.existing});

  @override
  State<_ResourceEditorSheet> createState() => _ResourceEditorSheetState();
}

class _ResourceEditorSheetState extends State<_ResourceEditorSheet> {
  final ResourceService _service = ResourceService();
  final _formKey = GlobalKey<FormState>();
  final _villageController = TextEditingController();
  final _notesController = TextEditingController();
  final _quantityController = TextEditingController();
  final _requiredController = TextEditingController();
  final _allocatedController = TextEditingController();

  String _resourceType = 'drinking_water';
  String _status = ResourceModel.statusNeeded;
  String _unit = 'units';
  bool _saving = false;

  static const List<String> _resourceTypes = [
    'drinking_water',
    'food_packets',
    'medicines',
    'blankets',
    'emergency_kits',
    'boats',
    'generators',
    'rescue_equipment',
    'tarpaulins',
    'cooked_food',
  ];

  static const Map<String, String> _unitDefaults = {
    'drinking_water': 'litres',
    'food_packets': 'packets',
    'medicines': 'packets',
    'blankets': 'units',
    'emergency_kits': 'kits',
    'boats': 'units',
    'generators': 'units',
    'rescue_equipment': 'sets',
    'tarpaulins': 'units',
    'cooked_food': 'meals',
  };

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _resourceType = e.resourceType;
      _status = e.status;
      _unit = e.unit;
      _villageController.text = e.village;
      _notesController.text = e.notes;
      _quantityController.text = '${e.quantity}';
      _requiredController.text = '${e.requiredQuantity}';
      _allocatedController.text = '${e.allocatedQuantity}';
    } else {
      _villageController.text = widget.user.village;
    }
  }

  @override
  void dispose() {
    _villageController.dispose();
    _notesController.dispose();
    _quantityController.dispose();
    _requiredController.dispose();
    _allocatedController.dispose();
    super.dispose();
  }

  int get _quantity => int.tryParse(_quantityController.text.trim()) ?? 0;
  int get _required => int.tryParse(_requiredController.text.trim()) ?? 0;
  int get _allocated =>
      int.tryParse(_allocatedController.text.trim()) ?? 0;

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final error = ResourceModel.validate(
      quantity: _quantity,
      requiredQuantity: _required,
      allocatedQuantity: _allocated,
      resourceType: _resourceType,
      village: _villageController.text,
    );
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error)),
      );
      return;
    }

    setState(() => _saving = true);

    try {
      final now = DateTime.now();
      if (_isEdit) {
        final updated = widget.existing!.copyWith(
          quantity: _quantity,
          requiredQuantity: _required,
          allocatedQuantity: _allocated,
          status: _status,
          notes: _notesController.text.trim(),
          updatedBy: widget.user.uid,
        );
        await _service.updateResource(widget.existing!.id, updated);
      } else {
        await _service.createResource(ResourceModel(
          disasterId: null,
          district: widget.user.district,
          mandal: widget.user.mandal,
          village: _villageController.text.trim(),
          resourceType: _resourceType,
          quantity: _quantity,
          requiredQuantity: _required,
          allocatedQuantity: _allocated,
          unit: _unitDefaults[_resourceType] ?? 'units',
          status: _status,
          notes: _notesController.text.trim(),
          updatedBy: widget.user.uid,
          createdAt: now,
          updatedAt: now,
        ));
      }

      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not save: $e'),
          backgroundColor: AppColors.danger,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Form(
          key: _formKey,
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.all(16),
            children: [
              Row(
                children: [
                  Text(
                    _isEdit
                        ? 'Update Resource — ${ResourceModel.resourceLabel(_resourceType)}'
                        : 'Add Resource Requirement',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Village (identity — fixed after creation)
              TextFormField(
                controller: _villageController,
                decoration: const InputDecoration(
                  labelText: 'Village *',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                enabled: !_isEdit,
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Village is required'
                    : null,
              ),
              const SizedBox(height: 12),

              // Resource type (identity — fixed after creation)
              DropdownButtonFormField<String>(
                value: _resourceType,
                decoration: const InputDecoration(
                  labelText: 'Resource type *',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                items: [
                  for (final t in _resourceTypes)
                    DropdownMenuItem(
                        value: t,
                        child: Text(ResourceModel.resourceLabel(t))),
                ],
                onChanged: _isEdit
                    ? null
                    : (v) => setState(() {
                          _resourceType = v!;
                          _unit = _unitDefaults[v] ?? 'units';
                        }),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Resource type is required'
                    : null,
              ),
              const SizedBox(height: 12),

              // Quantities
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _requiredController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Required ($_unit)',
                        border: const OutlineInputBorder(),
                        isDense: true,
                      ),
                      validator: (v) => _validateCount(v, 'Required'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextFormField(
                      controller: _quantityController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Available ($_unit)',
                        border: const OutlineInputBorder(),
                        isDense: true,
                      ),
                      validator: (v) => _validateCount(v, 'Available'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextFormField(
                      controller: _allocatedController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Allocated ($_unit)',
                        border: const OutlineInputBorder(),
                        isDense: true,
                      ),
                      validator: (v) => _validateCount(v, 'Allocated'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Status
              DropdownButtonFormField<String>(
                value: _status,
                decoration: const InputDecoration(
                  labelText: 'Status',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                items: [
                  for (final s in ResourceModel.statuses)
                    DropdownMenuItem(
                        value: s,
                        child: Text(ResourceModel.statusLabel(s))),
                ],
                onChanged: (v) => setState(() => _status = v!),
              ),
              const SizedBox(height: 12),

              // Notes
              TextFormField(
                controller: _notesController,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Notes',
                  hintText: 'Distribution point, source, contact…',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 16),

              SizedBox(
                height: 46,
                child: ElevatedButton.icon(
                  icon: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.save, size: 20),
                  label: Text(_isEdit ? 'Update Resource' : 'Add Requirement'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: _saving ? null : _save,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String? _validateCount(String? v, String label) {
    if (v == null || v.trim().isEmpty) return null;
    final n = int.tryParse(v.trim());
    if (n == null || n < 0) return 'Invalid $label quantity';
    return null;
  }
}
