class ChatMessage {
  final String id; // unique message id (uuid) - used for mesh dedup
  final String senderId; // ephemeral peer id of sender
  final String senderName; // display name at time of sending
  final String text;
  final DateTime timestamp;
  final bool isMine;

  ChatMessage({
    required this.id,
    required this.senderId,
    required this.senderName,
    required this.text,
    required this.timestamp,
    this.isMine = false,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'senderId': senderId,
        'senderName': senderName,
        'text': text,
        'timestamp': timestamp.millisecondsSinceEpoch,
      };

  factory ChatMessage.fromJson(Map<String, dynamic> json, {bool isMine = false}) {
    return ChatMessage(
      id: json['id'] as String,
      senderId: json['senderId'] as String,
      senderName: json['senderName'] as String,
      text: json['text'] as String,
      timestamp: DateTime.fromMillisecondsSinceEpoch(json['timestamp'] as int),
      isMine: isMine,
    );
  }
}
