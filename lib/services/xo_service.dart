import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'dart:math';

enum GameState { waiting, playing, finished }

class XOService extends ChangeNotifier {
  final FirebaseDatabase _db = FirebaseDatabase.instance;

  String? _playerName;
  String? _playerId;

  String? get playerName => _playerName;
  String? get playerId => _playerId;

  int _onlineCount = 0;
  int get onlineCount => _onlineCount;

  // Current Room State
  String? currentRoomId;
  Map<dynamic, dynamic>? currentRoomData;

  XOService() {
    _listenToOnlineCount();
  }

  void initializePlayer(String id, String name) {
    _playerId = id;
    _playerName = name.trim();
    _setOnlinePresence();
    notifyListeners();
  }

  void _setOnlinePresence() {
    if (_playerId == null) return;
    final ref = _db.ref('xo_online_players/$_playerId');
    ref.set(true);
    ref.onDisconnect().remove();
  }

  void _listenToOnlineCount() {
    _db.ref('xo_online_players').onValue.listen((event) {
      if (event.snapshot.exists) {
        _onlineCount = (event.snapshot.value as Map).length;
      } else {
        _onlineCount = 0;
      }
      notifyListeners();
    });
  }

  // --- Matchmaking ---

  Future<String> createRoom(int maxRounds) async {
    if (_playerId == null || _playerName == null)
      throw Exception('Player not initialized');

    // Generate 6 digit code
    final rnd = Random();
    String roomId = (100000 + rnd.nextInt(900000)).toString();

    // Ensure uniqueness
    var snapshot = await _db.ref('xo_rooms/$roomId').get();
    while (snapshot.exists) {
      roomId = (100000 + rnd.nextInt(900000)).toString();
      snapshot = await _db.ref('xo_rooms/$roomId').get();
    }

    currentRoomId = roomId;
    await _db.ref('xo_rooms/$roomId').set({
      'hostId': _playerId,
      'hostName': _playerName,
      'guestId': null,
      'guestName': null,
      'state': 'waiting', // waiting, playing, finished
      'board': List.generate(9, (_) => '').toList(),
      'currentTurn': 'X',
      'hostWins': 0,
      'guestWins': 0,
      'targetWins': maxRounds,
      'hostSymbol': 'X',
      'guestSymbol': 'O',
      'isPublic': false,
      'createdAt': ServerValue.timestamp,
    });

    _listenToRoom(roomId);
    return roomId;
  }

  Future<bool> joinRoom(String roomId) async {
    if (_playerId == null || _playerName == null)
      throw Exception('Player not initialized');

    final ref = _db.ref('xo_rooms/$roomId');
    final snapshot = await ref.get();

    if (!snapshot.exists) return false;

    final data = snapshot.value as Map<dynamic, dynamic>;
    if (data['guestId'] != null && data['guestId'] != _playerId) {
      return false; // Room full
    }

    await ref.update({
      'guestId': _playerId,
      'guestName': _playerName,
      'state': 'playing',
      'isPublic': false, // Hide from global if it was public
    });

    currentRoomId = roomId;
    _listenToRoom(roomId);
    return true;
  }

  Future<void> makeRoomPublic() async {
    if (currentRoomId != null) {
      await _db.ref('xo_rooms/$currentRoomId').update({'isPublic': true});
    }
  }

  Stream<Map<dynamic, dynamic>> getPublicRooms() {
    return _db
        .ref('xo_rooms')
        .orderByChild('isPublic')
        .equalTo(true)
        .onValue
        .map((event) {
          if (!event.snapshot.exists) return {};
          return event.snapshot.value as Map<dynamic, dynamic>;
        });
  }

  void _listenToRoom(String roomId) {
    _db.ref('xo_rooms/$roomId').onValue.listen((event) {
      if (event.snapshot.exists) {
        currentRoomData = event.snapshot.value as Map<dynamic, dynamic>;
        notifyListeners();
      } else {
        currentRoomData = null;
        currentRoomId = null;
        notifyListeners();
      }
    });
  }

  // --- Game Logic ---

