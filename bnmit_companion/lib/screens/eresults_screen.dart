import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:bnmit_companion/providers/auth_provider.dart';
import 'package:bnmit_companion/services/eresults_service.dart';


// ─── Providers ────────────────────────────────────────────────────────────────

final eResultsServiceProvider = Provider<EResultsService>((_) => EResultsService());

final _captchaStateProvider =
    StateNotifierProvider.autoDispose<_CaptchaNotifier, _CaptchaState>(
  (ref) => _CaptchaNotifier(ref.read(eResultsServiceProvider)),
);

class _CaptchaState {
  final bool loading;
  final Uint8List? imageBytes;
  final String hiddenKey;
  final String? error;

  const _CaptchaState({
    this.loading = false,
    this.imageBytes,
    this.hiddenKey = '',
    this.error,
  });

  _CaptchaState copyWith({
    bool? loading,
    Uint8List? imageBytes,
    String? hiddenKey,
    String? error,
  }) =>
      _CaptchaState(
        loading: loading ?? this.loading,
        imageBytes: imageBytes ?? this.imageBytes,
        hiddenKey: hiddenKey ?? this.hiddenKey,
        error: error,
      );
}

class _CaptchaNotifier extends StateNotifier<_CaptchaState> {
  final EResultsService _svc;

  _CaptchaNotifier(this._svc) : super(const _CaptchaState(loading: true)) {
    load();
  }

  Future<void> load() async {
    state = const _CaptchaState(loading: true);
    try {
      final result = await _svc.loadCaptcha();
      state = _CaptchaState(
        imageBytes: result.captchaBytes,
        hiddenKey: result.hiddenKey,
      );
    } catch (e) {
      state = _CaptchaState(error: e.toString());
    }
  }

  Future<void> reload() async {
    state = state.copyWith(loading: true, error: null);
    try {
      final result = await _svc.reloadCaptcha();
      state = state.copyWith(loading: false, imageBytes: result.captchaBytes);
    } catch (e) {
      state = state.copyWith(loading: false, error: e.toString());
    }
  }
}

// ─── Screen ───────────────────────────────────────────────────────────────────

class EResultsScreen extends ConsumerStatefulWidget {
  const EResultsScreen({super.key});

  @override
  ConsumerState<EResultsScreen> createState() => _EResultsScreenState();
}

