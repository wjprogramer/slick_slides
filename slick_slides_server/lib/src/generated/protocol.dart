/* AUTOMATICALLY GENERATED CODE DO NOT MODIFY */
/*   To generate run: "serverpod generate"    */

// ignore_for_file: library_private_types_in_public_api
// ignore_for_file: public_member_api_docs
// ignore_for_file: implementation_imports
// ignore_for_file: use_super_parameters
// ignore_for_file: type_literal_in_constant_pattern

library protocol; // ignore_for_file: no_leading_underscores_for_library_prefixes

import 'package:serverpod/serverpod.dart' as _i1;
import 'package:serverpod/protocol.dart' as _i2;
import 'deck_update.dart' as _i3;
import 'remote_action.dart' as _i4;
export 'deck_update.dart';
export 'remote_action.dart';

class Protocol extends _i1.SerializationManagerServer {
  Protocol._();

  factory Protocol() => _instance;

  static final Protocol _instance = Protocol._();

  static final List<_i2.TableDefinition> targetTableDefinitions = [
    ..._i2.Protocol.targetTableDefinitions
  ];

  @override
  T deserialize<T>(
    dynamic data, [
    Type? t,
  ]) {
    t ??= T;
    if (t == _i3.DeckState) {
      return _i3.DeckState.fromJson(data) as T;
    }
    if (t == _i4.RemoteAction) {
      return _i4.RemoteAction.fromJson(data) as T;
    }
    if (t == _i1.getType<_i3.DeckState?>()) {
      return (data != null ? _i3.DeckState.fromJson(data) : null) as T;
    }
    if (t == _i1.getType<_i4.RemoteAction?>()) {
      return (data != null ? _i4.RemoteAction.fromJson(data) : null) as T;
    }
    try {
      return _i2.Protocol().deserialize<T>(data, t);
    } on _i1.DeserializationTypeNotFoundException catch (_) {}
    return super.deserialize<T>(data, t);
  }

  @override
  String? getClassNameForObject(Object data) {
    if (data is _i3.DeckState) {
      return 'DeckState';
    }
    if (data is _i4.RemoteAction) {
      return 'RemoteAction';
    }
    return super.getClassNameForObject(data);
  }

  @override
  dynamic deserializeByClassName(Map<String, dynamic> data) {
    if (data['className'] == 'DeckState') {
      return deserialize<_i3.DeckState>(data['data']);
    }
    if (data['className'] == 'RemoteAction') {
      return deserialize<_i4.RemoteAction>(data['data']);
    }
    return super.deserializeByClassName(data);
  }

  @override
  _i1.Table? getTableForType(Type t) {
    {
      var table = _i2.Protocol().getTableForType(t);
      if (table != null) {
        return table;
      }
    }
    return null;
  }

  @override
  List<_i2.TableDefinition> getTargetTableDefinitions() =>
      targetTableDefinitions;

  @override
  String getModuleName() => 'slick_slides';
}
