/* Copyright (c) 2014, Anders Forsell (aforsell1971@gmail.com)
 */

import 'dart:html';
import 'dart:async';
import 'dart:math';
import 'dart:convert' show JSON;
import 'package:polymer/polymer.dart';
import 'package:chessboard/chess_board.dart';
import 'package:chesschallenge/shared.dart';
import 'package:firebase/firebase.dart' show Firebase;

/**
 * The Chess Challenge Board component
 */
@CustomTag('chess-challenge-board')
class ChessChallengeBoard extends PolymerElement {
  @published User user;

  @observable List<User> leaderBoard = toObservable([]);

  @observable List<User> topList = toObservable([]);

  @observable List<User> startChallengeUsers = toObservable([]);

  @observable String winnerTime;

  @observable String challengeTime = '';

  @observable String startChallengeStatus = '';

  @observable String startChallengeBtnLabel = 'Start';

  @observable String errorMessage = '';

  @observable bool challengeOngoing = false;

  Stopwatch _stopWatch = new Stopwatch();

  Timer _challengeTimer;

  Timer _pendingChallengeTimer;

  ChessBoard _chessBoard;

  WebSocket _webSocket;

  ChessChallengeBoard.created() : super.created();

  @override
  void domReady() {
    var navicon = $['navicon'];
    var drawerPanel = $['drawerPanel'];
    _chessBoard = $['chess_board'];

    resize();

    window.onResize.listen((e) {
      resize();
    });

    navicon.onClick.listen((e) => drawerPanel.togglePanel());
  }

  void userChanged(User oldValue, User newValue) {
    _connect();
    _connectFirebase();
  }


  void _connect() {
    Uri uri = Uri.parse(window.location.href);
    var port = uri.port != 8080 ? 80 : 9090;

    _webSocket = new WebSocket('ws://${uri.host}:${port}/ws')
        ..onMessage.listen(_receive)
        ..onOpen.listen((event) {
          showStartChallenge();
        })
        ..onClose.listen((event) {
          errorMessage = '${event.reason} (${event.code})';
          async((_) => $['connection_error'].toggle());
        })
        ..onError.listen((event) {
          print('Websocket error: ${event}');
          errorMessage = '';
          async((_) => $['connection_error'].toggle());
        });
  }

  void _connectFirebase() {
    var fb = new Firebase('${firebaseUrl}/toplist');
    fb.onValue.listen((event) {
      List users = event.snapshot.val();
      if (users != null) topList =
          users.map((u) => new User.fromMap(u)).toList();
    });
  }

  void connectionRetryClicked(Event event, var detail, Node target) {
    async((_) => _connect());
  }

  void showStartChallengeDialog() {
    $['start_challenge'].toggle();
  }

  void _receive(MessageEvent event) {
    String message = event.data;
    if (message.startsWith(Messages.PGN)) {
      var pgn = message.substring(Messages.PGN.length);
      print('Chess problem received: ' + pgn);
      ChessBoard chessBoard = $['chess_board']..position = pgn;
      async((_) {
        chessBoard.undo();
        chessBoard.reversed = chessBoard.turn == ChessBoard.BLACK;
        async((_) => chessBoard.refresh());
      });
    } else if (message == Messages.STARTCHALLENGE) {
      print('Start challenge message received');
      challengeOngoing = true;
      $['challenge_pending'].dismiss();
      $['stop_challenge'].style.display = 'block';
      _stopWatch
          ..reset()
          ..start();
      _challengeTimer =
          new Timer.periodic(new Duration(seconds: 1), updateChallengeTime);
    } else if (message.startsWith(Messages.LEADERBOARD)) {
      print('Leaderboard message received');
      List leaders =
          JSON.decode(message.substring(Messages.LEADERBOARD.length));
      leaderBoard = leaders.map((u) => new User.fromMap(u)).toList();
    } else if (message.startsWith(Messages.GAMEOVER)) {
      print('Gameover message received');
      int time = int.parse(message.substring(Messages.GAMEOVER.length));
      showResultsDialog(time);
    } else if (message.startsWith(Messages.PENDINGCHALLENGE)) {
      print('Pending challenge message received');
      String msg = message.substring(Messages.PENDINGCHALLENGE.length);
      int index = msg.indexOf(":");
      int seconds = int.parse(msg.substring(0, index));

      startChallengeUsers = getUsersFromJson(msg.substring(index + 1));

      startChallengeStatus =
          'A new challenge is starting in ${seconds} seconds...';
      startChallengeBtnLabel = 'Join';

      _pendingChallengeTimer =
          new Timer.periodic(new Duration(milliseconds: 1000), (timer) {
        seconds--;
        if (seconds == 0) {
          timer.cancel();
        } else {
          startChallengeStatus =
              'Challenge is starting in ${seconds} seconds...';
        }
      });

    } else if (message.startsWith(Messages.AVAILABLEUSERS)) {
      var users = message.substring(Messages.AVAILABLEUSERS.length);
      print('Available users message received ${users}');
      startChallengeUsers = getUsersFromJson(users);

      if (startChallengeUsers.length > 0) {
        startChallengeStatus = 'Challenge the following users:';
      } else {
        startChallengeStatus = 'No users available, challenge yourself!';
      }
      startChallengeBtnLabel = 'Start';
    }
  }

