/* AUTOMATICALLY GENERATED CODE DO NOT MODIFY */
/*   To generate run: "serverpod generate"    */

// ignore_for_file: library_private_types_in_public_api
// ignore_for_file: public_member_api_docs
// ignore_for_file: implementation_imports
// ignore_for_file: use_super_parameters
// ignore_for_file: type_literal_in_constant_pattern

// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'package:serverpod_client/serverpod_client.dart' as _i1;

abstract class DeckState implements _i1.SerializableModel {
  DeckState._({
    required this.isConnected,
    this.presenterNote,
  });

  factory DeckState({
    required bool isConnected,
    String? presenterNote,
  }) = _DeckStateImpl;

  factory DeckState.fromJson(Map<String, dynamic> jsonSerialization) {
    return DeckState(
      isConnected: jsonSerialization['isConnected'] as bool,
      presenterNote: jsonSerialization['presenterNote'] as String?,
    );
  }

  bool isConnected;

  String? presenterNote;

  DeckState copyWith({
    bool? isConnected,
    String? presenterNote,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      'isConnected': isConnected,
      if (presenterNote != null) 'presenterNote': presenterNote,
    };
  }

  @override
  String toString() {
    return _i1.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _DeckStateImpl extends DeckState {
  _DeckStateImpl({
    required bool isConnected,
    String? presenterNote,
  }) : super._(
          isConnected: isConnected,
          presenterNote: presenterNote,
        );

  @override
  DeckState copyWith({
    bool? isConnected,
    Object? presenterNote = _Undefined,
  }) {
    return DeckState(
      isConnected: isConnected ?? this.isConnected,
      presenterNote:
          presenterNote is String? ? presenterNote : this.presenterNote,
    );
  }
}
