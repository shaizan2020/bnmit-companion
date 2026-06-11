import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:bnmit_companion/providers/auth_provider.dart';
import 'package:bnmit_companion/core/constants.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usnController = TextEditingController();
  final _dayController = TextEditingController();
  final _monthController = TextEditingController();
  final _yearController = TextEditingController();
  final _digitsController = TextEditingController();
  int _selectedIdType = 1;
  String _selectedSemester = 'even';
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _usnController.dispose();
    _dayController.dispose();
    _monthController.dispose();
    _yearController.dispose();
    _digitsController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final day = _dayController.text.padLeft(2, '0');
    final month = _monthController.text.padLeft(2, '0');
    final year = _yearController.text;
    final dob = '$year-$month-$day';

    try {
      await ref.read(authStateProvider.notifier).login(
            username: _usnController.text.trim().toLowerCase(),
            dob: dob,
            idType: _selectedIdType,
            verificationDigits: _digitsController.text.trim(),
            semester: _selectedSemester,
          );

      if (mounted) {
        context.go('/dashboard');
      }
    } catch (e, stack) {
      debugPrint('LOGIN SCREEN ERROR: $e');
      debugPrint('STACK TRACE: $stack');
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceAll('Exception: ', '');
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isDark
                ? [colorScheme.surface, colorScheme.surface]
                : [
                    colorScheme.primary.withAlpha(15),
                    colorScheme.surface,
                  ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Logo
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [colorScheme.primary, colorScheme.secondary],
                        ),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: colorScheme.primary.withAlpha(64),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: const Center(
                        child: Text(
                          'B',
                          style: TextStyle(
                            fontSize: 42,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ).animate().scale(
                          begin: const Offset(0.8, 0.8),
                          duration: 500.ms,
                          curve: Curves.easeOutBack,
                        ),
                    const SizedBox(height: 16),
                    Text(
                      'BNMIT Companion',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: colorScheme.onSurface,
                      ),
                    ).animate(delay: 200.ms).fadeIn().slideY(begin: 0.2),
                    const SizedBox(height: 4),
                    Text(
                      'Sign in with your Contineo credentials',
                      style: TextStyle(
                        fontSize: 14,
                        color: colorScheme.onSurface.withAlpha(153),
                      ),
                    ).animate(delay: 300.ms).fadeIn(),
                    const SizedBox(height: 32),

                    // Login Card
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerLowest,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: colorScheme.outline.withAlpha(51),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withAlpha(10),
                            blurRadius: 20,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Semester selector
                          Text('Semester Term', style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: colorScheme.onSurface.withAlpha(180),
                            fontSize: 13,
                          )),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: InkWell(
                                  onTap: () => setState(() => _selectedSemester = 'odd'),
                                  borderRadius: BorderRadius.circular(12),
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                    decoration: BoxDecoration(
                                      color: _selectedSemester == 'odd'
                                          ? colorScheme.primary
                                          : Colors.transparent,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: _selectedSemester == 'odd'
                                            ? colorScheme.primary
                                            : colorScheme.outline.withAlpha(100),
                                      ),
                                    ),
                                    alignment: Alignment.center,
                                    child: Text(
                                      'Odd Semester',
                                      style: TextStyle(
                                        color: _selectedSemester == 'odd'
                                            ? colorScheme.onPrimary
                                            : colorScheme.onSurface,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: InkWell(
                                  onTap: () => setState(() => _selectedSemester = 'even'),
                                  borderRadius: BorderRadius.circular(12),
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                    decoration: BoxDecoration(
                                      color: _selectedSemester == 'even'
                                          ? colorScheme.primary
                                          : Colors.transparent,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: _selectedSemester == 'even'
                                            ? colorScheme.primary
                                            : colorScheme.outline.withAlpha(100),
                                      ),
                                    ),
                                    alignment: Alignment.center,
                                    child: Text(
                                      'Even Semester',
                                      style: TextStyle(
                                        color: _selectedSemester == 'even'
                                            ? colorScheme.onPrimary
                                            : colorScheme.onSurface,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),

                          // USN
                          Text('USN', style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: colorScheme.onSurface.withAlpha(180),
                            fontSize: 13,
                          )),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _usnController,
                            decoration: const InputDecoration(
                              hintText: 'e.g., 1BG24CS413',
                              prefixIcon: Icon(Icons.person_outline),
                            ),
                            textCapitalization: TextCapitalization.characters,
                            validator: (v) =>
                                v?.isEmpty == true ? 'Enter your USN' : null,
                          ),
                          const SizedBox(height: 20),

                          // DOB
                          Text('Date of Birth', style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: colorScheme.onSurface.withAlpha(180),
                            fontSize: 13,
                          )),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: _dayController,
                                  decoration: const InputDecoration(
                                    hintText: 'DD',
                                  ),
                                  keyboardType: TextInputType.number,
                                  maxLength: 2,
                                  validator: (v) =>
                                      v?.isEmpty == true ? '' : null,
                                  buildCounter: (_, {required currentLength, required isFocused, maxLength}) => null,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: TextFormField(
                                  controller: _monthController,
                                  decoration: const InputDecoration(
                                    hintText: 'MM',
                                  ),
                                  keyboardType: TextInputType.number,
                                  maxLength: 2,
                                  validator: (v) =>
                                      v?.isEmpty == true ? '' : null,
                                  buildCounter: (_, {required currentLength, required isFocused, maxLength}) => null,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                flex: 2,
                                child: TextFormField(
                                  controller: _yearController,
                                  decoration: const InputDecoration(
                                    hintText: 'YYYY',
                                  ),
                                  keyboardType: TextInputType.number,
                                  maxLength: 4,
                                  validator: (v) =>
                                      v?.isEmpty == true ? '' : null,
                                  buildCounter: (_, {required currentLength, required isFocused, maxLength}) => null,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),

                          // Verification Type
                          Text('Verification Type', style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: colorScheme.onSurface.withAlpha(180),
                            fontSize: 13,
                          )),
                          const SizedBox(height: 8),
                          DropdownButtonFormField<int>(
                            initialValue: _selectedIdType,
                            decoration: const InputDecoration(
                              prefixIcon: Icon(Icons.verified_user_outlined),
                            ),
                            items: AppConstants.verificationTypes.entries
                                .map((e) => DropdownMenuItem(
                                      value: e.key,
                                      child: Text(e.value, style: const TextStyle(fontSize: 14)),
                                    ))
                                .toList(),
                            onChanged: (v) =>
                                setState(() => _selectedIdType = v ?? 1),
                          ),
                          const SizedBox(height: 20),

                          // Last 4 digits
                          Text('Last 4 Digits', style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: colorScheme.onSurface.withAlpha(180),
                            fontSize: 13,
                          )),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _digitsController,
                            decoration: const InputDecoration(
                              hintText: '1234',
                              prefixIcon: Icon(Icons.dialpad),
                            ),
                            keyboardType: TextInputType.number,
                            maxLength: 4,
                            validator: (v) => v?.length != 4
                                ? 'Enter exactly 4 digits'
                                : null,
                            buildCounter: (_, {required currentLength, required isFocused, maxLength}) => null,
                          ),
                          const SizedBox(height: 8),

                          // Error message
                          if (_errorMessage != null) ...[
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: colorScheme.errorContainer,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.error_outline,
                                      color: colorScheme.error, size: 20),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      _errorMessage!,
                                      style: TextStyle(
                                        color: colorScheme.error,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],

                          // Login button
                          SizedBox(
                            width: double.infinity,
                            height: 52,
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _login,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: colorScheme.primary,
                                foregroundColor: colorScheme.onPrimary,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              child: _isLoading
                                  ? SizedBox(
                                      width: 24,
                                      height: 24,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.5,
                                        color: colorScheme.onPrimary,
                                      ),
                                    )
                                  : const Text(
                                      'Sign In',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ).animate(delay: 400.ms).fadeIn().slideY(begin: 0.1),

                    const SizedBox(height: 16),
                    Text(
                      'Your credentials are stored securely on your device',
                      style: TextStyle(
                        fontSize: 12,
                        color: colorScheme.onSurface.withAlpha(102),
                      ),
                      textAlign: TextAlign.center,
                    ).animate(delay: 600.ms).fadeIn(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