class _EResultsScreenState extends ConsumerState<EResultsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usnCtrl = TextEditingController();
  final _dobCtrl = TextEditingController();
  final _captchaCtrl = TextEditingController();

  bool _isSubmitting = false;
  String? _errorMsg;
  EResultData? _result;

  @override
  void initState() {
    super.initState();
    _prefillFromAuth();
  }

  Future<void> _prefillFromAuth() async {
    // Pre-fill USN from logged-in user
    final authState = ref.read(authStateProvider).valueOrNull;
    if (authState?.user != null) {
      _usnCtrl.text = authState!.user!.usn.toUpperCase();
    }

    // Pre-fill DOB from storage (stored as YYYY-MM-DD → convert to DD-MM-YYYY)
    final storage = ref.read(storageServiceProvider);
    final storedDob = await storage.getDob();
    if (storedDob != null && storedDob.isNotEmpty) {
      // stored format: YYYY-MM-DD
      final parts = storedDob.split('-');
      if (parts.length == 3) {
        _dobCtrl.text = '${parts[2]}-${parts[1]}-${parts[0]}'; // DD-MM-YYYY
      }
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final captchaState = ref.read(_captchaStateProvider);
    if (captchaState.hiddenKey.isEmpty) {
      setState(() => _errorMsg = 'Please wait for captcha to load.');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMsg = null;
      _result = null;
    });

    try {
      final result = await ref.read(eResultsServiceProvider).fetchResult(
            usn: _usnCtrl.text.trim(),
            dobDdMmYyyy: _dobCtrl.text.trim(),
            captchaCode: _captchaCtrl.text.trim(),
            hiddenKey: captchaState.hiddenKey,
          );
      setState(() => _result = result);
    } catch (e) {
      setState(() => _errorMsg = e.toString().replaceAll('Exception: ', ''));
      // Reload captcha on error
      ref.read(_captchaStateProvider.notifier).reload();
      _captchaCtrl.clear();
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _clearResult() {
    setState(() {
      _result = null;
      _errorMsg = null;
    });
    _captchaCtrl.clear();
    ref.read(_captchaStateProvider.notifier).reload();
  }

  @override
  void dispose() {
    _usnCtrl.dispose();
    _dobCtrl.dispose();
    _captchaCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // ── AppBar ──────────────────────────────────────────────────────────
          SliverAppBar(
            expandedHeight: 110,
            floating: false,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF1565C0), Color(0xFF0288D1)],
                  ),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white.withAlpha(38),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.emoji_events_rounded,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 12),
                        if (_result != null)
                          Expanded(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      'Exam Results',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 20,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    Text(
                                      'VTU Official Result',
                                      style: TextStyle(
                                        color: Colors.white70,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                                TextButton.icon(
                                  onPressed: _clearResult,
                                  icon: const Icon(Icons.search_rounded,
                                      color: Colors.white70, size: 18),
                                  label: const Text('New Search',
                                      style: TextStyle(
                                          color: Colors.white70, fontSize: 13)),
                                ),
                              ],
                            ),
                          )
                        else
                          const Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Exam Results',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Text(
                                'VTU Official Result via BNMIT Portal',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          // ── Content ─────────────────────────────────────────────────────────
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                if (_result == null) ...[
                  _SearchForm(
                    formKey: _formKey,
                    usnCtrl: _usnCtrl,
                    dobCtrl: _dobCtrl,
                    captchaCtrl: _captchaCtrl,
                    isSubmitting: _isSubmitting,
                    errorMsg: _errorMsg,
                    onSubmit: _submit,
                    onRefreshCaptcha: () =>
                        ref.read(_captchaStateProvider.notifier).reload(),
                  ),
                ] else ...[
                  _ResultView(data: _result!),
                ],
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Search Form Widget ────────────────────────────────────────────────────────

