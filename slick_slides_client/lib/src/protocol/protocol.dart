/* AUTOMATICALLY GENERATED CODE DO NOT MODIFY */
/*   To generate run: "serverpod generate"    */

// ignore_for_file: library_private_types_in_public_api
// ignore_for_file: public_member_api_docs
// ignore_for_file: implementation_imports
// ignore_for_file: use_super_parameters
// ignore_for_file: type_literal_in_constant_pattern

library protocol; // ignore_for_file: no_leading_underscores_for_library_prefixes

import 'package:serverpod_client/serverpod_client.dart' as _i1;
import 'deck_update.dart' as _i2;
import 'remote_action.dart' as _i3;
export 'deck_update.dart';
export 'remote_action.dart';
export 'client.dart';

class Protocol extends _i1.SerializationManager {
  Protocol._();

  factory Protocol() => _instance;

  static final Protocol _instance = Protocol._();

  @override
  T deserialize<T>(
    dynamic data, [
    Type? t,
  ]) {
    t ??= T;
    if (t == _i2.DeckState) {
      return _i2.DeckState.fromJson(data) as T;
    }
    if (t == _i3.RemoteAction) {
      return _i3.RemoteAction.fromJson(data) as T;
    }
    if (t == _i1.getType<_i2.DeckState?>()) {
      return (data != null ? _i2.DeckState.fromJson(data) : null) as T;
    }
    if (t == _i1.getType<_i3.RemoteAction?>()) {
      return (data != null ? _i3.RemoteAction.fromJson(data) : null) as T;
    }
    return super.deserialize<T>(data, t);
  }

  @override
  String? getClassNameForObject(Object data) {
    if (data is _i2.DeckState) {
      return 'DeckState';
    }
    if (data is _i3.RemoteAction) {
      return 'RemoteAction';
    }
    return super.getClassNameForObject(data);
  }

  @override
  dynamic deserializeByClassName(Map<String, dynamic> data) {
    if (data['className'] == 'DeckState') {
      return deserialize<_i2.DeckState>(data['data']);
    }
    if (data['className'] == 'RemoteAction') {
      return deserialize<_i3.RemoteAction>(data['data']);
    }
    return super.deserializeByClassName(data);
  }
}
