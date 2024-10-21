import 'package:flutter/material.dart';
import 'package:wakeup/services/auth_service.dart';

class LogWindow extends StatefulWidget {
  final Function(String) onApiKeySubmitted;

  const LogWindow({Key? key, required this.onApiKeySubmitted})
      : super(key: key);

  @override
  LogWindowState createState() => LogWindowState();
}

class LogWindowState extends State<LogWindow> {
  final AuthService _authService = AuthService(); // AuthService for Firebase
  final List<String> _logs = [];
  final TextEditingController _apiKeyController =
      TextEditingController(); // Controller for the input field

  @override
  void initState() {
    super.initState();
    _loadApiKey();
  }

  Future<void> _loadApiKey() async {
    final apiKey = await _authService.getStoredApiKey();
    if (apiKey != null) {
      widget.onApiKeySubmitted(apiKey);
    }
  }

  Future<void> _submitApiKey() async {
    final apiKey = _apiKeyController.text;
    if (apiKey.isNotEmpty) {
      widget.onApiKeySubmitted(apiKey);
      await _authService.storeApiKey(apiKey); // Store API key in Firebase
      addLog("API key submitted and stored.");
    } else {
      addLog("API key cannot be empty.");
    }
  }

  void addLog(String log) {
    setState(() {
      _logs.add(log);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: MediaQuery.of(context).size.width,
        height: MediaQuery.of(context).size.height, // Full screen
        color: Colors.grey[850], // Solid gray background theme
        child: Column(
          children: [
            AppBar(
              title: const Text(
                'Log Window',
                style: TextStyle(
                  color: Color.fromARGB(255, 209, 209, 209),
                ),
              ),
              backgroundColor: Colors.grey[900], // Darker gray app bar
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: TextField(
                controller: _apiKeyController,
                style: const TextStyle(
                  color: Colors.white, // White text when typing
                ),
                cursorColor: Colors.white, // White cursor
                decoration: const InputDecoration(
                  labelText: 'Enter API Key',
                  labelStyle:
                      TextStyle(color: Colors.white70), // White label text
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            ElevatedButton(
              onPressed: _submitApiKey,
              child: const Text('Submit API Key'),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: _logs.length,
                itemBuilder: (context, index) {
                  return Card(
                    color: Colors.grey[700], // Gray card background
                    margin:
                        const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Text(
                        _logs[index],
                        style:
                            const TextStyle(color: Colors.white), // White text
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
