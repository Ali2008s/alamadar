import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:almadar/core/theme.dart';
import 'package:almadar/services/xo_service.dart';
import 'package:almadar/services/focus_sound_service.dart';
import 'package:audioplayers/audioplayers.dart';
import 'dart:async';
import 'dart:math';

class XOGameScreen extends StatefulWidget {
  final bool isBotMode;
  const XOGameScreen({super.key, this.isBotMode = false});

  @override
  State<XOGameScreen> createState() => _XOGameScreenState();
}

class _XOGameScreenState extends State<XOGameScreen>
    with TickerProviderStateMixin {
  final TextEditingController _chatController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final _sendPlayer = AudioPlayer();
  final _receivePlayer = AudioPlayer();
  StreamSubscription? _chatSub;
  bool _isFirstChatLoad = true;
  bool _showChat = true;

  // Bot Mode State
  List<String> _botBoard = List.generate(9, (_) => '');
  String _botTurn = 'X';
  int _botPlayerWins = 0;
  int _botAIWins = 0;
  int _botTargetWins = 3;
  bool _botIsThinking = false;
  bool _botMatchEnded = false;
  bool _botShowingDialog = false;
  String? _lastWinner;

  late AnimationController _glowController;
  late Animation<double> _glowAnim;

  final List<String> _quickPhrases = [
    '🔥 كفووو', '⚡ العب بسرعة', '😅 استعجل', '💪 يا بطل', '😂 حظك رخيص', '❤️ حبيبي',
  ];

  @override
  void initState() {
    super.initState();
    _glowController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);
    _glowAnim = Tween<double>(begin: 0.3, end: 0.8).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );

    if (!widget.isBotMode) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final xoService = Provider.of<XOService>(context, listen: false);
        _chatSub = xoService.getChatStream().listen((event) {
          if (_isFirstChatLoad) {
            _isFirstChatLoad = false;
            return;
          }
          if (event.snapshot.exists) {
            final Map<dynamic, dynamic> msgsRaw =
                event.snapshot.value as Map<dynamic, dynamic>;
            final List<Map<String, dynamic>> messages = msgsRaw.entries.map((e) {
              final m = Map<String, dynamic>.from(e.value as Map);
              m['id'] = e.key?.toString() ?? '';
              return m;
            }).toList();
            messages.sort((a, b) => (a['timestamp'] ?? 0).compareTo(b['timestamp'] ?? 0));

            if (messages.isNotEmpty) {
              final lastMsg = messages.last;
              if (lastMsg['senderId'] != xoService.playerId) {
                _receivePlayer.play(AssetSource('sounds/receive.mp3'));
              }
            }
          }
        });
      });
    }
  }

  @override
  void dispose() {
    _chatController.dispose();
    _scrollController.dispose();
    _glowController.dispose();
    _sendPlayer.dispose();
    _receivePlayer.dispose();
    _chatSub?.cancel();
    super.dispose();
  }

  void _handleCellTap(int index) {
    FocusSoundService.play();
    if (widget.isBotMode) {
      _handleBotMove(index);
    } else {
      Provider.of<XOService>(context, listen: false).makeMove(index);
    }
  }

  void _handleBotMove(int index) async {
    if (_botIsThinking || _botBoard[index].isNotEmpty || _botMatchEnded) return;
    
    setState(() {
      _botBoard[index] = _botTurn;
      _botTurn = (_botTurn == 'X' ? 'O' : 'X');
    });

    final shouldStop = _checkBotWinner();
    if (shouldStop || _botMatchEnded || _botTurn == 'X') return;

    setState(() => _botIsThinking = true);
    await Future.delayed(const Duration(milliseconds: 700));
    if (!mounted || _botMatchEnded) return;

    final aiMove = _findBestMove();
    if (aiMove != -1) {
      setState(() {
        _botBoard[aiMove] = 'O';
        _botTurn = 'X';
        _botIsThinking = false;
      });
      FocusSoundService.play();
      _checkBotWinner();
    } else {
      setState(() => _botIsThinking = false);
    }
  }

  int _findBestMove() {
    const lines = [
      [0, 1, 2], [3, 4, 5], [6, 7, 8], [0, 3, 6], [1, 4, 7], [2, 5, 8], [0, 4, 8], [2, 4, 6],
    ];
    for (var l in lines) {
      final vals = [_botBoard[l[0]], _botBoard[l[1]], _botBoard[l[2]]];
      if (vals.where((v) => v == 'O').length == 2 && vals.contains('')) return l[vals.indexOf('')];
    }
    for (var l in lines) {
      final vals = [_botBoard[l[0]], _botBoard[l[1]], _botBoard[l[2]]];
      if (vals.where((v) => v == 'X').length == 2 && vals.contains('')) return l[vals.indexOf('')];
    }
    if (_botBoard[4].isEmpty) return 4;
    List<int> empties = [];
    for (int i = 0; i < 9; i++) if (_botBoard[i].isEmpty) empties.add(i);
    return empties.isEmpty ? -1 : empties[Random().nextInt(empties.length)];
  }

  bool _checkBotWinner() {
    if (_botShowingDialog) return false;
    const lines = [
      [0, 1, 2], [3, 4, 5], [6, 7, 8], [0, 3, 6], [1, 4, 7], [2, 5, 8], [0, 4, 8], [2, 4, 6],
    ];
    String? winner;
    for (var l in lines) {
      if (_botBoard[l[0]].isNotEmpty && _botBoard[l[0]] == _botBoard[l[1]] && _botBoard[l[1]] == _botBoard[l[2]]) {
        winner = _botBoard[l[0]];
        break;
      }
    }

    if (winner != null) {
      _botShowingDialog = true;
      setState(() {
        if (winner == 'X') _botPlayerWins++; else _botAIWins++;
        _lastWinner = winner;
      });
      final bool isMatchOver = _botPlayerWins >= _botTargetWins || _botAIWins >= _botTargetWins;
      if (isMatchOver) _botMatchEnded = true;
      Future.delayed(const Duration(milliseconds: 400), () {
        if (mounted) _showRoundEndDialog(winner == 'X' ? '🏆 فزت بالجولة!' : '🤖 فاز الكمبيوتر!', winner == 'X', isMatchOver);
      });
      return true;
    }

    if (!_botBoard.contains('')) {
      _botShowingDialog = true;
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) _showRoundEndDialog('🤝 تعادل!', null, false);
      });
      return true;
    }
    return false;
  }

  void _showRoundEndDialog(String title, bool? playerWon, bool isMatchOver) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xff1a1a2e),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(title, style: TextStyle(color: playerWon == true ? Colors.greenAccent : (playerWon == false ? Colors.redAccent : Colors.amber), fontWeight: FontWeight.bold), textAlign: TextAlign.center),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [_scoreChip('أنت', _botPlayerWins, Colors.blue), const Padding(padding: EdgeInsets.symmetric(horizontal: 8), child: Text('vs', style: TextStyle(color: Colors.white38))), _scoreChip('كمبيوتر', _botAIWins, Colors.redAccent)]),
            if (isMatchOver) ...[const SizedBox(height: 16), Text(_botPlayerWins >= _botTargetWins ? '🎉 أنت بطل المباراة!' : '😔 الكمبيوتر فاز بالمباراة', style: TextStyle(color: _botPlayerWins >= _botTargetWins ? Colors.greenAccent : Colors.white54), textAlign: TextAlign.center)],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              if (isMatchOver) Navigator.pop(context);
              else setState(() {
                _botBoard = List.generate(9, (_) => '');
                _botTurn = _lastWinner ?? 'X'; // Winner starts next round
                _botShowingDialog = false;
              });
            },
            child: Text(isMatchOver ? 'خروج' : 'الجولة التالية ▶', style: const TextStyle(color: AppColors.accentBlue, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _scoreChip(String label, int score, Color color) {
    return Column(children: [Text(label, style: const TextStyle(color: Colors.white54, fontSize: 12)), const SizedBox(height: 4), Container(width: 52, height: 52, alignment: Alignment.center, decoration: BoxDecoration(color: color.withOpacity(0.15), shape: BoxShape.circle, border: Border.all(color: color.withOpacity(0.5), width: 2)), child: Text('$score', style: TextStyle(color: color, fontSize: 24, fontWeight: FontWeight.bold)))]);
  }

  Widget _buildTurnIndicator(String text, bool isMyTurn, {bool isAlert = false}) {
    final color = isAlert ? Colors.amber : (isMyTurn ? AppColors.accentBlue : Colors.redAccent);
    return AnimatedBuilder(
      animation: _glowAnim,
      builder: (_, __) => Container(
        margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 20),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(22), border: Border.all(color: color.withOpacity(isMyTurn && !isAlert ? _glowAnim.value : 0.4), width: 1.5)),
        child: Text(text, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 15)),
      ),
    );
  }

  Widget _buildBoard(List<String> board) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: 9,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, crossAxisSpacing: 10, mainAxisSpacing: 10),
        itemBuilder: (context, index) {
          final isX = board[index] == 'X';
          return GestureDetector(
            onTap: () => _handleCellTap(index),
            child: Container(
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(15), border: Border.all(color: board[index].isNotEmpty ? (isX ? AppColors.accentBlue : AppColors.accentPink).withOpacity(0.5) : Colors.white10)),
              child: Center(child: board[index].isEmpty ? null : Text(board[index], style: TextStyle(fontSize: 48, fontWeight: FontWeight.bold, color: isX ? AppColors.accentBlue : AppColors.accentPink, shadows: [Shadow(color: (isX ? AppColors.accentBlue : AppColors.accentPink).withOpacity(0.5), blurRadius: 12)]))),
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeader(String p1Name, String p2Name, int p1Wins, int p2Wins, int target, String? roomId) {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _playerScore(p1Name, p1Wins, AppColors.accentBlue, true),
              Column(children: [Text('هدف الفوز: $target', style: const TextStyle(color: Colors.white38, fontSize: 12)), const Text('VS', style: TextStyle(color: Colors.white24, fontWeight: FontWeight.w900, fontSize: 22))]),
              _playerScore(p2Name, p2Wins, AppColors.accentPink, false),
            ],
          ),
          if (roomId != null) ...[const SizedBox(height: 10), Text('كود الغرفة: $roomId', style: const TextStyle(color: Colors.white24, fontSize: 12, letterSpacing: 2))],
        ],
      ),
    );
  }

  Widget _playerScore(String name, int wins, Color color, bool isLeft) {
    return Container(
      width: 110,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: color.withOpacity(0.05), borderRadius: BorderRadius.circular(15), border: Border.all(color: color.withOpacity(0.2))),
      child: Column(children: [Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold)), const SizedBox(height: 8), Text('$wins', style: TextStyle(color: color, fontSize: 26, fontWeight: FontWeight.bold))]),
    );
  }

  Widget _buildBotMode() {
    return Column(children: [_buildHeader('أنت (X)', 'كمبيوتر (O)', _botPlayerWins, _botAIWins, _botTargetWins, null), _buildTurnIndicator(_botTurn == 'X' ? 'دورك الآن ✨' : 'دور الكمبيوتر 🤖', _botTurn == 'X'), Expanded(child: Center(child: _buildBoard(_botBoard))), if (_botIsThinking) const Padding(padding: EdgeInsets.all(12), child: Text('الكمبيوتر يفكر...', style: TextStyle(color: Colors.white54))), const SizedBox(height: 20)]);
  }

  Widget _buildOnlineMode() {
    return Consumer<XOService>(
      builder: (context, xoService, _) {
        final room = xoService.currentRoomData;
        if (room == null) return const Center(child: CircularProgressIndicator(color: AppColors.accentBlue));
        final isHost = room['hostId'] == xoService.playerId;
        final mySymbol = (isHost ? room['hostSymbol'] : room['guestSymbol'])?.toString() ?? (isHost ? 'X' : 'O');
        final opponentName = isHost ? (room['guestName']?.toString() ?? 'بانتظار لاعب...') : (room['hostName']?.toString() ?? 'الخصم');
        final int myWins = isHost ? (room['hostWins'] ?? 0) : (room['guestWins'] ?? 0);
        final int opWins = isHost ? (room['guestWins'] ?? 0) : (room['hostWins'] ?? 0);
        final int targetWins = room['targetWins'] ?? 3;
        List<String> board = List<String>.from(room['board'] ?? List.generate(9, (_) => ''));
        String currentTurn = room['currentTurn']?.toString() ?? 'X';
        String state = room['state']?.toString() ?? 'waiting';
        bool isMyTurn = currentTurn == mySymbol;
        final isKeyboardOpen = MediaQuery.of(context).viewInsets.bottom > 0;

        if (state == 'waiting_next' && isHost) {
          Future.delayed(const Duration(seconds: 2), () {
            if (mounted && xoService.currentRoomData?['state'] == 'waiting_next') xoService.resetBoardForNextMatch();
          });
        }

        return Column(
          children: [
            _buildHeader('أنت ($mySymbol)', opponentName, myWins, opWins, targetWins, xoService.currentRoomId),
            if (!isKeyboardOpen) ...[
              if (state == 'waiting') const Text('⏳ بانتظار لاعب للانضمام', style: TextStyle(color: Colors.amber))
              else if (state == 'playing') _buildTurnIndicator(isMyTurn ? 'دورك الآن ✨' : 'دور الخصم ⏳', isMyTurn)
              else if (state == 'waiting_next') _buildTurnIndicator('🔄 جولة جديدة تبدأ...', true, isAlert: true),
            ],
            Expanded(
              child: state == 'finished'
                  ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Text(myWins >= targetWins ? '🏆 أنت البطل!' : '💔 حظ أوفر', style: TextStyle(color: myWins >= targetWins ? Colors.greenAccent : Colors.redAccent, fontSize: 28, fontWeight: FontWeight.bold)), Text('أنت: $myWins  |  الخصم: $opWins', style: const TextStyle(color: Colors.amber, fontSize: 20)), const SizedBox(height: 24), ElevatedButton(onPressed: () { xoService.leaveRoom(); Navigator.pop(context); }, child: const Text('عودة للوبي'))]))
                  : _buildBoard(board),
            ),
            _buildChatSection(xoService, isKeyboardOpen),
          ],
        );
      },
    );
  }

  Widget _buildChatSection(XOService xoService, bool isKeyboardOpen) {
    return Container(
      decoration: const BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.vertical(top: Radius.circular(20)), border: Border(top: BorderSide(color: Colors.white10))),
      child: Column(
        children: [
          ListTile(
            dense: true,
            leading: const Icon(Icons.chat_bubble_rounded, size: 16, color: AppColors.accentBlue),
            title: const Text('الدردشة', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold, fontSize: 13)),
            trailing: IconButton(icon: Icon(_showChat ? Icons.visibility_off_rounded : Icons.visibility_rounded, size: 18, color: Colors.white38), onPressed: () => setState(() => _showChat = !_showChat)),
          ),
          if (_showChat) ...[
            if (!isKeyboardOpen) SizedBox(height: 120, child: _chatMessagesList(xoService)),
            _chatInput(xoService),
          ],
        ],
      ),
    );
  }

  Widget _chatMessagesList(XOService xoService) {
    return StreamBuilder(
      stream: xoService.getChatStream(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.snapshot.value == null) return const Center(child: Text('لا توجد رسائل...', style: TextStyle(color: Colors.white24, fontSize: 11)));
        Map<dynamic, dynamic> chatsMap = snapshot.data!.snapshot.value as Map<dynamic, dynamic>;
        List<Map<dynamic, dynamic>> chats = chatsMap.entries.map((e) => {...Map<String, dynamic>.from(e.value as Map), 'key': e.key}).toList();
        chats.sort((a, b) => (b['timestamp'] as int).compareTo(a['timestamp'] as int));
        return ListView.builder(
          reverse: true,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          itemCount: chats.length,
          itemBuilder: (context, index) {
            final msg = chats[index];
            final isMe = msg['senderId'] == xoService.playerId;
            return Align(alignment: isMe ? Alignment.centerRight : Alignment.centerLeft, child: Container(margin: const EdgeInsets.symmetric(vertical: 2), padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5), decoration: BoxDecoration(color: isMe ? AppColors.accentBlue.withOpacity(0.6) : Colors.white10, borderRadius: BorderRadius.circular(10)), child: Text(msg['text']?.toString() ?? '', style: const TextStyle(color: Colors.white, fontSize: 12))));
          },
        );
      },
    );
  }

  Widget _chatInput(XOService xoService) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
      child: Row(
        children: [
          Expanded(child: TextField(controller: _chatController, style: const TextStyle(color: Colors.white, fontSize: 13), decoration: InputDecoration(hintText: 'اكتب...', hintStyle: const TextStyle(color: Colors.white38), filled: true, fillColor: Colors.white.withOpacity(0.05), border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none), contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8)))),
          IconButton(icon: const Icon(Icons.send_rounded, color: AppColors.accentBlue, size: 20), onPressed: () { final text = _chatController.text.trim(); if (text.isNotEmpty) { xoService.sendMessage(text); _chatController.clear(); }})
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('🎮 XO التحدي'), backgroundColor: Colors.black26, centerTitle: true, leading: IconButton(icon: const Icon(Icons.close_rounded), onPressed: () { if (!widget.isBotMode) Provider.of<XOService>(context, listen: false).leaveRoom(); Navigator.pop(context); })),
      body: SafeArea(child: widget.isBotMode ? _buildBotMode() : _buildOnlineMode()),
    );
  }
}
