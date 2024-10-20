import 'package:flutter/material.dart';

class LogWindow extends StatefulWidget {
  final Function(String) onApiKeySubmitted;

  const LogWindow({Key? key, required this.onApiKeySubmitted})
      : super(key: key);

  @override
  LogWindowState createState() => LogWindowState();
}

class LogWindowState extends State<LogWindow> {
  final TextEditingController _apiKeyController = TextEditingController();
  bool _isApiKeySubmitted = false;
  final List<String> _logs = [];

  void _submitApiKey() {
    final apiKey = _apiKeyController.text.trim();
    if (apiKey.isNotEmpty) {
      widget.onApiKeySubmitted(apiKey);
      setState(() {
        _isApiKeySubmitted = true;
      });
    }
  }

  void addLog(String log) {
    setState(() {
      _logs.add(log);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      child: Column(
        children: [
          AppBar(
            title: const Text('Caution Logs'),
            backgroundColor: Colors.blue,
          ),
          Expanded(
            child: _isApiKeySubmitted ? _buildLogList() : _buildApiKeyInput(),
          ),
        ],
      ),
    );
  }

  Widget _buildApiKeyInput() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          TextField(
            controller: _apiKeyController,
            decoration: const InputDecoration(
              labelText: 'Enter Gemini API',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _submitApiKey,
            child: const Text('Submit'),
          ),
        ],
      ),
    );
  }

  Widget _buildLogList() {
    return ListView.builder(
      itemCount: _logs.length,
      itemBuilder: (context, index) {
        return Card(
          margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Text(_logs[index]),
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    super.dispose();
  }
}
