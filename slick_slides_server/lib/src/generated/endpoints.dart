/* AUTOMATICALLY GENERATED CODE DO NOT MODIFY */
/*   To generate run: "serverpod generate"    */

// ignore_for_file: library_private_types_in_public_api
// ignore_for_file: public_member_api_docs
// ignore_for_file: implementation_imports
// ignore_for_file: use_super_parameters
// ignore_for_file: type_literal_in_constant_pattern

// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'package:serverpod/serverpod.dart' as _i1;
import '../endpoints/deck_endpoint.dart' as _i2;
import '../endpoints/remote_endpoint.dart' as _i3;
import 'package:slick_slides_server/src/generated/remote_action.dart' as _i4;
import 'package:slick_slides_server/src/generated/deck_update.dart' as _i5;

class Endpoints extends _i1.EndpointDispatch {
  @override
  void initializeEndpoints(_i1.Server server) {
    var endpoints = <String, _i1.Endpoint>{
      'deck': _i2.DeckEndpoint()
        ..initialize(
          server,
          'deck',
          null,
        ),
      'remote': _i3.RemoteEndpoint()
        ..initialize(
          server,
          'remote',
          null,
        ),
    };
    connectors['deck'] = _i1.EndpointConnector(
      name: 'deck',
      endpoint: endpoints['deck']!,
      methodConnectors: {
        'actions': _i1.StreamingMethodConnector(
          name: 'actions',
          params: {},
          inputStreams: {},
          outputStream:
              _i1.StreamDescription<_i4.RemoteAction>(name: 'actions'),
          call: (
            _i1.Session session,
            Map<String, dynamic> params,
            Map<String, dynamic> inputStreams,
            _i1.OutputStreamContext? outputStream,
          ) async =>
              outputStream?.addStream(
                  (endpoints['deck'] as _i2.DeckEndpoint).actions(session)),
        )
      },
    );
    connectors['remote'] = _i1.EndpointConnector(
      name: 'remote',
      endpoint: endpoints['remote']!,
      methodConnectors: {
        'next': _i1.MethodConnector(
          name: 'next',
          params: {},
          call: (
            _i1.Session session,
            Map<String, dynamic> params,
          ) async =>
              (endpoints['remote'] as _i3.RemoteEndpoint).next(session),
        ),
        'previous': _i1.MethodConnector(
          name: 'previous',
          params: {},
          call: (
            _i1.Session session,
            Map<String, dynamic> params,
          ) async =>
              (endpoints['remote'] as _i3.RemoteEndpoint).previous(session),
        ),
        'deckUpdates': _i1.StreamingMethodConnector(
          name: 'deckUpdates',
          params: {},
          inputStreams: {},
          outputStream:
              _i1.StreamDescription<_i5.DeckState>(name: 'deckUpdates'),
          call: (
            _i1.Session session,
            Map<String, dynamic> params,
            Map<String, dynamic> inputStreams,
            _i1.OutputStreamContext? outputStream,
          ) async =>
              outputStream?.addStream(
                  (endpoints['remote'] as _i3.RemoteEndpoint)
                      .deckUpdates(session)),
        ),
      },
    );
  }
}
