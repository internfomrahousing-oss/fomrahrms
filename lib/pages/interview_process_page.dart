// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'package:flutter/material.dart';

const _blue = Color(0xFF0D47A1);

class InterviewProcessPage extends StatelessWidget {
  const InterviewProcessPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFF5F7FA),
      child: Column(
        children: [
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
            child: Row(children: [
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  color: _blue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.record_voice_over_rounded,
                    color: _blue, size: 20),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text('Interview Process',
                    style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: _blue)),
              ),
              ElevatedButton.icon(
                onPressed: () => html.window.open(
                  '${html.window.location.href.split('#')[0]}#/candidate-application',
                  '_blank',
                ),
                icon: const Icon(Icons.assignment_ind_rounded, size: 16),
                label: const Text('Application Form',
                    style: TextStyle(fontSize: 13)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _blue,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ]),
          ),
          const Expanded(child: SizedBox()),
        ],
      ),
    );
  }
}
