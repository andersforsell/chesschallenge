import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_web_socket/shelf_web_socket.dart';
import 'dart:io';
import 'package:chesschallenge/shared.dart';
import 'dart:convert' show JSON, LATIN1, LineSplitter, UTF8;
import 'dart:async';
import 'dart:math';

Map<WebSocket, User> users = {};

List<Challenge> challenges = [];

List<String> pgnGames = [];

const GAMES_PER_CHALLENGE = 5;

const PENDING_CHALLENGE_TIME = 10;

Challenge pendingChallenge = null;

Stopwatch pendingChallengeStopwatch = new Stopwatch();

class Challenge {
  List<WebSocket> webSockets = [];
  List<String> games = [];
  Stopwatch stopWatch = new Stopwatch();

  Challenge() {
    addRandomGames(GAMES_PER_CHALLENGE);
  }

  void addRandomGames(int count) {
    var rnd = new Random();
    int length = pgnGames.length;
    for (int i = 0; i < count; i++) {
      int index = rnd.nextInt(length);
      games.add(pgnGames[index]);
    }
  }

  List<User> getUsers() {
    return webSockets.map((ws) => users[ws]).toList();
  }
}

Challenge findChallenge(webSocket) {
  for (var challenge in challenges) {
    if (challenge.webSockets.contains(webSocket)) {
      return challenge;
    }
  }
  return null;
}

void main() {
  readGames('IB1419.pgn');

  var handler = webSocketHandler(onConnection);

  shelf_io.serve(handler, InternetAddress.ANY_IP_V4, 4040).then((server) {
    print('Serving at ws://${server.address.host}:${server.port}');
  });
}

void readGames(String fileName) {
  String pgn = '';

  final file = new File(fileName);
  Stream<List<int>> inputStream = file.openRead();

  inputStream.transform(
      LATIN1.decoder).transform(new LineSplitter()).listen((String line) {
    if (line.trim().isEmpty) {
      if (pgn.contains('1.')) {
        if (pgn.contains('#')) {
          pgnGames.add(pgn);
        }
        pgn = '';
      }
    } else {
      pgn += line + '\n';
    }
  }, onDone: () {
    print('Ready with ${pgnGames.length} challenges.');
  }, onError: (e) {
    print(e.toString());
  });
}

List<User> getLeaderBoard(Challenge challenge) {
  return challenge.getUsers()..sort((u1, u2) => u2.score.compareTo(u1.score));
}

void onConnection(webSocket) {
  webSocket.listen((String message) {
    if (message.startsWith(Messages.LOGIN)) {
      users.remove(webSocket);
      var user =
          new User.fromMap(JSON.decode(message.substring(Messages.LOGIN.length)));
      users.putIfAbsent(webSocket, () => user);
    } else if (message == Messages.CHALLENGE) {
      joinChallenge(webSocket);
    } else if (message == Messages.CHECKMATE) {
      User user = users[webSocket];
      user.score += 1;
      var challenge = findChallenge(webSocket);
      updateLeaderBoard(challenge);
      if (user.score == challenge.games.length) {
        // We have a winner!
        challenge.stopWatch.stop();
        challenges.remove(challenge);
        sendGameOver(challenge);
      } else {
        webSocket.add(Messages.PGN + challenge.games[user.score]);
      }
    } else if (message == Messages.GETSTATUS) {
      if (pendingChallenge != null) {
        List<User> leaderBoard = getLeaderBoard(pendingChallenge);
        int seconds =
            PENDING_CHALLENGE_TIME -
            pendingChallengeStopwatch.elapsed.inSeconds;
        webSocket.add(
            Messages.PENDINGCHALLENGE +
                seconds.toString() +
                ":" +
                JSON.encode(leaderBoard));
      } else {
        List<User> users = getAvailableUsers(webSocket);
        webSocket.add(Messages.AVAILABLEUSERS + JSON.encode(users));
      }
    } else if (message == Messages.STOPCHALLENGE) {
      var challenge = findChallenge(webSocket);
      if (challenge != null) {
        challenge.webSockets.remove(webSocket);
        if (challenge.webSockets.length == 0) {
          challenge.stopWatch.stop();
          challenges.remove(challenge);
        }
        updateLeaderBoard(challenge);
      }
    }
  }, onDone: () => doneHandler(webSocket));
}

/// Return the list of available users except the user
/// corresponding to the given websocket
List<User> getAvailableUsers(webSocket) {
  List<User> availableUsers = [];
  for (var ws in users.keys) {
    if (ws != webSocket && findChallenge(ws) == null) {
      availableUsers.add(users[ws]);
    }
  }
  return availableUsers;
}

void sendGameOver(Challenge challenge) {
  var msg =
      Messages.GAMEOVER +
      challenge.stopWatch.elapsedMilliseconds.toString();
  for (var ws in challenge.webSockets) {
    ws.add(msg);
  }
}

void joinChallenge(dynamic webSocket) {
  leaveChallenge(webSocket);
  if (pendingChallenge == null) {
    pendingChallenge = new Challenge()..webSockets.add(webSocket);
    pendingChallengeStopwatch
        ..reset()
        ..start();
    var timer =
        new Timer.periodic(
            new Duration(seconds: PENDING_CHALLENGE_TIME),
            startChallenge);

  } else if (!pendingChallenge.webSockets.contains(webSocket)) {
    pendingChallenge.webSockets.add(webSocket);
  }
  updateLeaderBoard(pendingChallenge);
}

void updateLeaderBoard(Challenge challenge) {
  List<User> leaderBoard = getLeaderBoard(challenge);
  for (var ws in challenge.webSockets) {
    ws.add(Messages.LEADERBOARD + JSON.encode(leaderBoard));
  }
}

void startChallenge(Timer timer) {
  timer.cancel();
  pendingChallenge.stopWatch.start();
  challenges.add(pendingChallenge);
  updateLeaderBoard(pendingChallenge);
  sendStartChallenge(pendingChallenge);
  sendNewChessProblem(pendingChallenge);
  pendingChallenge = null;
}

void sendStartChallenge(Challenge pendingChallenge) {
  for (var ws in pendingChallenge.webSockets) {
    ws.add(Messages.STARTCHALLENGE);
  }
}

void sendNewChessProblem(Challenge pendingChallenge) {
  for (var ws in pendingChallenge.webSockets) {
    ws.add(Messages.PGN + pendingChallenge.games[0]);
  }
}

void doneHandler(webSocket) {
  leaveChallenge(webSocket);
  users.remove(webSocket);
}

void leaveChallenge(webSocket) {
  var user = users[webSocket];
  user.score = 0;
  var challenge = findChallenge(webSocket);
  if (challenge != null) {
    challenge.webSockets.remove(webSocket);
    if (challenge.webSockets.length == 0) {
      challenges.remove(challenge);
    }
  }
}
