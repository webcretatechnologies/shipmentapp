import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/flavor.dart';
import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';
import '../../core/auth/auth_controller.dart';

/// Login with two tabs: "Login with Plantex" (warehouse) and
/// "Login with Vendor" (supplier). The selected tab decides the role.
/// The logo + app name come from the admin panel settings (GET /app-config),
/// falling back to the bundled Plantex logo if the call fails.
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

  String? _logoUrl; // resolved from admin settings
  String _appName = 'Plantex';

  AppRole get _loginType => _tab.index == 1 ? AppRole.supplier : AppRole.plantex;

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  Future<void> _loadConfig() async {
    try {
      final data = await context.read<ApiClient>().get(ApiEndpoints.appConfig);
      if (data is Map && mounted) {
        setState(() {
          final url = data['logo_url']?.toString();
          _logoUrl = (url != null && url.isNotEmpty) ? url : null;
          final name = data['app_name']?.toString();
          if (name != null && name.isNotEmpty) _appName = name;
        });
      }
    } catch (_) {
      // keep bundled logo + default name
    }
  }

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
      backgroundColor: Pwa.bg,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _Logo(logoUrl: _logoUrl),
                  const SizedBox(height: 26),
                  // ── login card ──
                  Container(
                    padding: const EdgeInsets.fromLTRB(22, 26, 22, 26),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: Pwa.border),
                      boxShadow: const [
                        BoxShadow(color: Color(0x14026E78), blurRadius: 24, offset: Offset(0, 10)),
                      ],
                    ),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'Login here',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.w800,
                              color: kBrandAccent,
                            ),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Welcome back you’ve been missed!',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Pwa.text,
                            ),
                          ),
                          const SizedBox(height: 22),

                          // ── role tabs ──
                          Container(
                            decoration: BoxDecoration(
                              color: Pwa.bg,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: TabBar(
                              controller: _tab,
                              indicator: BoxDecoration(
                                color: kBrandAccent,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              indicatorSize: TabBarIndicatorSize.tab,
                              dividerColor: Colors.transparent,
                              labelColor: Colors.white,
                              unselectedLabelColor: Pwa.muted,
                              labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                              tabs: const [
                                Tab(text: 'Plantex'),
                                Tab(text: 'Vendor'),
                              ],
                            ),
                          ),
                          const SizedBox(height: 18),

                          TextFormField(
                            controller: _email,
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.next,
                            decoration: const InputDecoration(
                              hintText: 'Email',
                              prefixIcon: Icon(Icons.email_outlined),
                            ),
                            validator: (v) =>
                                (v == null || !v.contains('@')) ? 'Enter a valid email' : null,
                          ),
                          const SizedBox(height: 14),
                          TextFormField(
                            controller: _password,
                            obscureText: _obscure,
                            textInputAction: TextInputAction.done,
                            onFieldSubmitted: (_) => _submit(),
                            decoration: InputDecoration(
                              hintText: 'Password',
                              prefixIcon: const Icon(Icons.lock_outline),
                              suffixIcon: IconButton(
                                icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility),
                                onPressed: () => setState(() => _obscure = !_obscure),
                              ),
                            ),
                            validator: (v) => (v == null || v.isEmpty) ? 'Enter your password' : null,
                          ),
                          const SizedBox(height: 26),
                          FilledButton(
                            onPressed: auth.busy ? null : _submit,
                            child: auth.busy
                                ? const SizedBox(
                                    height: 22,
                                    width: 22,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2, color: Colors.white))
                                : Text(isVendor ? 'Sign in as Vendor' : 'Sign in'),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    isVendor ? 'Vendor / Supplier portal' : 'Warehouse staff portal',
                    style: const TextStyle(color: Pwa.muted, fontSize: 12),
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

/// App logo — admin-configured (network) with the bundled Plantex logo as a
/// fallback while loading or on error.
class _Logo extends StatelessWidget {
  const _Logo({this.logoUrl});
  final String? logoUrl;

  static const _asset = AssetImage('assets/images/plantex_logo.jpeg');

  @override
  Widget build(BuildContext context) {
    final fallback = Image(image: _asset, height: 56, fit: BoxFit.contain);
    final logo = (logoUrl == null)
        ? fallback
        : Image.network(
            logoUrl!,
            height: 56,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => fallback,
            loadingBuilder: (_, child, progress) =>
                progress == null ? child : fallback,
          );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: logo,
    );
  }
}