  void showResultsDialog(int time) {
    challengeOngoing = false;
    _challengeTimer.cancel();
    _stopWatch.stop();
    challengeTime = '';
    winnerTime = '${(time/1000).toStringAsFixed(1)} s';
    challengeTime = '';
    async((_) {
      $['stop_challenge'].style.display = 'none';
      $['result'].toggle();
    });
  }

  void resize() {
    var mainHeaderPanel = $['main_header_panel'];
    var mainToolbar = $['main_toolbar'];

    ChessBoard chessBoard = $['chess_board'];
    var paddingX2 = 20 * 2;
    int height =
        mainHeaderPanel.clientHeight -
        mainToolbar.clientHeight -
        paddingX2;
    int width = mainHeaderPanel.clientWidth - paddingX2;
    int newWidth = min(height, width);
    if (newWidth > 0) {
      chessBoard.style
          ..width = '${newWidth}px'
          ..height = chessBoard.style.width;
      chessBoard.resize();
    }
  }

  void onMove(CustomEvent event, detail, target) {
    ChessBoard chessBoard = event.target;
    if (chessBoard.gameStatus != 'checkmate') {
      $['try_again'].show();
      chessBoard.undo();
      chessBoard.refresh();
    } else {
      _webSocket.send(Messages.CHECKMATE);
    }
  }

  void stopChallengeClicked(Event event, var detail, Node target) {
    if (_stopWatch.isRunning) {
      $['confirm_stop_challenge'].toggle();
    }
  }

  void startChallengeClicked(Event event, var detail, Node target) {
    async((_) {
      $['start_challenge'].opened = false;
      startChallenge();
    });
  }

  void showAbout() {
    async((_) => $['about_dialog'].toggle());
  }

  void startChallenge() {
    if (_pendingChallengeTimer != null) _pendingChallengeTimer.cancel();
    _webSocket.send(Messages.CHALLENGE);
    async((_) => $['challenge_pending'].show());
  }

  void stopChallenge() {
    _webSocket.send(Messages.STOPCHALLENGE);
    showStartChallenge();
  }

  void resultOkClicked(Event event, var detail, Node target) {
    showStartChallenge();
  }

  void showStartChallenge() {
    if (_challengeTimer != null) {
      _challengeTimer.cancel();
    }
    _stopWatch.stop();
    leaderBoard = [];
    challengeTime = '';
    challengeOngoing = false;
    async((_) {
      $['stop_challenge'].style.display = 'none';
      _webSocket.send(Messages.LOGIN + JSON.encode(user));
      showStartChallengeDialog();
    });
  }

  void confirmStopChallengeClicked(Event event, var detail, Node target) {
    stopChallenge();
  }

  void updateChallengeTime(Timer timer) {
    challengeTime =
        '${(_stopWatch.elapsedMilliseconds/1000).toStringAsFixed(0)} s';
  }

  /// Returns the player info for the [side] ('Black' or 'White')
  String getPlayerInfo(String side) {
    if (_chessBoard == null) {
      return '';
    }
    var name = _chessBoard.header[side];
    if (name == null) {
      return '';
    }
    var rating = _chessBoard.header[side + 'Elo'];
    if (rating != null) {
      return '${name} (${rating})';
    }
    return name;
  }
}
