import 'package:flutter/material.dart';
import '../../services/mandal_data_service.dart';

class MandalAutocomplete extends StatefulWidget {
  final TextEditingController controller;
  final String? labelText;
  final String? hintText;
  final IconData? prefixIcon;
  final String? Function(String?)? validator;
  final TextInputAction? textInputAction;
  final bool enabled;
  final Function(String)? onSelected;

  const MandalAutocomplete({
    super.key,
    required this.controller,
    this.labelText,
    this.hintText,
    this.prefixIcon,
    this.validator,
    this.textInputAction,
    this.enabled = true,
    this.onSelected,
  });

  @override
  State<MandalAutocomplete> createState() => _MandalAutocompleteState();
}

class _MandalAutocompleteState extends State<MandalAutocomplete> {
  List<String> _allMandals = [];
  List<String> _filteredMandals = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadMandals();
  }

  Future<void> _loadMandals() async {
    try {
      final mandals = await MandalDataService.loadMandals();
      if (mounted) {
        setState(() {
          _allMandals = mandals;
          _filteredMandals = mandals;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to load mandals';
          _isLoading = false;
        });
      }
    }
  }

  void _filterMandals(String query) {
    setState(() {
      _filteredMandals = MandalDataService.filterMandals(query, _allMandals);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return TextFormField(
        controller: widget.controller,
        decoration: InputDecoration(
          labelText: widget.labelText ?? 'Mandal',
          hintText: widget.hintText ?? 'Loading mandals...',
          prefixIcon: widget.prefixIcon != null
              ? Icon(widget.prefixIcon)
              : const Icon(Icons.location_city),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          suffixIcon: const Padding(
            padding: EdgeInsets.all(12.0),
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        ),
        enabled: false,
        validator: widget.validator,
      );
    }

    if (_errorMessage != null) {
      return TextFormField(
        controller: widget.controller,
        decoration: InputDecoration(
          labelText: widget.labelText ?? 'Mandal',
          hintText: widget.hintText ?? 'Enter mandal manually',
          prefixIcon: widget.prefixIcon != null
              ? Icon(widget.prefixIcon)
              : const Icon(Icons.location_city),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          errorText: _errorMessage,
        ),
        enabled: widget.enabled,
        validator: widget.validator,
        textInputAction: widget.textInputAction,
      );
    }

    return Autocomplete<String>(
      optionsBuilder: (TextEditingValue textEditingValue) {
        _filterMandals(textEditingValue.text);
        return _filteredMandals;
      },
      initialValue: TextEditingValue(text: widget.controller.text),
      onSelected: (String selection) {
        widget.controller.text = selection;
        widget.onSelected?.call(selection);
      },
      fieldViewBuilder:
          (
            BuildContext context,
            TextEditingController textEditingController,
            FocusNode focusNode,
            VoidCallback onFieldSubmitted,
          ) {
            return TextFormField(
              controller: textEditingController,
              focusNode: focusNode,
              decoration: InputDecoration(
                labelText: widget.labelText ?? 'Mandal',
                hintText: widget.hintText ?? 'Search mandal...',
                prefixIcon: widget.prefixIcon != null
                    ? Icon(widget.prefixIcon)
                    : const Icon(Icons.location_city),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                suffixIcon: textEditingController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          textEditingController.clear();
                          widget.controller.clear();
                        },
                      )
                    : null,
              ),
              enabled: widget.enabled,
              validator: widget.validator,
              textInputAction: widget.textInputAction,
              onChanged: (value) {
                widget.controller.text = value;
              },
            );
          },
      optionsViewBuilder:
          (
            BuildContext context,
            AutocompleteOnSelected<String> onSelected,
            Iterable<String> options,
          ) {
            return Align(
              alignment: Alignment.topLeft,
              child: Material(
                elevation: 4,
                borderRadius: BorderRadius.circular(12),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 200),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: options.length,
                    itemBuilder: (BuildContext context, int index) {
                      final String option = options.elementAt(index);
                      return ListTile(
                        dense: true,
                        title: Text(
                          option,
                          style: const TextStyle(fontSize: 14),
                        ),
                        onTap: () {
                          onSelected(option);
                        },
                      );
                    },
                  ),
                ),
              ),
            );
          },
    );
  }
}
