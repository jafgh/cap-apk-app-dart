// Simple data class for process information fetched from the API
class ProcessInfo {
  final String processId;
  final String centerName;

  ProcessInfo({required this.processId, required this.centerName});

  // Factory constructor to parse JSON from the API response
  factory ProcessInfo.fromJson(Map<String, dynamic> json) {
    return ProcessInfo(
      processId: json['PROCESS_ID']?.toString() ?? 'N/A', // Handle potential null or non-string types
      centerName: json['ZCENTER_NAME'] ?? 'Unknown Center', // Handle potential null
    );
  }
}
