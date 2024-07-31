import 'dart:async';

import 'package:serverpod/serverpod.dart';
import 'package:slick_slides_server/src/endpoints/deck_endpoint.dart';
import 'package:slick_slides_server/src/generated/protocol.dart';

const kRemoteActionsChannel = 'remote actions';

class RemoteEndpoint extends Endpoint {
  Future<void> next(Session session) async {
    session.messages.postMessage(
      kRemoteActionsChannel,
      RemoteAction.next,
    );
  }

  Future<void> previous(Session session) async {
    session.messages.postMessage(
      kRemoteActionsChannel,
      RemoteAction.previous,
    );
  }

  Stream<DeckState> deckUpdates(Session session) async* {
    yield currentDeckState;

    var deckUpdateStream =
        session.messages.getStream<DeckState>(kDeckUpdatesChannel);

    await for (var update in deckUpdateStream) {
      yield update;
    }
  }
}
