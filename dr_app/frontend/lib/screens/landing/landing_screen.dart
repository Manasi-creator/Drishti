import 'package:flutter/material.dart';

import '../auth/sign_in_screen.dart';

class LandingScreen extends StatelessWidget {
  const LandingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1280),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 32),
              child: Row(
                children: [
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(right: 32),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text(
                            'DRISHTI',
                            style: TextStyle(
                              fontSize: 30,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 3,
                              color: Color(0xFF123B4A),
                            ),
                          ),
                          const SizedBox(height: 18),
                          const Text(
                            'AI-Assisted Diabetic Retinopathy Screening',
                            style: TextStyle(
                              fontSize: 38,
                              fontWeight: FontWeight.bold,
                              height: 1.15,
                              color: Color(0xFF17202A),
                            ),
                          ),
                          const SizedBox(height: 18),
                          const Text(
                            'Empowering clinicians with AI-assisted retinal screening, explainable results and structured patient review.',
                            style: TextStyle(
                              fontSize: 20,
                              color: Color(0xFF4B5563),
                              height: 1.5,
                            ),
                          ),
                          const SizedBox(height: 32),
                          Wrap(
                            spacing: 12,
                            runSpacing: 12,
                            children: const [
                              FeatureChip('AI-assisted retinal screening'),
                              FeatureChip('Explainable AI attention maps'),
                              FeatureChip('Patient screening history'),
                              FeatureChip('Structured clinical reports'),
                            ],
                          ),
                          const SizedBox(height: 36),
                          SizedBox(
                            height: 54,
                            child: ElevatedButton(
                              onPressed: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => const SignInScreen(),
                                  ),
                                );
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF176B87),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 32,
                                  vertical: 18,
                                ),
                                textStyle: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              child: const Text('Sign In'),
                            ),
                          ),
                          const SizedBox(height: 24),
                          const Text(
                            'Drishti is an AI-assisted screening support system and does not replace professional medical judgment or definitive diagnosis.',
                            style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFF6B7280),
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Expanded(
                    child: Container(
                      height: 620,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(28),
                        gradient: const LinearGradient(
                          colors: [
                            Color(0xFF123B4A),
                            Color(0xFF176B87),
                            Color(0xFF5CB8D1),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.12),
                            blurRadius: 28,
                            offset: const Offset(0, 16),
                          ),
                        ],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(30),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.all(18),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(18),
                              ),
                              child: const Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(
                                    Icons.remove_red_eye_outlined,
                                    color: Colors.white,
                                    size: 40,
                                  ),
                                  SizedBox(height: 12),
                                  Text(
                                    'Clinical screening review',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 18,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  SizedBox(height: 8),
                                  Text(
                                    'Review retinal findings, grade severity, and attention-guided explanations in one workflow.',
                                    style: TextStyle(
                                      color: Colors.white70,
                                      fontSize: 14,
                                      height: 1.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                            Expanded(
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(22),
                                ),
                                child: const Center(
                                  child: Icon(
                                    Icons.medical_information_outlined,
                                    size: 180,
                                    color: Colors.white70,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 18),
                            const Text(
                              'AI-assisted screening support • Clinician review required',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
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

class FeatureChip extends StatelessWidget {
  const FeatureChip(this.label, {super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Color(0xFF123B4A),
          fontWeight: FontWeight.w600,
          fontSize: 13,
        ),
      ),
    );
  }
}
