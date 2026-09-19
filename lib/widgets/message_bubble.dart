import 'package:flutter/material.dart';

import '../models/message.dart';
import '../theme/app_theme.dart';

/// Styled like a logged radio transmission rather than a rounded chat
/// bubble: sender + time in monospace (this is genuinely telemetry - who
/// sent it, when), the text itself in the readable sans below.
class MessageBubble extends StatelessWidget {
  final ChatMessage message;

  const MessageBubble({super.key, required this.message});

  String _time(DateTime t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final mine = message.isMine;
    final accent = mine ? AppColors.signal : AppColors.link;

    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 320),
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 9),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border(left: BorderSide(color: accent, width: 3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  mine ? 'you' : message.senderName,
                  style: TextStyle(
                    color: accent,
                    fontFamily: 'monospace',
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 8),
                Text(_time(message.timestamp), style: AppText.mono.copyWith(fontSize: 11)),
              ],
            ),
            const SizedBox(height: 4),
            Text(message.text, style: const TextStyle(color: AppColors.textPrimary, fontSize: 14.5, height: 1.35)),
          ],
        ),
      ),
    );
  }
}
