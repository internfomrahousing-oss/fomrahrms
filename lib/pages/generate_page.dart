import 'package:flutter/material.dart';
import '../widgets/form_detail_page.dart' as fd;

class GeneratePage extends StatelessWidget {
  const GeneratePage({super.key});

  @override
  Widget build(BuildContext context) {
    return const fd.FormDetailPage(
      title: 'Generate',
      icon: Icons.summarize_rounded,
      color: Color(0xFF2563EB),
      fields: [
        fd.FormField(label: 'Working Hours',  icon: Icons.schedule_rounded,  keyboardType: TextInputType.number),
        fd.FormField(label: 'Overtime Hours', icon: Icons.more_time_rounded, keyboardType: TextInputType.number),
      ],
    );
  }
}
