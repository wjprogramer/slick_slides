import 'dart:async';

import 'package:serverpod/serverpod.dart';
import 'package:slick_slides_server/src/endpoints/remote_endpoint.dart';
import 'package:slick_slides_server/src/generated/protocol.dart';

const kDeckUpdatesChannel = 'deck updates';
DeckState currentDeckState = DeckState(isConnected: false);

class DeckEndpoint extends Endpoint {
  Stream<RemoteAction> actions(Session session) async* {
    currentDeckState = DeckState(isConnected: true);
    session.messages.postMessage(
      kDeckUpdatesChannel,
      currentDeckState,
    );

    var actionStream =
        session.messages.getStream<RemoteAction>(kRemoteActionsChannel);
    await for (var action in actionStream) {
      print('Sending action: $action');
      yield action;
    }

    currentDeckState = DeckState(isConnected: false);
    session.messages.postMessage(
      kDeckUpdatesChannel,
      currentDeckState,
    );
  }
}
