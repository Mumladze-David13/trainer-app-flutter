import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/models/models.dart';
import '../../../core/services/auth_provider.dart';

class AddressSearchField extends StatefulWidget {
  final Address? initialValue;
  final ValueChanged<Address> onSelected;
  final VoidCallback? onClear;

  const AddressSearchField({
    super.key,
    this.initialValue,
    required this.onSelected,
    this.onClear,
  });

  @override
  State<AddressSearchField> createState() => _AddressSearchFieldState();
}

class _AddressSearchFieldState extends State<AddressSearchField> {
  final _textCtrl = TextEditingController();
  final _focusNode = FocusNode();
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    if (widget.initialValue != null) {
      _textCtrl.text = widget.initialValue!.displayFull;
    }
  }

  @override
  void dispose() {
    _textCtrl.dispose();
    _focusNode.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  Future<Iterable<Map<String, dynamic>>> _fetchSuggestions(String query) {
    if (query.length < 3) return Future.value(const []);
    final completer = Completer<Iterable<Map<String, dynamic>>>();
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () async {
      try {
        final api = context.read<AuthProvider>().api;
        final results = await api.getAddressSuggestions(query);
        if (!completer.isCompleted) completer.complete(results);
      } catch (_) {
        if (!completer.isCompleted) completer.complete(const []);
      }
    });
    return completer.future;
  }

  @override
  Widget build(BuildContext context) {
    return RawAutocomplete<Map<String, dynamic>>(
      textEditingController: _textCtrl,
      focusNode: _focusNode,
      displayStringForOption: (option) => option['value'] as String? ?? '',
      optionsBuilder: (textEditingValue) =>
          _fetchSuggestions(textEditingValue.text),
      onSelected: (option) {
        final data = option['data'] as Map<String, dynamic>? ?? {};
        final address = Address(
          country: data['country'],
          region: data['region_with_type'],
          city: data['city'] ?? data['settlement'],
          street: data['street_with_type'],
          building: data['house'],
          unit: data['flat'] ?? data['block'],
        );
        widget.onSelected(address);
      },
      fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
        return TextField(
          controller: controller,
          focusNode: focusNode,
          decoration: InputDecoration(
            labelText: 'Адрес',
            border: const OutlineInputBorder(),
            suffixIcon: controller.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      controller.clear();
                      widget.onClear?.call();
                    },
                  )
                : null,
          ),
        );
      },
      optionsViewBuilder: (context, onSelected, options) {
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 4,
            borderRadius: BorderRadius.circular(4),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 200),
              child: ListView.separated(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                itemCount: options.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, i) {
                  final option = options.elementAt(i);
                  return ListTile(
                    dense: true,
                    leading: const Icon(Icons.location_on, size: 18),
                    title: Text(
                      option['value'] as String? ?? '',
                      style: const TextStyle(fontSize: 13),
                    ),
                    onTap: () => onSelected(option),
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
