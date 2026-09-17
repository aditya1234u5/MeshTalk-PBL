import 'package:hive_flutter/hive_flutter.dart';
import '../models/message.dart';

/// Persists chat history locally on-device across app sessions, using Hive
/// (a lightweight NoSQL key-value store - no native SQL setup needed,
/// which is why it's the faster of the two options the synopsis lists).
///
/// Each message is stored as a plain Map under its own message ID key, so
/// writes are O(1) and don't require re-serializing the whole history.
class PersistenceService {
  static const _boxName = 'chat_history';
  late Box<Map> _box;

  Future<void> init() async {
    await Hive.initFlutter();
    _box = await Hive.openBox<Map>(_boxName);
  }

  Future<void> saveMessage(ChatMessage message) async {
    await _box.put(message.id, {
      ...message.toJson(),
      'isMine': message.isMine,
    });
  }

  /// Loads all persisted messages, oldest first, for restoring the chat
  /// thread on app startup.
  List<ChatMessage> loadAll() {
    final messages = _box.values.map((raw) {
      final map = Map<String, dynamic>.from(raw);
      final isMine = map['isMine'] as bool? ?? false;
      return ChatMessage.fromJson(map, isMine: isMine);
    }).toList();
    messages.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    return messages;
  }

  Future<void> clearAll() async {
    await _box.clear();
  }
}
