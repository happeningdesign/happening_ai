import 'dart:convert';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:http/http.dart' as http;

import 'ai_chat_models.dart';

/// ====================== CONFIG ======================
/// Point this to your deployed backend:
const String kBackendBase = 'http://localhost:8080';
const String kEndpointPath =
    '/api/ai/generate-code'; // POST { userPrompt: string }

class AiChatState {
  final List<ChatMessage> messages;
  final bool loading;
  final String? error;

  const AiChatState({
    required this.messages,
    required this.loading,
    required this.error,
  });

  factory AiChatState.initial() => AiChatState(
        messages: <ChatMessage>[
          ChatMessage(
            Role.assistant,
            '👋 **Welcome to AI Design Assistant!**\n\nI\'m here to help you create beautiful Flutter UIs. Just describe what you want to build and I\'ll generate clean, modern code that follows best practices.\n\n**Try something like:**\n- "Create a login screen with email and password fields"\n- "Design a modern card component for a social media app"\n- "Build a responsive navigation drawer"\n\nWhat would you like to create today?',
          ),
        ],
        loading: false,
        error: null,
      );

  AiChatState copyWith({
    List<ChatMessage>? messages,
    bool? loading,
    String? error,
  }) {
    return AiChatState(
      messages: messages ?? this.messages,
      loading: loading ?? this.loading,
      error: error,
    );
  }
}

class AiChatCubit extends Cubit<AiChatState> {
  AiChatCubit() : super(AiChatState.initial());

  Future<void> sendPrompt(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || state.loading) return;

    final nextMessages = List<ChatMessage>.from(state.messages)
      ..add(ChatMessage(Role.user, trimmed));
    emit(state.copyWith(messages: nextMessages, loading: true, error: null));

    try {
      final uri = Uri.parse('$kBackendBase$kEndpointPath');
      final resp = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'userPrompt': trimmed}),
      );

      if (resp.statusCode != 200) {
        final errorMsg = 'Backend error ${resp.statusCode}: ${resp.body}';
        emit(
          state.copyWith(
            error: errorMsg,
            loading: false,
            messages: List<ChatMessage>.from(state.messages)
              ..add(ChatMessage(Role.assistant, '⚠️ $errorMsg')),
          ),
        );
        return;
      }

      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      final markdown = (data['code'] ?? '').toString().trim();
      final reply = markdown.isEmpty ? '_No response returned._' : markdown;

      emit(
        state.copyWith(
          loading: false,
          messages: List<ChatMessage>.from(state.messages)
            ..add(ChatMessage(Role.assistant, reply)),
        ),
      );
    } catch (e) {
      final errorMsg = 'Request failed: $e';
      emit(
        state.copyWith(
          error: errorMsg,
          loading: false,
          messages: List<ChatMessage>.from(state.messages)
            ..add(ChatMessage(Role.assistant, '⚠️ $errorMsg')),
        ),
      );
    }
  }
}
