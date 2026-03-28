import 'package:flutter_riverpod/flutter_riverpod.dart';

class ChatMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;

  ChatMessage({
    required this.text,
    required this.isUser,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();
}

class AiChatState {
  final List<ChatMessage> messages;
  final bool isLoading;

  const AiChatState({
    this.messages = const [],
    this.isLoading = false,
  });

  AiChatState copyWith({
    List<ChatMessage>? messages,
    bool? isLoading,
  }) {
    return AiChatState(
      messages: messages ?? this.messages,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class AiChatNotifier extends StateNotifier<AiChatState> {
  AiChatNotifier() : super(const AiChatState());

  Future<void> sendMessage(String text) async {
    // Add user message
    final updatedMessages = [
      ...state.messages,
      ChatMessage(text: text, isUser: true),
    ];
    state = state.copyWith(messages: updatedMessages, isLoading: true);

    try {
      // TODO: Replace with actual AI API call
      await Future.delayed(const Duration(seconds: 1));

      final aiResponse = ChatMessage(
        text:
            'I\'m your KVM ERP AI assistant. I can help you with student data, attendance reports, fee status, and more. This is a placeholder response — connect me to an AI backend to get started!',
        isUser: false,
      );

      state = state.copyWith(
        messages: [...state.messages, aiResponse],
        isLoading: false,
      );
    } catch (e) {
      final errorMsg = ChatMessage(
        text: 'Sorry, something went wrong. Please try again.',
        isUser: false,
      );
      state = state.copyWith(
        messages: [...state.messages, errorMsg],
        isLoading: false,
      );
    }
  }

  void clearChat() {
    state = const AiChatState();
  }
}

final aiChatProvider =
    StateNotifierProvider<AiChatNotifier, AiChatState>(
        (ref) => AiChatNotifier());
