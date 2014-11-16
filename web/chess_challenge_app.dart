/* Copyright (c) 2014, Anders Forsell (aforsell1971@gmail.com)
 */

import 'package:polymer/polymer.dart';
import 'package:chesschallenge/shared.dart';

/**
 * The Chess Challenge App component
 */
@CustomTag('chess-challenge-app')
class ChessChallengeApp extends PolymerElement {
  @published User user;
  /// [true] if min-width is 900px
  @observable bool wide = true;
  @observable String selected = 'login';

  ChessChallengeApp.created() : super.created();

  void selectedChanged(String oldValue, String newValue) {
    if (selected == 'board') {
      async((_) => $['board'].resize());
    }
  }

}