class _SearchForm extends ConsumerWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController usnCtrl;
  final TextEditingController dobCtrl;
  final TextEditingController captchaCtrl;
  final bool isSubmitting;
  final String? errorMsg;
  final VoidCallback onSubmit;
  final VoidCallback onRefreshCaptcha;

  const _SearchForm({
    required this.formKey,
    required this.usnCtrl,
    required this.dobCtrl,
    required this.captchaCtrl,
    required this.isSubmitting,
    required this.errorMsg,
    required this.onSubmit,
    required this.onRefreshCaptcha,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final captchaState = ref.watch(_captchaStateProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return Form(
      key: formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Info banner
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF0288D1).withAlpha(20),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                  color: const Color(0xFF0288D1).withAlpha(60)),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline_rounded,
                    color: Color(0xFF0288D1), size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Your USN and DOB are pre-filled from your login. '
                    'Enter the captcha to view your official VTU result.',
                    style: TextStyle(
                      fontSize: 12,
                      color: colorScheme.onSurface.withAlpha(180),
                    ),
                  ),
                ),
              ],
            ),
          ).animate().fadeIn(duration: 400.ms),

          const SizedBox(height: 20),

          // Card with form fields
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(20),
              border:
                  Border.all(color: colorScheme.outline.withAlpha(50)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(10),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                )
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // USN
                _FieldLabel('USN'),
                const SizedBox(height: 8),
                TextFormField(
                  controller: usnCtrl,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(
                    hintText: 'e.g., 1BG24CS413',
                    prefixIcon: Icon(Icons.badge_outlined),
                  ),
                  validator: (v) =>
                      v?.isEmpty == true ? 'Enter your USN' : null,
                ),
                const SizedBox(height: 16),

                // DOB
                _FieldLabel('Date of Birth (DD-MM-YYYY)'),
                const SizedBox(height: 8),
                TextFormField(
                  controller: dobCtrl,
                  keyboardType: TextInputType.datetime,
                  decoration: const InputDecoration(
                    hintText: 'e.g., 01-01-2006',
                    prefixIcon: Icon(Icons.calendar_today_outlined),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Enter your DOB';
                    if (!RegExp(r'^\d{2}-\d{2}-\d{4}$').hasMatch(v)) {
                      return 'Format must be DD-MM-YYYY';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),

                // Captcha section
                _FieldLabel('Security Code'),
                const SizedBox(height: 12),
                Row(
                  children: [
                    // Captcha image box
                    Expanded(
                      flex: 2,
                      child: Container(
                        height: 72,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: colorScheme.outline.withAlpha(80)),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: captchaState.loading
                              ? const Center(
                                  child: SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2),
                                  ),
                                )
                              : captchaState.imageBytes != null
                                  ? Image.memory(
                                      captchaState.imageBytes!,
                                      fit: BoxFit.contain,
                                    )
                                  : Center(
                                      child: Text(
                                        captchaState.error ?? 'Failed',
                                        style: const TextStyle(
                                            fontSize: 11, color: Colors.red),
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),

                    // Refresh button
                    InkWell(
                      onTap: captchaState.loading ? null : onRefreshCaptcha,
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        width: 48,
                        height: 72,
                        decoration: BoxDecoration(
                          color: colorScheme.primary.withAlpha(15),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: colorScheme.primary.withAlpha(60)),
                        ),
                        child: Icon(
                          Icons.refresh_rounded,
                          color: colorScheme.primary,
                          size: 22,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: captchaCtrl,
                  decoration: const InputDecoration(
                    hintText: 'Type the code shown above',
                    prefixIcon: Icon(Icons.security_rounded),
                  ),
                  validator: (v) =>
                      v?.isEmpty == true ? 'Enter the captcha code' : null,
                ),

                // Error message
                if (errorMsg != null) ...[
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: colorScheme.errorContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.error_outline,
                            color: colorScheme.error, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            errorMsg!,
                            style: TextStyle(
                              color: colorScheme.error,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 20),

                // Submit
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: isSubmitting ? null : onSubmit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1565C0),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                      elevation: 2,
                    ),
                    child: isSubmitting
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: Colors.white),
                          )
                        : const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.search_rounded, size: 20),
                              SizedBox(width: 8),
                              Text(
                                'Fetch Result',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
              ],
            ),
          ).animate(delay: 100.ms).fadeIn().slideY(begin: 0.06),

          const SizedBox(height: 12),
          Text(
            'Results are fetched from bnmit-eresults.contineo.in',
            style: TextStyle(
              fontSize: 11,
              color: colorScheme.onSurface.withAlpha(100),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ─── Result View ──────────────────────────────────────────────────────────────

class _ResultView extends StatelessWidget {
  final EResultData data;

  const _ResultView({required this.data});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final passed = data.passCount;
    final failed = data.failCount;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Summary card ────────────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF1565C0), Color(0xFF0288D1)],
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF1565C0).withAlpha(80),
                blurRadius: 20,
                offset: const Offset(0, 6),
              )
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha(40),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.school_rounded,
                        color: Colors.white, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          data.studentName.isNotEmpty
                              ? data.studentName
                              : data.usn,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          data.usn,
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (data.examName.isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(30),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    data.examName,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w500),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              Row(
                children: [
                  if (data.sgpa.isNotEmpty)
                    _StatPill(label: 'SGPA', value: data.sgpa),
                  if (data.sgpa.isNotEmpty && data.cgpa.isNotEmpty)
                    const SizedBox(width: 10),
                  if (data.cgpa.isNotEmpty)
                    _StatPill(label: 'CGPA', value: data.cgpa),
                  if (data.sgpa.isNotEmpty || data.cgpa.isNotEmpty)
                    const SizedBox(width: 10),
                  _StatPill(
                    label: 'Pass',
                    value: '$passed',
                    color: Colors.green.shade300,
                  ),
                  const SizedBox(width: 10),
                  _StatPill(
                    label: 'Fail',
                    value: '$failed',
                    color:
                        failed > 0 ? Colors.red.shade300 : Colors.white70,
                  ),
                ],
              ),
            ],
          ),
        ).animate().fadeIn(duration: 400.ms).slideY(begin: -0.05),

        const SizedBox(height: 20),

        // ── Subjects ────────────────────────────────────────────────────────
        if (data.subjects.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                children: [
                  Icon(Icons.table_rows_outlined,
                      size: 48,
                      color: colorScheme.onSurface.withAlpha(80)),
                  const SizedBox(height: 12),
                  Text(
                    'Result fetched but no subject table found.\n'
                    'Please view on the web portal for details.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: colorScheme.onSurface.withAlpha(150)),
                  ),
                ],
              ),
            ),
          )
        else ...[
          Text(
            'Subject-wise Result',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 12),
          ...data.subjects.asMap().entries.map((entry) {
            final i = entry.key;
            final s = entry.value;
            return _SubjectCard(subject: s, index: i)
                .animate(delay: Duration(milliseconds: 60 * i))
                .fadeIn()
                .slideX(begin: 0.04);
          }),
        ],
        const SizedBox(height: 24),
      ],
    );
  }
}

