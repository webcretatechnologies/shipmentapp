import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../app/flavor.dart';

/// Barcode input: a text field (works with USB/Bluetooth ring scanners that
/// "type" the code + Enter) plus a camera-scan button. Calls [onSubmit] with
/// the raw code. Keeps focus so rapid scanning is fast.
class ScanField extends StatefulWidget {
  const ScanField({
    super.key,
    required this.onSubmit,
    this.hint = 'Scan or enter barcode',
    this.enabled = true,
    this.dark = false,
  });

  final void Function(String code) onSubmit;
  final String hint;
  final bool enabled;

  /// Dark variant for placing the field on a navy header.
  final bool dark;

  @override
  State<ScanField> createState() => _ScanFieldState();
}

class _ScanFieldState extends State<ScanField> {
  final _controller = TextEditingController();
  final _focus = FocusNode();

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _submit([String? value]) {
    final code = (value ?? _controller.text).trim();
    if (code.isEmpty) return;
    widget.onSubmit(code);
    _controller.clear();
    _focus.requestFocus();
  }

  Future<void> _openCamera() async {
    final code = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const _CameraScanPage()),
    );
    if (code != null) _submit(code);
  }

  @override
  Widget build(BuildContext context) {
    const brand = Color(0xFF028894); // PWA teal
    final dark = widget.dark;
    // Dark variant now sits on the teal header → use a glassy translucent fill.
    final fill = dark ? Colors.white.withOpacity(0.14) : const Color(0xFFFFFFFF);
    final borderColor = dark ? Colors.white.withOpacity(0.22) : const Color(0xFFD7E2EA);
    final textColor = dark ? Colors.white : const Color(0xFF0F172A);
    final hintColor = dark ? Colors.white.withOpacity(0.6) : const Color(0xFF94A3B8);
    final iconColor = dark ? Colors.white : brand;
    OutlineInputBorder b(Color c, double w) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: c, width: w),
        );
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _controller,
            focusNode: _focus,
            enabled: widget.enabled,
            autofocus: true,
            textInputAction: TextInputAction.go,
            onSubmitted: _submit,
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: textColor),
            inputFormatters: [FilteringTextInputFormatter.deny(RegExp(r'\n'))],
            decoration: InputDecoration(
              hintText: widget.hint,
              hintStyle: TextStyle(color: hintColor, fontWeight: FontWeight.w500),
              filled: true,
              fillColor: fill,
              prefixIcon: Icon(Icons.qr_code_scanner, color: iconColor),
              contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
              enabledBorder: b(borderColor, dark ? 1 : 1.2),
              border: b(borderColor, dark ? 1 : 1.2),
              focusedBorder: b(brand, 1.6),
            ),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          height: 52,
          width: 52,
          child: FilledButton(
            style: FilledButton.styleFrom(
              padding: EdgeInsets.zero,
              // On the teal header (dark) use white; otherwise the teal brand.
              backgroundColor: dark ? Colors.white : brand,
              foregroundColor: dark ? brand : Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: widget.enabled ? _openCamera : null,
            child: const Icon(Icons.photo_camera, size: 22),
          ),
        ),
      ],
    );
  }
}

class _CameraScanPage extends StatefulWidget {
  const _CameraScanPage();
  @override
  State<_CameraScanPage> createState() => _CameraScanPageState();
}

class _CameraScanPageState extends State<_CameraScanPage> {
  bool _handled = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan barcode'),
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        titleTextStyle: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800),
        flexibleSpace: const DecoratedBox(
          decoration: BoxDecoration(gradient: Pwa.headerGradient),
        ),
      ),
      body: MobileScanner(
        onDetect: (capture) {
          if (_handled) return;
          final code = capture.barcodes.isNotEmpty ? capture.barcodes.first.rawValue : null;
          if (code != null && code.isNotEmpty) {
            _handled = true;
            Navigator.of(context).pop(code);
          }
        },
      ),
    );
  }
}
