import 'package:flutter/material.dart';
import '../models/account.dart';
import '../models/process_info.dart';
import '../services/api_service.dart';
import '../widgets/captcha_dialog.dart'; // Import the dialog widget

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ApiService _apiService = ApiService();
  final List<Account> _accounts = [];
  // Store processes linked to each account username
  final Map<String, List<ProcessInfo>> _accountProcesses = {}; 
  // Store loading state for each account
  final Map<String, bool> _accountLoading = {}; 

  String _notification = '';
  Color _notificationColor = Colors.black;

  // Controllers for the Add Account dialog
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  @override
  void dispose() {
    _apiService.dispose(); // Dispose the http client
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _updateNotification(String message, Color color) {
    if (mounted) {
      setState(() {
        _notification = message;
        _notificationColor = color;
      });
    }
    print("$color: $message"); // Also print to console
     // Optional: Show snackbar for important messages
    if (message.isNotEmpty && (color == Colors.red || color == Colors.green)) {
       ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: color,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  Future<void> _addAccount() async {
    // Clear previous input
    _usernameController.clear();
    _passwordController.clear();

    final result = await showDialog<Account>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Account'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _usernameController,
              decoration: const InputDecoration(labelText: 'Username'),
              autocorrect: false,
            ),
            TextField(
              controller: _passwordController,
              decoration: const InputDecoration(labelText: 'Password'),
              obscureText: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(), // Cancel
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              if (_usernameController.text.isNotEmpty && _passwordController.text.isNotEmpty) {
                Navigator.of(context).pop(Account(
                  username: _usernameController.text,
                  password: _passwordController.text,
                ));
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );

    if (result != null) {
       // Check if account already exists
      if (_accounts.any((acc) => acc.username == result.username)) {
          _updateNotification('Account ${result.username} already added.', Colors.orange);
          return;
      }

      _updateNotification('Attempting to log in ${result.username}...', Colors.blue);
      setState(() {
         _accountLoading[result.username] = true; // Set loading state
      });

      bool loggedIn = await _apiService.login(result.username, result.password);

      if (loggedIn) {
        _updateNotification('Login successful for ${result.username}. Fetching processes...', Colors.green);
        List<ProcessInfo> processes = await _apiService.fetchProcessIds(result.username);
        
        if (mounted) {
           setState(() {
            _accounts.add(result);
            _accountProcesses[result.username] = processes;
             _accountLoading[result.username] = false; // Clear loading state
          });
           if (processes.isEmpty) {
               _updateNotification('No processes found for ${result.username}.', Colors.orange);
           } else {
                _updateNotification('Found ${processes.length} processes for ${result.username}.', Colors.green);
           }
        }
      } else {
         if (mounted) {
            setState(() {
              _accountLoading[result.username] = false; // Clear loading state
            });
         }
        _updateNotification('Login failed for ${result.username}.', Colors.red);
      }
    }
  }

  Future<void> _handleCaptchaRequest(Account account, ProcessInfo process) async {
     _updateNotification('Fetching captcha for ${account.username} - ${process.centerName}...', Colors.blue);
     
     // Show loading indicator on the specific process button? (More complex UI needed)
     // For now, just show notification.

     String? base64Captcha = await _apiService.getCaptcha(process.processId);

     if (base64Captcha != null && mounted) {
        _updateNotification('Captcha received. Processing...', Colors.blue);
        
        // Show the Captcha Dialog
        showDialog(
          context: context,
          barrierDismissible: false, // Prevent closing by tapping outside
          builder: (context) => CaptchaDialog(
            apiService: _apiService, // Pass ApiService instance
            base64Captcha: base64Captcha!,
            account: account,
            processInfo: process,
            onResult: (message, color) {
              // Update notification from dialog result
              _updateNotification(message, color);
            },
          ),
        );

     } else if (mounted) {
       _updateNotification('Failed to fetch captcha for ${process.centerName}. Possible re-login needed?', Colors.red);
       // Optionally trigger re-login automatically here
       // bool reLoggedIn = await _apiService.login(account.username, account.password);
       // if (reLoggedIn) _handleCaptchaRequest(account, process); // Retry after re-login
     }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Captcha Solver'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          children: [
            // Notification Area
            if (_notification.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Text(
                  _notification,
                  style: TextStyle(color: _notificationColor, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
              ),

            // Add Account Button
            ElevatedButton.icon(
              icon: const Icon(Icons.person_add),
              label: const Text('Add Account'),
              onPressed: _addAccount,
            ),
            const Divider(height: 20, thickness: 1),

            // Accounts and Processes List
            Expanded(
              child: ListView.builder(
                itemCount: _accounts.length,
                itemBuilder: (context, index) {
                  final account = _accounts[index];
                  final processes = _accountProcesses[account.username] ?? [];
                  final isLoading = _accountLoading[account.username] ?? false;

                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 5.0),
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                           Row(
                             children: [
                               Expanded(
                                 child: Text(
                                    'Account: ${account.username}',
                                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                  ),
                               ),
                               if (isLoading) const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2,)),
                             ],
                           ),
                          const SizedBox(height: 5),
                          if (!isLoading && processes.isEmpty)
                             const Text('No processes loaded for this account.'),
                          ...processes.map((proc) => Padding(
                            padding: const EdgeInsets.only(left: 8.0, top: 4.0),
                            child: ElevatedButton(
                                onPressed: () => _handleCaptchaRequest(account, proc),
                                child: Text(proc.centerName),
                              ),
                          )),
                        ],
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
