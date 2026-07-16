import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/flavor.dart';
import '../../core/auth/auth_controller.dart';

/// Login: a dark navy branding header (logo tile + Plantex + tagline) over a
/// white sheet with Plantex / Vendor tabs and the email + password form.
/// The selected tab decides the role.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with SingleTickerProviderStateMixin {
  late final TabController _tab = TabController(length: 2, vsync: this)
    ..addListener(() => setState(() {}));
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _obscure = true;

  AppRole get _loginType => _tab.index == 1 ? AppRole.supplier : AppRole.plantex;

  @override
  void dispose() {
    _tab.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final auth = context.read<AuthController>();
    final ok = await auth.login(
      email: _email.text,
      password: _password.text,
      loginType: _loginType,
    );
    if (!ok && mounted && auth.errorMessage != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(auth.errorMessage!), backgroundColor: Colors.red.shade600),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final isVendor = _loginType == AppRole.supplier;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          _brandHeader(),
          Expanded(
            child: Transform.translate(
              offset: const Offset(0, -22),
              child: Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(22, 26, 22, 28),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _tabs(),
                        const SizedBox(height: 18),
                        Center(
                          child: Text(
                            isVendor ? 'Vendor / Supplier sign-in' : 'Warehouse staff sign-in',
                            style: const TextStyle(
                                color: Pwa.muted, fontSize: 13, fontWeight: FontWeight.w600),
                          ),
                        ),
                        const SizedBox(height: 22),
                        const _FieldLabel('Email Address'),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _email,
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                          decoration: _dec(
                            hint: 'staff@plantex.work',
                            prefix: const Icon(Icons.mail_outline_rounded, color: Pwa.muted, size: 20),
                          ),
                          validator: (v) =>
                              (v == null || !v.contains('@')) ? 'Enter a valid email' : null,
                        ),
                        const SizedBox(height: 18),
                        const _FieldLabel('Password'),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _password,
                          obscureText: _obscure,
                          textInputAction: TextInputAction.done,
                          onFieldSubmitted: (_) => _submit(),
                          decoration: _dec(
                            hint: '••••••••',
                            prefix: const Icon(Icons.lock_outline_rounded, color: Pwa.muted, size: 20),
                            suffix: IconButton(
                              icon: Icon(_obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                                  color: Pwa.muted),
                              onPressed: () => setState(() => _obscure = !_obscure),
                            ),
                          ),
                          validator: (v) => (v == null || v.isEmpty) ? 'Enter your password' : null,
                        ),
                        const SizedBox(height: 10),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Please contact your administrator to reset your password.')),
                              );
                            },
                            style: TextButton.styleFrom(
                              foregroundColor: kBrandAccent,
                              padding: EdgeInsets.zero,
                              minimumSize: const Size(0, 0),
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: const Text('Forgot password?', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                          ),
                        ),
                        const SizedBox(height: 18),
                        Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(color: kBrandAccent.withOpacity(0.35), blurRadius: 20, offset: const Offset(0, 8)),
                            ],
                          ),
                          child: FilledButton(
                            onPressed: auth.busy ? null : _submit,
                            child: auth.busy
                                ? const SizedBox(
                                    height: 22,
                                    width: 22,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                : Text(isVendor ? 'Sign in as Vendor' : 'Sign in'),
                          ),
                        ),
                        const SizedBox(height: 14),
                        Center(
                          child: Text(
                            isVendor ? 'Vendor / Supplier portal' : 'Warehouse staff portal',
                            style: const TextStyle(
                                color: Pwa.muted, fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Dark navy branding header ──
  Widget _brandHeader() {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(gradient: Pwa.headerGradient),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 30, 24, 34),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 86,
                height: 86,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: kBrandAccent,
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: [
                    BoxShadow(color: kBrandAccent.withOpacity(0.45), blurRadius: 28, spreadRadius: 1),
                  ],
                ),
                child: const Icon(Icons.local_shipping_rounded, color: Colors.white, size: 44),
              ),
              const SizedBox(height: 18),
              const Text('Plantex',
                  style: TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w800)),
              const SizedBox(height: 5),
              Text('SHIPMENT MANAGEMENT',
                  style: TextStyle(
                      color: Colors.white.withOpacity(0.55),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 3)),
            ],
          ),
        ),
      ),
    );
  }

  // ── Plantex / Vendor segmented tabs ──
  Widget _tabs() {
    return Container(
      height: 50,
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: Pwa.bg,
        borderRadius: BorderRadius.circular(14),
      ),
      child: TabBar(
        controller: _tab,
        indicator: BoxDecoration(
          color: kBrandAccent,
          borderRadius: BorderRadius.circular(10),
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        labelColor: Colors.white,
        unselectedLabelColor: Pwa.muted,
        labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
        unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
        tabs: const [
          Tab(text: 'Plantex Login'),
          Tab(text: 'Vendor Login'),
        ],
      ),
    );
  }

  InputDecoration _dec({required String hint, Widget? prefix, Widget? suffix}) => InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontWeight: FontWeight.w500),
        prefixIcon: prefix,
        suffixIcon: suffix,
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: kBrandAccent, width: 1.6),
        ),
      );
}

/// Small uppercase field label ("EMAIL ADDRESS", "PASSWORD").
class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: const TextStyle(
        color: Pwa.muted,
        fontSize: 11.5,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.8,
      ),
    );
  }
}
