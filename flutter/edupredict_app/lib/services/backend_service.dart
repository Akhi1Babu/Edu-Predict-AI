import 'package:flutter/material.dart';

class BackendService {
  // ValueNotifier to allow UI to react to changes, default to live 24/7 Render Cloud URL
  static final ValueNotifier<String> backendUrl = ValueNotifier<String>("https://edu-predict-ai-oo6l.onrender.com");

  static String get url => backendUrl.value;

  static void setUrl(String newIpOrUrl) {
    String formatted = newIpOrUrl.trim();
    if (formatted.isEmpty) return;

    if (!formatted.startsWith('http://') && !formatted.startsWith('https://')) {
      if (formatted.contains('.onrender.com') || formatted.contains('.railway.app') || formatted.contains('.koyeb.app')) {
        formatted = 'https://$formatted';
      } else if (!formatted.contains(':')) {
        formatted = 'http://$formatted:8000';
      } else {
        formatted = 'http://$formatted';
      }
    }
    backendUrl.value = formatted;
  }

  static void showSettingsDialog(BuildContext context) {
    final controller = TextEditingController(text: url.replaceFirst('http://', '').replaceFirst('https://', ''));

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Backend Server Configuration'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Enter your 24/7 Cloud API URL (e.g. my-app.onrender.com) or local IP (e.g. 192.168.1.15:8000).',
                style: TextStyle(fontSize: 13, color: Colors.grey),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                decoration: const InputDecoration(
                  labelText: 'Server URL or IP',
                  hintText: 'edupredict.onrender.com',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('CANCEL'),
            ),
            ElevatedButton(
              onPressed: () {
                setUrl(controller.text);
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Backend URL set to: $url')),
                );
              },
              child: const Text('SAVE'),
            ),
          ],
        );
      },
    );
  }
}