class _StatPill extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;

  const _StatPill({
    required this.label,
    required this.value,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(25),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withAlpha(40)),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              color: color ?? Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white60,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _SubjectCard extends StatelessWidget {
  final EResultSubject subject;
  final int index;

  const _SubjectCard({required this.subject, required this.index});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final passed = subject.isPassed;
    final passColor = passed ? const Color(0xFF2E7D32) : const Color(0xFFC62828);
    final passBg = passed
        ? const Color(0xFF2E7D32).withAlpha(18)
        : const Color(0xFFC62828).withAlpha(18);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.outline.withAlpha(40)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(8),
            blurRadius: 10,
            offset: const Offset(0, 3),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Subject header
          Row(
            children: [
              // Index badge
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: const Color(0xFF0288D1).withAlpha(20),
                  borderRadius: BorderRadius.circular(8),
                ),
                alignment: Alignment.center,
                child: Text(
                  '${index + 1}',
                  style: const TextStyle(
                    color: Color(0xFF0288D1),
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (subject.code.isNotEmpty)
                      Text(
                        subject.code,
                        style: TextStyle(
                          fontSize: 11,
                          color: colorScheme.onSurface.withAlpha(150),
                          fontWeight: FontWeight.w500,
                          letterSpacing: 0.5,
                        ),
                      ),
                    Text(
                      subject.name.isNotEmpty
                          ? subject.name
                          : subject.code,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: colorScheme.onSurface,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              // Pass/Fail badge
              if (subject.result.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: passBg,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: passColor.withAlpha(60)),
                  ),
                  child: Text(
                    passed ? 'PASS' : 'FAIL',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: passColor,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
            ],
          ),

          const SizedBox(height: 12),

          // Marks chips
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (subject.internalMarks.isNotEmpty)
                _MarkChip(
                  label: 'Internal',
                  value: subject.internalMarks,
                  color: const Color(0xFF5C6BC0),
                ),
              if (subject.externalMarks.isNotEmpty)
                _MarkChip(
                  label: 'External',
                  value: subject.externalMarks,
                  color: const Color(0xFF00838F),
                ),
              if (subject.totalMarks.isNotEmpty)
                _MarkChip(
                  label: 'Total',
                  value: subject.totalMarks +
                      (subject.maxMarks.isNotEmpty
                          ? '/${subject.maxMarks}'
                          : ''),
                  color: const Color(0xFF2E7D32),
                ),
              if (subject.grade.isNotEmpty)
                _MarkChip(
                  label: 'Grade',
                  value: subject.grade,
                  color: const Color(0xFFE65100),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MarkChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _MarkChip({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withAlpha(18),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withAlpha(60)),
      ),
      child: RichText(
        text: TextSpan(
          children: [
            TextSpan(
              text: '$label: ',
              style: TextStyle(
                  color: color.withAlpha(180),
                  fontSize: 11,
                  fontWeight: FontWeight.w500),
            ),
            TextSpan(
              text: value,
              style: TextStyle(
                  color: color,
                  fontSize: 13,
                  fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontWeight: FontWeight.w600,
        color: Theme.of(context).colorScheme.onSurface.withAlpha(180),
        fontSize: 13,
      ),
    );
  }
}
