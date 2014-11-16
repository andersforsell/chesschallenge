class User {
  String name;
  int avatar;
  int score = 0;

  User(this.name, this.avatar);

  User.fromMap(Map map) {
    name = map['name'];
    avatar = map['avatar'];
    score = map['score'];
  }

  Map toJson() {
    Map map = new Map();
    map['name'] = name;
    map['avatar'] = avatar;
    map['score'] = score;
    return map;
  }
}

class Messages {
  static const String AVAILABLEUSERS = 'au';

  static const String CHALLENGE = 'cc';

  static const String CHECKMATE = 'cm';

  static const String GAMEOVER = 'go';

  static const String GETSTATUS = 'gs';

  static const String LOGIN = 'li';

  static const String LEADERBOARD = 'lb';

  static const String PENDINGCHALLENGE = 'pc';

  static const String PGN = 'pg';

  static const String STARTCHALLENGE = 'ss';

  static const String STOPCHALLENGE = 'sc';

}