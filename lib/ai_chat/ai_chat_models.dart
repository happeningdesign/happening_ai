import 'package:flutter/material.dart';

/// ====================== CONFIG ======================
/// Optional custom spacer to avoid raw SizedBox if you prefer:
class SpacerWidget extends StatelessWidget {
  final double size;
  const SpacerWidget(this.size, {super.key});
  @override
  Widget build(BuildContext context) => SizedBox(height: size, width: size);
}

/// =============== MODELS & HELPERS ===================
enum Role { user, assistant }

class ChatMessage {
  final Role role;
  final String contentMarkdown;
  ChatMessage(this.role, this.contentMarkdown);
}

/// Split markdown into ordered Text and Code blocks
enum BlockType { text, code }

class Block {
  final BlockType type;
  final String content;
  final String? lang;
  Block(this.type, this.content, {this.lang});
}

List<Block> splitMarkdown(String input) {
  final re = RegExp(r'```(\w+)?\s*([\s\S]*?)```', multiLine: true);
  final blocks = <Block>[];
  int last = 0;

  for (final m in re.allMatches(input)) {
    if (m.start > last) {
      final text = input.substring(last, m.start).trim();
      if (text.isNotEmpty) blocks.add(Block(BlockType.text, text));
    }
    final lang = m.group(1)?.trim();
    final code = (m.group(2) ?? '').trimRight();
    blocks.add(
      Block(
        BlockType.code,
        code,
        lang: (lang?.isEmpty ?? true) ? 'dart' : lang,
      ),
    );
    last = m.end;
  }
  if (last < input.length) {
    final text = input.substring(last).trim();
    if (text.isNotEmpty) blocks.add(Block(BlockType.text, text));
  }
  return blocks;
}
