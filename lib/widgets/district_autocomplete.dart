import 'package:flutter/material.dart';
import '../../services/mandal_data_service.dart';

class DistrictAutocomplete extends StatefulWidget {
  final TextEditingController controller;
  final String? labelText;
  final String? hintText;
  final IconData? prefixIcon;
  final String? Function(String?)? validator;
  final TextInputAction? textInputAction;
  final bool enabled;
  final Function(String)? onSelected;

  const DistrictAutocomplete({
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
  State<DistrictAutocomplete> createState() => _DistrictAutocompleteState();
}

class _DistrictAutocompleteState extends State<DistrictAutocomplete> {
  List<String> _allDistricts = [];
  List<String> _filteredDistricts = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadDistricts();
  }

  Future<void> _loadDistricts() async {
    try {
      final districts = await MandalDataService.loadDistricts();
      if (mounted) {
        setState(() {
          _allDistricts = districts;
          _filteredDistricts = districts;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to load districts';
          _isLoading = false;
        });
      }
    }
  }

  void _filterDistricts(String query) {
    setState(() {
      _filteredDistricts =
          MandalDataService.filterDistricts(query, _allDistricts);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return TextFormField(
        controller: widget.controller,
        decoration: InputDecoration(
          labelText: widget.labelText ?? 'District',
          hintText: widget.hintText ?? 'Loading districts...',
          prefixIcon: widget.prefixIcon != null
              ? Icon(widget.prefixIcon)
              : const Icon(Icons.map),
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
          labelText: widget.labelText ?? 'District',
          hintText: widget.hintText ?? 'Enter district manually',
          prefixIcon: widget.prefixIcon != null
              ? Icon(widget.prefixIcon)
              : const Icon(Icons.map),
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
        _filterDistricts(textEditingValue.text);
        return _filteredDistricts;
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
                labelText: widget.labelText ?? 'District',
                hintText: widget.hintText ?? 'Search district...',
                prefixIcon: widget.prefixIcon != null
                    ? Icon(widget.prefixIcon)
                    : const Icon(Icons.map),
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
