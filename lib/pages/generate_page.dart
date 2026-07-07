import 'package:flutter/material.dart';
import '../widgets/form_detail_page.dart' as fd;
import '../theme/app_theme.dart';

class GeneratePage extends StatelessWidget {
  const GeneratePage({super.key});

  @override
  Widget build(BuildContext context) {
    return fd.FormDetailPage(
      title: 'Generate',
      icon: Icons.summarize_rounded,
      color: AppTheme.primaryBlue,
      fields: [
        fd.FormField(label: 'Working Hours',  icon: Icons.schedule_rounded,  keyboardType: TextInputType.number),
        fd.FormField(label: 'Overtime Hours', icon: Icons.more_time_rounded, keyboardType: TextInputType.number),
      ],
    );
  }
}
