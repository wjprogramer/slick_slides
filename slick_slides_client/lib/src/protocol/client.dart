/* AUTOMATICALLY GENERATED CODE DO NOT MODIFY */
/*   To generate run: "serverpod generate"    */

// ignore_for_file: library_private_types_in_public_api
// ignore_for_file: public_member_api_docs
// ignore_for_file: implementation_imports
// ignore_for_file: use_super_parameters
// ignore_for_file: type_literal_in_constant_pattern

// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'package:serverpod_client/serverpod_client.dart' as _i1;
import 'dart:async' as _i2;
import 'package:slick_slides_client/src/protocol/remote_action.dart' as _i3;
import 'package:slick_slides_client/src/protocol/deck_update.dart' as _i4;
import 'protocol.dart' as _i5;

/// {@category Endpoint}
class EndpointDeck extends _i1.EndpointRef {
  EndpointDeck(_i1.EndpointCaller caller) : super(caller);

  @override
  String get name => 'deck';

  _i2.Stream<_i3.RemoteAction> actions() =>
      caller.callAndListenToStreamingEndpoint<_i3.RemoteAction>(
        'deck',
        'actions',
        {},
        {},
      );
}

/// {@category Endpoint}
class EndpointRemote extends _i1.EndpointRef {
  EndpointRemote(_i1.EndpointCaller caller) : super(caller);

  @override
  String get name => 'remote';

  _i2.Future<void> next() => caller.callServerEndpoint<void>(
        'remote',
        'next',
        {},
      );

  _i2.Future<void> previous() => caller.callServerEndpoint<void>(
        'remote',
        'previous',
        {},
      );

  _i2.Stream<_i4.DeckState> deckUpdates() =>
      caller.callAndListenToStreamingEndpoint<_i4.DeckState>(
        'remote',
        'deckUpdates',
        {},
        {},
      );
}

class Client extends _i1.ServerpodClient {
  Client(
    String host, {
    dynamic securityContext,
    _i1.AuthenticationKeyManager? authenticationKeyManager,
    Duration? streamingConnectionTimeout,
    Duration? connectionTimeout,
    Function(
      _i1.MethodCallContext,
      Object,
      StackTrace,
    )? onFailedCall,
    Function(_i1.MethodCallContext)? onSucceededCall,
  }) : super(
          host,
          _i5.Protocol(),
          securityContext: securityContext,
          authenticationKeyManager: authenticationKeyManager,
          streamingConnectionTimeout: streamingConnectionTimeout,
          connectionTimeout: connectionTimeout,
          onFailedCall: onFailedCall,
          onSucceededCall: onSucceededCall,
        ) {
    deck = EndpointDeck(this);
    remote = EndpointRemote(this);
  }

  late final EndpointDeck deck;

  late final EndpointRemote remote;

  @override
  Map<String, _i1.EndpointRef> get endpointRefLookup => {
        'deck': deck,
        'remote': remote,
      };

  @override
  Map<String, _i1.ModuleEndpointCaller> get moduleLookup => {};
}
