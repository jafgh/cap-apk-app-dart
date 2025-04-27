// Simple data class to hold account information
class Account {
  final String username;
  final String password; // Warning: Storing password directly is insecure

  Account({required this.username, required this.password});
}
