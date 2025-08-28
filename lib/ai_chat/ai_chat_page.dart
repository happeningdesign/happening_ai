import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:highlight/highlight.dart' as hi;/*
import 'package:dart_eval/dart_eval.dart';
import 'package:flutter_eval/flutter_eval.dart';*/

import 'ai_chat_cubit.dart';
import 'ai_chat_models.dart';

/// Minimal code highlighter for Markdown inline code (not used by our code card)
class _DartHighlighter extends SyntaxHighlighter {
  @override
  TextSpan format(String source) {
    final nodes = hi.highlight.parse(source, language: 'dart').nodes ?? [];
    return _toTextSpan(nodes);
  }

  TextSpan _toTextSpan(List<hi.Node> nodes) {
    final children = <TextSpan>[];
    for (final n in nodes) {
      if (n.value != null) {
        children.add(TextSpan(text: n.value));
      } else if (n.children != null) {
        children.add(
          TextSpan(
            style: TextStyle(
                color: _colorFor(n.className), fontFamily: 'monospace'),
            children: [_toTextSpan(n.children!)],
          ),
        );
      }
    }
    return TextSpan(
        style: const TextStyle(fontFamily: 'monospace'), children: children);
  }

  Color? _colorFor(String? cls) {
    switch (cls) {
      case 'keyword':
      case 'built_in':
        return const Color(0xffa626a4);
      case 'string':
        return const Color(0xff50a14f);
      case 'number':
      case 'literal':
        return const Color(0xff986801);
      case 'comment':
        return const Color(0xffa0a1a7);
      case 'title':
      case 'function':
        return const Color(0xff4078f2);
    }
    return null;
  }
}

class AiChatPage extends StatefulWidget {
  const AiChatPage({super.key});

  @override
  State<AiChatPage> createState() => _AiChatPageState();
}

class _AiChatPageState extends State<AiChatPage> {
  final _input = TextEditingController();
  final _scroll = ScrollController();

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _autoScroll() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent + 200,
          duration: const Duration(milliseconds: 800),
          curve: Curves.easeInOutCubic,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<AiChatCubit, AiChatState>(
      listenWhen: (prev, curr) =>
          prev.messages.length != curr.messages.length ||
          prev.loading != curr.loading,
      listener: (context, state) => _autoScroll(),
      builder: (context, state) {
        return Scaffold(
          backgroundColor: const Color(0xFFF7F7F8),
          appBar: AppBar(
            backgroundColor: Colors.white,
            elevation: 0,
            title: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF10A37F), Color(0xFF1DB584)],
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.auto_awesome,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  'AI Design Assistant',
                  style: TextStyle(
                    color: Color(0xFF1D1D1F),
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            centerTitle: false,
          ),
          body: Column(
            children: [
              Expanded(
                child: ListView.builder(
                  controller: _scroll,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  itemCount: state.messages.length + (state.loading ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index == state.messages.length && state.loading) {
                      // Show typing indicator
                      return const _TypingIndicator();
                    }

                    final m = state.messages[index];
                    final isUser = m.role == Role.user;
                    return _ChatMessageWidget(
                      message: m,
                      isUser: isUser,
                    );
                  },
                ),
              ),
              if (state.error != null)
                Container(
                  margin:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline,
                          color: Colors.red.shade600, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          state.error!,
                          style: TextStyle(
                              color: Colors.red.shade700, fontSize: 14),
                        ),
                      ),
                    ],
                  ),
                ),
              _ModernComposer(
                controller: _input,
                loading: state.loading,
                onSend: () {
                  final text = _input.text;
                  context.read<AiChatCubit>().sendPrompt(text);
                  _input.clear();
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ChatMessageWidget extends StatefulWidget {
  final ChatMessage message;
  final bool isUser;

  const _ChatMessageWidget({
    required this.message,
    required this.isUser,
  });

  @override
  State<_ChatMessageWidget> createState() => _ChatMessageWidgetState();
}

class _ChatMessageWidgetState extends State<_ChatMessageWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    ));

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    ));

    // Start animation after a brief delay
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) {
        _animationController.forward();
      }
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: _slideAnimation,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          color: widget.isUser ? Colors.transparent : Colors.white,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 768),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Avatar
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: widget.isUser
                          ? const Color(0xFF10A37F)
                          : const Color(0xFF6366F1),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(
                      widget.isUser ? Icons.person : Icons.auto_awesome,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 16),
                  // Message content
                  Expanded(
                    child: _MessageContent(
                      markdown: widget.message.contentMarkdown,
                      isUser: widget.isUser,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MessageContent extends StatelessWidget {
  final String markdown;
  final bool isUser;

  const _MessageContent({
    required this.markdown,
    required this.isUser,
  });

  @override
  Widget build(BuildContext context) {
    if (isUser) {
      return SelectableText(
        markdown,
        style: const TextStyle(
          fontSize: 15,
          height: 1.5,
          color: Color(0xFF1D1D1F),
        ),
      );
    }

    final blocks = splitMarkdown(markdown);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (int i = 0; i < blocks.length; i++) ...[
          if (blocks[i].type == BlockType.text)
            MarkdownBody(
              data: blocks[i].content,
              selectable: true,
              shrinkWrap: true,
              styleSheet: MarkdownStyleSheet(
                p: const TextStyle(
                  fontSize: 15,
                  height: 1.5,
                  color: Color(0xFF1D1D1F),
                ),
                code: TextStyle(
                  fontFamily: 'SF Mono',
                  fontSize: 13,
                  backgroundColor: const Color(0xFFF6F6F7),
                  color: const Color(0xFFEB5757),
                ),
                codeblockDecoration: BoxDecoration(
                  color: const Color(0xFFF6F6F7),
                  borderRadius: BorderRadius.circular(6),
                ),
                h1: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1D1D1F),
                ),
                h2: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1D1D1F),
                ),
                h3: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1D1D1F),
                ),
                listBullet: const TextStyle(
                  color: Color(0xFF1D1D1F),
                ),
              ),
              syntaxHighlighter: _DartHighlighter(),
            )
          else
            _ModernCodeCard(
                code: blocks[i].content, lang: blocks[i].lang ?? 'dart'),
          if (i != blocks.length - 1) const SizedBox(height: 12),
        ],
      ],
    );
  }
}

