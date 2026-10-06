import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../viewmodels/forgot_password_viewmodel.dart';
import '../widgets/custom_text_field.dart';

class ForgotPasswordView extends StatefulWidget {
  const ForgotPasswordView({super.key});

  @override
  State<ForgotPasswordView> createState() => _ForgotPasswordViewState();
}

class _ForgotPasswordViewState extends State<ForgotPasswordView> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _otpController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _otpController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _handleSendOtp() async {
    if (!_formKey.currentState!.validate()) return;

    final vm = context.read<ForgotPasswordViewModel>();
    final success = await vm.sendOtp(email: _emailController.text.trim());

    if (success) {
      _otpController.clear();
    }
  }

  void _handleVerifyOtp() async {
    if (!_formKey.currentState!.validate()) return;

    final vm = context.read<ForgotPasswordViewModel>();
    final success = await vm.verifyOtp(otp: _otpController.text.trim());

    if (success) {
      _passwordController.clear();
      _confirmPasswordController.clear();
    }
  }

  void _handleResetPassword() async {
    if (!_formKey.currentState!.validate()) return;

    final vm = context.read<ForgotPasswordViewModel>();
    final success = await vm.resetPassword(
      newPassword: _passwordController.text,
    );

    if (success && mounted) {
      // Tampilkan dialog sukses
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          icon: const Icon(
            Icons.check_circle,
            color: Colors.green,
            size: 64,
          ),
          title: const Text('Berhasil!'),
          content: const Text('Password berhasil direset. Silakan login dengan password baru Anda.'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                Navigator.of(context).pop(); // Kembali ke login
              },
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reset Password'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Consumer<ForgotPasswordViewModel>(
              builder: (context, vm, child) {
                return Form(
                  key: _formKey,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Icon berdasarkan step
                      Icon(
                        _getStepIcon(vm.currentStep),
                        size: 80,
                        color: Colors.deepPurple,
                      ),
                      const SizedBox(height: 16),

                      // Title berdasarkan step
                      Text(
                        _getStepTitle(vm.currentStep),
                        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _getStepSubtitle(vm.currentStep),
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: Colors.grey[600],
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 32),

                      // Step indicator
                      _StepIndicator(currentStep: vm.currentStep),
                      const SizedBox(height: 32),

                      // Content berdasarkan step
                      if (vm.currentStep == ForgotPasswordStep.email)
                        _buildEmailStep(vm),
                      if (vm.currentStep == ForgotPasswordStep.otp)
                        _buildOtpStep(vm),
                      if (vm.currentStep == ForgotPasswordStep.reset)
                        _buildResetStep(vm),

                      const SizedBox(height: 16),

                      // Error Message
                      if (vm.errorMessage.isNotEmpty)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.red[50],
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.red[200]!),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.error_outline,
                                color: Colors.red,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  vm.errorMessage,
                                  style: const TextStyle(color: Colors.red),
                                ),
                              ),
                            ],
                          ),
                        ),

                      // Success Message
                      if (vm.successMessage.isNotEmpty &&
                          vm.currentStep != ForgotPasswordStep.reset)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.green[50],
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.green[200]!),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.check_circle_outline,
                                color: Colors.green,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  vm.successMessage,
                                  style: const TextStyle(color: Colors.green),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  // Step 1: Email
  Widget _buildEmailStep(ForgotPasswordViewModel vm) {
    return Column(
      children: [
        CustomTextField(
          controller: _emailController,
          label: 'Email',
          hint: 'Masukkan email terdaftar',
          prefixIcon: Icons.email_outlined,
          keyboardType: TextInputType.emailAddress,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Email tidak boleh kosong';
            }
            if (!value.contains('@')) {
              return 'Email tidak valid';
            }
            return null;
          },
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            onPressed: vm.isLoading ? null : _handleSendOtp,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.deepPurple,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: vm.isLoading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text(
                    'Kirim OTP',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  // Step 2: OTP
  Widget _buildOtpStep(ForgotPasswordViewModel vm) {
    return Column(
      children: [
        CustomTextField(
          controller: _otpController,
          label: 'Kode OTP',
          hint: 'Masukkan kode OTP dari email',
          prefixIcon: Icons.lock_clock_outlined,
          keyboardType: TextInputType.number,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'OTP tidak boleh kosong';
            }
            if (value.length < 4) {
              return 'OTP minimal 4 digit';
            }
            return null;
          },
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            onPressed: vm.isLoading ? null : _handleVerifyOtp,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.deepPurple,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: vm.isLoading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text(
                    'Verifikasi OTP',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 16),
        TextButton(
          onPressed: vm.goBack,
          child: const Text('Ubah Email'),
        ),
      ],
    );
  }

  // Step 3: Reset Password
  Widget _buildResetStep(ForgotPasswordViewModel vm) {
    return Column(
      children: [
        CustomTextField(
          controller: _passwordController,
          label: 'Password Baru',
          hint: 'Masukkan password baru',
          prefixIcon: Icons.lock_outline,
          obscureText: _obscurePassword,
          suffixIcon: IconButton(
            icon: Icon(
              _obscurePassword ? Icons.visibility_off : Icons.visibility,
            ),
            onPressed: () {
              setState(() {
                _obscurePassword = !_obscurePassword;
              });
            },
          ),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Password tidak boleh kosong';
            }
            if (value.length < 6) {
              return 'Password minimal 6 karakter';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),
        CustomTextField(
          controller: _confirmPasswordController,
          label: 'Konfirmasi Password',
          hint: 'Masukkan ulang password baru',
          prefixIcon: Icons.lock_outline,
          obscureText: _obscureConfirmPassword,
          suffixIcon: IconButton(
            icon: Icon(
              _obscureConfirmPassword ? Icons.visibility_off : Icons.visibility,
            ),
            onPressed: () {
              setState(() {
                _obscureConfirmPassword = !_obscureConfirmPassword;
              });
            },
          ),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Konfirmasi password tidak boleh kosong';
            }
            if (value != _passwordController.text) {
              return 'Password tidak cocok';
            }
            return null;
          },
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            onPressed: vm.isLoading ? null : _handleResetPassword,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.deepPurple,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: vm.isLoading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text(
                    'Reset Password',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  IconData _getStepIcon(ForgotPasswordStep step) {
    switch (step) {
      case ForgotPasswordStep.email:
        return Icons.mark_email_read_outlined;
      case ForgotPasswordStep.otp:
        return Icons.lock_clock_outlined;
      case ForgotPasswordStep.reset:
        return Icons.lock_reset_outlined;
    }
  }

  String _getStepTitle(ForgotPasswordStep step) {
    switch (step) {
      case ForgotPasswordStep.email:
        return 'Lupa Password';
      case ForgotPasswordStep.otp:
        return 'Verifikasi OTP';
      case ForgotPasswordStep.reset:
        return 'Password Baru';
    }
  }

  String _getStepSubtitle(ForgotPasswordStep step) {
    switch (step) {
      case ForgotPasswordStep.email:
        return 'Masukkan email Anda untuk menerima kode OTP';
      case ForgotPasswordStep.otp:
        return 'Masukkan kode OTP yang dikirim ke email Anda';
      case ForgotPasswordStep.reset:
        return 'Masukkan password baru Anda';
    }
  }
}

// Step Indicator Widget
class _StepIndicator extends StatelessWidget {
  final ForgotPasswordStep currentStep;

  const _StepIndicator({required this.currentStep});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _StepCircle(
          number: '1',
          isActive: true,
          isCompleted: currentStep.index > 0,
        ),
        _StepLine(isActive: currentStep.index > 0),
        _StepCircle(
          number: '2',
          isActive: currentStep.index >= 1,
          isCompleted: currentStep.index > 1,
        ),
        _StepLine(isActive: currentStep.index > 1),
        _StepCircle(
          number: '3',
          isActive: currentStep.index >= 2,
          isCompleted: false,
        ),
      ],
    );
  }
}

class _StepCircle extends StatelessWidget {
  final String number;
  final bool isActive;
  final bool isCompleted;

  const _StepCircle({
    required this.number,
    required this.isActive,
    required this.isCompleted,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isCompleted
            ? Colors.green
            : isActive
                ? Colors.deepPurple
                : Colors.grey[300],
      ),
      child: Center(
        child: isCompleted
            ? const Icon(Icons.check, color: Colors.white, size: 20)
            : Text(
                number,
                style: TextStyle(
                  color: isActive ? Colors.white : Colors.grey[600],
                  fontWeight: FontWeight.bold,
                ),
              ),
      ),
    );
  }
}

class _StepLine extends StatelessWidget {
  final bool isActive;

  const _StepLine({required this.isActive});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 3,
      color: isActive ? Colors.deepPurple : Colors.grey[300],
    );
  }
}
