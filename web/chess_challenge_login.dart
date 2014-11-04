/* Copyright (c) 2014, Anders Forsell (aforsell1971@gmail.com)
 */

import 'package:polymer/polymer.dart';
import 'dart:html';
import 'dart:math';
import 'package:chesschallenge/shared.dart';

/**
 * The Chess Challenge Login component
 */
@CustomTag('chess-challenge-login')
class ChessChallengeLogin extends PolymerElement {
  @published bool wide;

  @published User user;

  @observable int selectedAvatar;

  ChessChallengeLogin.created() : super.created();

  void keypressAction(KeyboardEvent event, var detail, Node target) {
    var code = event.keyCode;
    if (code == 13) {
      var target = event.target;
      if (target == $['name']) {
        $['name'].blur();
      }
    }
  }

  @override
  void domReady() {
    _selectRandomAvatar();
  }

  void _selectRandomAvatar() {
    selectedAvatar = new Random().nextInt(16);
  }

  void handleLogin(Event event, var detail, Node target) {
    user = new User($['name'].value, selectedAvatar + 1);
    this.parent.setAttribute('selected', 'board');
  }

}