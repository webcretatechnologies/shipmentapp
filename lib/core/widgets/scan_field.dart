import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

/// Barcode input: a text field (works with USB/Bluetooth ring scanners that
/// "type" the code + Enter) plus a camera-scan button. Calls [onSubmit] with
/// the raw code. Keeps focus so rapid scanning is fast.
class ScanField extends StatefulWidget {
  const ScanField({
    super.key,
    required this.onSubmit,
    this.hint = 'Scan or enter barcode',
    this.enabled = true,
  });

  final void Function(String code) onSubmit;
  final String hint;
  final bool enabled;

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
            inputFormatters: [FilteringTextInputFormatter.deny(RegExp(r'\n'))],
            decoration: InputDecoration(
              hintText: widget.hint,
              prefixIcon: const Icon(Icons.qr_code_scanner),
            ),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          height: 52,
          child: FilledButton(
            onPressed: widget.enabled ? _openCamera : null,
            child: const Icon(Icons.photo_camera),
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
      appBar: AppBar(title: const Text('Scan barcode')),
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
