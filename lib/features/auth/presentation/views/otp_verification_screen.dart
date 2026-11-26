import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:wayhunter_mobile/core/network/api_client.dart';
import 'package:wayhunter_mobile/features/auth/presentation/auth_form.dart';

enum OtpVerificationResult {
  verified,
  wrongCode,
  invalidOrExpired,
  expired,
  networkError,
}

class OtpVerificationScreen extends StatefulWidget {
  const OtpVerificationScreen({
    super.key,
    required this.email,
    this.onVerify,
    this.onResend,
    this.onVerified,
    this.initialCooldownSeconds = 0,
    this.resendCooldownSeconds = 60,
  });

  final String email;

  final VoidCallback? onVerified;
  final Future<OtpVerificationResult> Function(String code)? onVerify;

  final Future<bool> Function()? onResend;

  final int initialCooldownSeconds;
  final int resendCooldownSeconds;

  @override
  State<OtpVerificationScreen> createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends State<OtpVerificationScreen> {
  final _otpController = TextEditingController();

  Timer? _countdownTimer;
  int _secondsRemaining = 0;

  bool _isVerifying = false;
  bool _isResending = false;
  String? _message;
  bool _isError = false;

  @override
  void initState() {
    super.initState();

    assert(widget.initialCooldownSeconds >= 0);
    assert(widget.resendCooldownSeconds > 0);

    _beginCountdown(widget.initialCooldownSeconds);
  }

  void _beginCountdown(int seconds) {
    _countdownTimer?.cancel();
    _secondsRemaining = seconds;

    if (seconds <= 0) return;

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      setState(() {
        if (_secondsRemaining > 0) {
          _secondsRemaining--;
        }

        if (_secondsRemaining == 0) {
          timer.cancel();
        }
      });
    });
  }

  Future<void> _verifyOtp() async {
    if (_isVerifying || _isResending) return;

    final code = _otpController.text.trim();

    if (!RegExp(r'^[0-9]{6}$').hasMatch(code)) {
      setState(() {
        _message = 'Enter a valid 6-digit OTP';
        _isError = true;
      });
      return;
    }

    final verify = widget.onVerify;

    if (verify == null) {
      setState(() {
        _message = 'Verification API not connected yet';
        _isError = true;
      });
      return;
    }

    setState(() {
      _isVerifying = true;
      _message = null;
    });

    try {
      final result = await verify(code);

      if (!mounted) return;

      setState(() {
        _isError = result != OtpVerificationResult.verified;

        _message = switch (result) {
          OtpVerificationResult.verified => 'Email verified successfully',
          OtpVerificationResult.wrongCode => 'Incorrect OTP. Please try again.',
          OtpVerificationResult.invalidOrExpired =>
            'Incorrect or expired OTP. Try again or request a new code.',
          OtpVerificationResult.expired => 'OTP expired. Request a new code.',
          OtpVerificationResult.networkError => 'Network error. Please retry.',
        };
      });
      if (result == OtpVerificationResult.verified) widget.onVerified?.call();
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _message = authErrorMessage(error);
        _isError = true;
      });
    } finally {
      if (mounted) {
        setState(() {
          _isVerifying = false;
        });
      }
    }
  }

  Future<void> _resendOtp() async {
    if (_secondsRemaining > 0 || _isResending || _isVerifying) {
      return;
    }

    final resend = widget.onResend;

    if (resend == null) {
      setState(() {
        _message = 'Resend API not connected yet';
        _isError = true;
      });
      return;
    }

    setState(() {
      _isResending = true;
      _message = null;
    });

    try {
      final success = await resend();

      if (!mounted) return;

      if (success) {
        _otpController.clear();

        _beginCountdown(widget.resendCooldownSeconds);
      }

      setState(() {
        _isError = !success;
        _message = success
            ? 'A new OTP has been requested'
            : 'Could not resend OTP. Please retry.';
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        if (error is ApiException && error.statusCode == 429) {
          _beginCountdown(
            error.retryAfterSeconds ?? widget.resendCooldownSeconds,
          );
        }
        _message = authErrorMessage(error);
        _isError = true;
      });
    } finally {
      if (mounted) {
        setState(() {
          _isResending = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _otpController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final busy = _isVerifying || _isResending;

    return Scaffold(
      backgroundColor: const Color(0xFF0A1420),
      appBar: AppBar(title: const Text('Verify Email')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(
                    Icons.mark_email_read_outlined,
                    color: Color(0xFF17C8E6),
                    size: 64,
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'OTP Verification',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Enter the verification code sent to '
                    '${widget.email}',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 28),
                  TextField(
                    controller: _otpController,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    maxLength: 6,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(
                      labelText: '6-digit OTP',
                      hintText: '000000',
                      border: OutlineInputBorder(),
                      counterText: '',
                    ),
                  ),
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: busy ? null : _verifyOtp,
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Text(_isVerifying ? 'Verifying...' : 'Verify OTP'),
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (_secondsRemaining > 0)
                    Text(
                      'Resend code in '
                      '$_secondsRemaining ${_secondsRemaining == 1 ? 'second' : 'seconds'}',
                      textAlign: TextAlign.center,
                    )
                  else
                    TextButton(
                      onPressed: busy ? null : _resendOtp,
                      child: Text(_isResending ? 'Resending...' : 'Resend OTP'),
                    ),
                  if (_message != null) ...[
                    const SizedBox(height: 20),
                    Text(
                      _message!,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: _isError ? Colors.redAccent : Colors.greenAccent,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