class _ModernCodeCard extends StatefulWidget {
  final String code;
  final String lang;

  const _ModernCodeCard({required this.code, required this.lang});

  @override
  State<_ModernCodeCard> createState() => _ModernCodeCardState();
}

class _ModernCodeCardState extends State<_ModernCodeCard> {
  bool _copied = false;

  void _copyCode() async {
    await Clipboard.setData(ClipboardData(text: widget.code));
    setState(() => _copied = true);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  void _showPreview() {
   /* showDialog(
      context: context,
      builder: (context) => _FlutterCodePreviewDialog(code: widget.code),
    );*/
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF333333)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header with language and copy button
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: const BoxDecoration(
              color: Color(0xFF2D2D2D),
              borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
            ),
            child: Row(
              children: [
                Text(
                  widget.lang,
                  style: const TextStyle(
                    color: Color(0xFF9CA3AF),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const Spacer(),
                // Preview button (only for Flutter/Dart code)
                if (widget.lang.toLowerCase() == 'dart' ||
                    widget.lang.toLowerCase() == 'flutter')
                  InkWell(
                    onTap: _showPreview,
                    borderRadius: BorderRadius.circular(4),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.preview,
                            size: 14,
                            color: const Color(0xFF9CA3AF),
                          ),
                          const SizedBox(width: 4),
                          const Text(
                            'Preview',
                            style: TextStyle(
                              color: Color(0xFF9CA3AF),
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                if (widget.lang.toLowerCase() == 'dart' ||
                    widget.lang.toLowerCase() == 'flutter')
                  const SizedBox(width: 8),
                // Copy button
                InkWell(
                  onTap: _copyCode,
                  borderRadius: BorderRadius.circular(4),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _copied ? Icons.check : Icons.copy,
                          size: 14,
                          color: _copied
                              ? const Color(0xFF10A37F)
                              : const Color(0xFF9CA3AF),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _copied ? 'Copied!' : 'Copy',
                          style: TextStyle(
                            color: _copied
                                ? const Color(0xFF10A37F)
                                : const Color(0xFF9CA3AF),
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Code content
          Padding(
            padding: const EdgeInsets.all(16),
            child: SelectableText(
              widget.code,
              style: const TextStyle(
                fontFamily: 'SF Mono',
                fontSize: 13,
                height: 1.4,
                color: Color(0xFFE5E7EB),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ModernComposer extends StatefulWidget {
  final TextEditingController controller;
  final bool loading;
  final VoidCallback onSend;

  const _ModernComposer({
    required this.controller,
    required this.loading,
    required this.onSend,
  });

  @override
  State<_ModernComposer> createState() => _ModernComposerState();
}

class _ModernComposerState extends State<_ModernComposer> {
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    super.dispose();
  }

  void _onTextChanged() {
    final hasText = widget.controller.text.trim().isNotEmpty;
    if (hasText != _hasText) {
      setState(() => _hasText = hasText);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFE5E7EB))),
      ),
      padding: const EdgeInsets.all(20),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: const Color(0xFFD1D5DB)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: TextField(
                  controller: widget.controller,
                  minLines: 1,
                  maxLines: 6,
                  style: const TextStyle(
                    fontSize: 15,
                    height: 1.4,
                    color: Color(0xFF1D1D1F),
                  ),
                  decoration: InputDecoration(
                    hintText: 'Describe the UI you want...',
                    hintStyle: const TextStyle(
                      color: Color(0xFF9CA3AF),
                      fontSize: 15,
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                  ),
                  onSubmitted: _hasText && !widget.loading
                      ? (_) => widget.onSend()
                      : null,
                ),
              ),
            ),
            const SizedBox(width: 12),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              child: Material(
                color: (_hasText && !widget.loading)
                    ? const Color(0xFF10A37F)
                    : const Color(0xFFE5E7EB),
                borderRadius: BorderRadius.circular(20),
                child: InkWell(
                  onTap: (_hasText && !widget.loading) ? widget.onSend : null,
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    width: 40,
                    height: 40,
                    alignment: Alignment.center,
                    child: widget.loading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : Icon(
                            Icons.arrow_upward,
                            color: (_hasText && !widget.loading)
                                ? Colors.white
                                : const Color(0xFF9CA3AF),
                            size: 20,
                          ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TypingIndicator extends StatefulWidget {
  const _TypingIndicator();

  @override
  State<_TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<_TypingIndicator>
    with TickerProviderStateMixin {
  late List<AnimationController> _controllers;
  late List<Animation<double>> _animations;

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(
      3,
      (index) => AnimationController(
        duration: const Duration(milliseconds: 600),
        vsync: this,
      ),
    );

    _animations = _controllers.map((controller) {
      return Tween<double>(begin: 0.4, end: 1.0).animate(
        CurvedAnimation(parent: controller, curve: Curves.easeInOut),
      );
    }).toList();

    // Start animations with delays
    for (int i = 0; i < _controllers.length; i++) {
      Future.delayed(Duration(milliseconds: i * 200), () {
        if (mounted) {
          _controllers[i].repeat(reverse: true);
        }
      });
    }
  }

  @override
  void dispose() {
    for (final controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      color: Colors.white,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 768),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // AI Avatar
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: const Color(0xFF6366F1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.auto_awesome,
                  color: Colors.white,
                  size: 18,
                ),
              ),
              const SizedBox(width: 16),
              // Typing animation
              Expanded(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F1F2),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (int i = 0; i < 3; i++) ...[
                        AnimatedBuilder(
                          animation: _animations[i],
                          builder: (context, child) {
                            return Opacity(
                              opacity: _animations[i].value,
                              child: Container(
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(
                                  color: Color(0xFF8E8EA0),
                                  shape: BoxShape.circle,
                                ),
                              ),
                            );
                          },
                        ),
                        if (i < 2) const SizedBox(width: 4),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/*
class _FlutterCodePreviewDialog extends StatefulWidget {
  final String code;

  const _FlutterCodePreviewDialog({required this.code});

  @override
  State<_FlutterCodePreviewDialog> createState() =>
      _FlutterCodePreviewDialogState();
}

class _FlutterCodePreviewDialogState extends State<_FlutterCodePreviewDialog> {
  Widget? _previewWidget;
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _compileAndRenderCode();
  }

  Future<void> _compileAndRenderCode() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      // Try dart_eval compilation first
      final preparedCode = _prepareFlutterCode(widget.code);

      // Attempt to compile with dart_eval

      final compiler = Compiler();

      final program = compiler.compile({
        'example': {
          'main.dart': preparedCode,
        }
      });
      final runtime = Runtime.ofProgram(program);
      // final executable = runtime.loadProgram(program);
      final result = runtime.executeLib('example', preparedCode);

      Widget? compiledWidget;
      if (result is Widget) {
        compiledWidget = result;
      }

      setState(() {
        _previewWidget = compiledWidget ?? _createFallbackWidget();
        _loading = false;
      });
    } catch (e) {
      // dart_eval compilation failed, use smart pattern matching
      debugPrint('dart_eval compilation failed: $e');

      try {
        final fallbackWidget = _createFallbackWidget();
        setState(() {
          _previewWidget = fallbackWidget;
          _loading = false;
        });
      } catch (fallbackError) {
        setState(() {
          _error = 'Could not generate preview: Unable to parse Flutter code';
          _loading = false;
        });
      }
    }
  }

  String _prepareFlutterCode(String code) {
    // Clean and prepare the code for compilation
    String cleanCode = code.trim();

    // Add necessary imports if not present
    if (!cleanCode.contains('import \'package:flutter/material.dart\';')) {
      cleanCode = "import 'package:flutter/material.dart';\n\n$cleanCode";
    }

    // If the code doesn't contain a function that returns a Widget,
    // wrap it in a createWidget function
    if (!cleanCode.contains('Widget') || !cleanCode.contains('(')) {
      // Assume it's just a widget definition that needs to be wrapped
      cleanCode = """
import 'package:flutter/material.dart';

Widget createWidget() {
  return $cleanCode;
}
""";
    } else if (!cleanCode.contains('createWidget')) {
      // The code has a widget but not the createWidget function
      // Try to extract the main widget and wrap it
      if (cleanCode.contains('class ') &&
          cleanCode.contains('extends StatelessWidget')) {
        final className = _extractClassName(cleanCode);
        if (className != null) {
          cleanCode += "\n\nWidget createWidget() {\n  return $className();\n}";
        }
      } else if (cleanCode.contains('class ') &&
          cleanCode.contains('extends StatefulWidget')) {
        final className = _extractClassName(cleanCode);
        if (className != null) {
          cleanCode += "\n\nWidget createWidget() {\n  return $className();\n}";
        }
      } else {
        // Try to wrap the entire code as a return statement
        cleanCode = """
import 'package:flutter/material.dart';

Widget createWidget() {
  return $cleanCode;
}
""";
      }
    }

    return cleanCode;
  }

  String? _extractClassName(String code) {
    final match =
        RegExp(r'class\s+(\w+)\s+extends\s+Stateful?Widget').firstMatch(code);
    return match?.group(1);
  }

  Widget _createFallbackWidget() {
    return _createPreviewWidget(widget.code);
  }

  Widget _createPreviewWidget(String code) {
    final lowerCode = code.toLowerCase().trim();

    // Try to extract colors
    Color primaryColor = Colors.blue;
    if (code.contains('Colors.red'))
      primaryColor = Colors.red;
    else if (code.contains('Colors.green'))
      primaryColor = Colors.green;
    else if (code.contains('Colors.purple'))
      primaryColor = Colors.purple;
    else if (code.contains('Colors.orange'))
      primaryColor = Colors.orange;
    else if (code.contains('Colors.teal')) primaryColor = Colors.teal;

    // Common Flutter widget patterns
    if (lowerCode.contains('container')) {
      return _createContainerPreview(code, primaryColor);
    } else if (lowerCode.contains('card')) {
      return _createCardPreview(code, primaryColor);
    } else if (lowerCode.contains('button') ||
        lowerCode.contains('elevatedbutton')) {
      return _createButtonPreview(code, primaryColor);
    } else if (lowerCode.contains('text')) {
      return _createTextPreview(code, primaryColor);
    } else if (lowerCode.contains('appbar')) {
      return _createAppBarPreview(code, primaryColor);
    } else if (lowerCode.contains('listview') || lowerCode.contains('list')) {
      return _createListPreview(code, primaryColor);
    } else if (lowerCode.contains('column') || lowerCode.contains('row')) {
      return _createLayoutPreview(code, primaryColor);
    } else {
      return _createGenericPreview(code, primaryColor);
    }
  }

  Widget _createContainerPreview(String code, Color color) {
    return Center(
      child: Container(
        width: 200,
        height: 150,
        decoration: BoxDecoration(
          color: color.withOpacity(0.2),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color, width: 2),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.widgets, color: color, size: 48),
              const SizedBox(height: 8),
              Text(
                'Container Preview',
                style: TextStyle(color: color, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _createCardPreview(String code, Color color) {
    return Center(
      child: Card(
        elevation: 4,
        child: Container(
          width: 250,
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.credit_card, color: color, size: 48),
              const SizedBox(height: 12),
              Text(
                'Card Preview',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              const SizedBox(height: 8),
              const Text('This is a sample card widget preview'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _createButtonPreview(String code, Color color) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ElevatedButton(
            onPressed: () {},
            style: ElevatedButton.styleFrom(
              backgroundColor: color,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: const Text('Sample Button'),
          ),
          const SizedBox(height: 16),
          OutlinedButton(
            onPressed: () {},
            style: OutlinedButton.styleFrom(
              foregroundColor: color,
              side: BorderSide(color: color),
            ),
            child: const Text('Outlined Button'),
          ),
        ],
      ),
    );
  }

  Widget _createTextPreview(String code, Color color) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'Heading Text',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'This is a sample text widget preview.\nIt shows how text might appear in your Flutter app.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _createAppBarPreview(String code, Color color) {
    return Column(
      children: [
        AppBar(
          title: const Text('App Bar Preview'),
          backgroundColor: color,
          foregroundColor: Colors.white,
          elevation: 2,
          leading: const Icon(Icons.menu),
          actions: [
            const Icon(Icons.search),
            const SizedBox(width: 16),
            const Icon(Icons.more_vert),
            const SizedBox(width: 8),
          ],
        ),
        Expanded(
          child: Container(
            color: Colors.grey[100],
            child: const Center(
              child: Text('App content would go here'),
            ),
          ),
        ),
      ],
    );
  }

  Widget _createListPreview(String code, Color color) {
    return ListView.builder(
      itemCount: 5,
      padding: const EdgeInsets.all(8),
      itemBuilder: (context, index) {
        return Card(
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: color,
              child: Text('${index + 1}'),
            ),
            title: Text('List Item ${index + 1}'),
            subtitle: Text('This is subtitle ${index + 1}'),
            trailing: const Icon(Icons.arrow_forward_ios),
          ),
        );
      },
    );
  }

  Widget _createLayoutPreview(String code, Color color) {
    bool isRow = code.toLowerCase().contains('row');

    return Center(
      child: Container(
        padding: const EdgeInsets.all(16),
        child: isRow
            ? Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _layoutItem(color, '1'),
                  _layoutItem(color, '2'),
                  _layoutItem(color, '3'),
                ],
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _layoutItem(color, '1'),
                  const SizedBox(height: 16),
                  _layoutItem(color, '2'),
                  const SizedBox(height: 16),
                  _layoutItem(color, '3'),
                ],
              ),
      ),
    );
  }

  Widget _layoutItem(Color color, String label) {
    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color),
      ),
      child: Center(
        child: Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _createGenericPreview(String code, Color color) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 200,
            height: 120,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [color.withOpacity(0.3), color.withOpacity(0.1)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: color, width: 2),
            ),
            child: Center(
              child: Icon(
                Icons.flutter_dash,
                size: 48,
                color: color,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Flutter Widget Preview',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Dynamic preview based on your code',
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog.fullscreen(
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Flutter Code Preview'),
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.of(context).pop(),
          ),
          actions: [
            if (!_loading && _error == null)
              TextButton(
                onPressed: () {
                  _compileAndRenderCode();
                },
                child: const Text('Refresh'),
              ),
          ],
        ),
        body: Container(
          color: const Color(0xFFF5F5F5),
          child: _loading
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text('Generating preview...'),
                    ],
                  ),
                )
              : _error != null
                  ? Center(
                      child: Container(
                        margin: const EdgeInsets.all(20),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.red.shade200),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.error_outline,
                              color: Colors.red.shade600,
                              size: 48,
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'Preview Error',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _error!,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.red.shade700,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: () => _compileAndRenderCode(),
                              child: const Text('Retry'),
                            ),
                          ],
                        ),
                      ),
                    )
                  : Center(
                      child: Container(
                        constraints: const BoxConstraints(
                          maxWidth: 400,
                          maxHeight: 600,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Column(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: const BoxDecoration(
                                  color: Color(0xFF2D2D2D),
                                  borderRadius: BorderRadius.vertical(
                                    top: Radius.circular(12),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 12,
                                      height: 12,
                                      decoration: const BoxDecoration(
                                        color: Colors.red,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Container(
                                      width: 12,
                                      height: 12,
                                      decoration: const BoxDecoration(
                                        color: Colors.orange,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Container(
                                      width: 12,
                                      height: 12,
                                      decoration: const BoxDecoration(
                                        color: Colors.green,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const Spacer(),
                                    const Text(
                                      'Flutter Preview',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Expanded(
                                child: Container(
                                  width: double.infinity,
                                  color: Colors.white,
                                  child: _previewWidget != null
                                      ? _previewWidget!
                                      : const Center(
                                          child: Text('No preview available'),
                                        ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
        ),
      ),
    );
  }
}
*/