  Future<void> makeMove(int index) async {
    if (currentRoomId == null || currentRoomData == null) return;
    if (currentRoomData!['state'] != 'playing') return;

    List<dynamic> board = List.from(
      currentRoomData!['board'] ?? List.generate(9, (_) => ''),
    );
    if (board[index].toString().isNotEmpty) return; // Cell taken

    String currentTurn = currentRoomData!['currentTurn'];
    String mySymbol = currentRoomData!['hostId'] == _playerId
        ? currentRoomData!['hostSymbol']
        : currentRoomData!['guestSymbol'];

    if (currentTurn != mySymbol) return; // Not my turn

    board[index] = mySymbol;
    String nextTurn = mySymbol == 'X' ? 'O' : 'X';

    Map<String, dynamic> updates = {'board': board, 'currentTurn': nextTurn};

    // Check winner
    String? winner = _checkWinner(board.cast<String>());
    if (winner != null) {
      int hostWins = currentRoomData!['hostWins'] ?? 0;
      int guestWins = currentRoomData!['guestWins'] ?? 0;
      int targetWins = currentRoomData!['targetWins'] ?? 3;

      updates['lastWinner'] = winner; // Record winner for next round

      if (winner == currentRoomData!['hostSymbol']) {
        hostWins++;
        updates['hostWins'] = hostWins;
      } else if (winner == currentRoomData!['guestSymbol']) {
        guestWins++;
        updates['guestWins'] = guestWins;
      }

      if (hostWins >= targetWins || guestWins >= targetWins) {
        updates['state'] = 'finished';
      } else {
        updates['state'] = 'waiting_next';
      }
    } else if (!board.contains('')) {
      // Draw - last winner field remains same or we can alternate
      updates['state'] = 'waiting_next';
    }

    await _db.ref('xo_rooms/$currentRoomId').update(updates);
  }

  Future<void> resetBoardForNextMatch() async {
    if (currentRoomId == null || currentRoomData == null) return;

    // Turn determined by last winner, if none (first game or draw logic), default to X
    String nextTurn = currentRoomData!['lastWinner'] ?? 'X';

    // Only the host should ideally trigger this to avoid race conditions, but either works.
    await _db.ref('xo_rooms/$currentRoomId').update({
      'board': List.generate(9, (_) => ''),
      'currentTurn': nextTurn, 
      'state': 'playing',
    });
  }

  String? _checkWinner(List<String> b) {
    const lines = [
      [0, 1, 2], [3, 4, 5], [6, 7, 8], // rows
      [0, 3, 6], [1, 4, 7], [2, 5, 8], // cols
      [0, 4, 8], [2, 4, 6], // diagonals
    ];
    for (var l in lines) {
      if (b[l[0]].isNotEmpty && b[l[0]] == b[l[1]] && b[l[1]] == b[l[2]]) {
        return b[l[0]];
      }
    }
    return null;
  }

  Future<void> leaveRoom() async {
    if (currentRoomId != null) {
      final isHost = currentRoomData?['hostId'] == _playerId;

      if (isHost) {
        // Destroy room
        await _db.ref('xo_rooms/$currentRoomId').remove();
        await _db.ref('xo_chats/$currentRoomId').remove();
      } else {
        // Guest leaves
        await _db.ref('xo_rooms/$currentRoomId').update({
          'guestId': null,
          'guestName': null,
          'state': 'waiting',
          'board': List.generate(9, (_) => '').toList(),
          'hostWins': 0,
          'guestWins': 0,
        });
      }

      currentRoomId = null;
      currentRoomData = null;
      notifyListeners();
    }
  }

  // --- Chat ---

  Stream<DatabaseEvent> getChatStream() {
    return _db.ref('xo_chats/$currentRoomId').orderByChild('timestamp').onValue;
  }

  Future<void> sendMessage(String text) async {
    if (currentRoomId == null || _playerName == null || text.trim().isEmpty)
      return;
    await _db.ref('xo_chats/$currentRoomId').push().set({
      'senderId': _playerId,
      'senderName': _playerName,
      'text': text.trim(),
      'timestamp': ServerValue.timestamp,
    });
  }
}
