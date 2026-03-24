import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter_linkify/flutter_linkify.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:almadar/services/auth_service.dart';
import 'package:almadar/services/image_service.dart';
import 'package:almadar/core/theme.dart';
import 'package:almadar/screens/auth_ui_screen.dart';
import 'package:almadar/screens/chat_settings_screen.dart';
import 'package:almadar/screens/profile_screen.dart';
import 'package:almadar/screens/custom_gallery_screen.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:almadar/services/data_service.dart';
import 'dart:ui' as ui;

class SupportChatScreen extends StatefulWidget {
  const SupportChatScreen({super.key});

  @override
  State<SupportChatScreen> createState() => _SupportChatScreenState();
}

class _SupportChatScreenState extends State<SupportChatScreen> {
  final _msgCtrl = TextEditingController();
  final _audioPlayer = AudioPlayer();
  bool _isFirstLoad = true;
  final DatabaseReference _chatRef = FirebaseDatabase.instance.ref(
    'support_chat/messages',
  );
  final DatabaseReference _settingsRef = FirebaseDatabase.instance.ref(
    'support_chat/settings',
  );
  final DatabaseReference _bannedRef = FirebaseDatabase.instance.ref(
    'support_chat/banned',
  );
  final DatabaseReference _mutedRef = FirebaseDatabase.instance.ref(
    'support_chat/muted',
  );
  final DatabaseReference _adminsRef = FirebaseDatabase.instance.ref(
    'support_chat/admins',
  );
  final DatabaseReference _groupInfoRef = FirebaseDatabase.instance.ref(
    'support_chat/group_info',
  );
  final DatabaseReference _usersRef = FirebaseDatabase.instance.ref('users');

  Map<String, dynamic>? _replyMsg;
  Map<String, dynamic>? _editMsg;
  File? _pickedImage;
  Map<dynamic, dynamic>? _pinnedMsg;
  List<Map<dynamic, dynamic>> _pinnedMessagesList = [];
  Set<String> _selectedMessages = {};

  bool _isChatLocked = false;
  bool _isBanned = false;
  bool _isMuted = false;
  bool _isSuperAdmin = false;
  bool _isGroupAdmin = false;
  bool _isSending = false;

  final Map<String, GlobalKey> _msgKeys = {}; // Keys for scrolling to messages

  User? _currentUser;

  String _groupName = 'مجموعة الدعم - عالمنا';
  String? _groupImage;
  String _groupMembersCount = 'جاري التحميل...';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAuth();
      _loadGroupInfo();

      // Listen for new messages to play receive sound
      _chatRef.orderByChild('timestamp').limitToLast(1).onChildAdded.listen((
        event,
      ) {
        if (_isFirstLoad) {
          _isFirstLoad = false;
          return;
        }
        if (!mounted) return;
        final data = event.snapshot.value as Map<dynamic, dynamic>?;
        if (data != null && data['senderId'] != _currentUser?.uid) {
          _audioPlayer.play(AssetSource('sounds/receive.mp3'));
        }
      });
    });
  }

  @override
  void dispose() {
    _msgCtrl.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  void _checkAuth() {
    final authService = Provider.of<AuthService>(context, listen: false);
    _currentUser = authService.user;

    if (_currentUser == null) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const AuthUIScreen()),
      );
      return;
    }

    if (_currentUser?.email == 'hmwshy402@gmail.com') {
      _isSuperAdmin = true;
      _isGroupAdmin = true;
    } else {
      _isSuperAdmin = false;
      _isGroupAdmin = false;
    }

    _checkPrivileges();
  }

  void _loadGroupInfo() {
    _groupInfoRef.onValue.listen((event) {
      if (!mounted) return;
      if (event.snapshot.value != null) {
        final data = event.snapshot.value as Map<dynamic, dynamic>;
        setState(() {
          _groupName = data['name'] ?? 'مجموعة الدعم - عالمنا';
          _groupImage = data['image'];
        });
      }
    });

    // Dummy member count for visual purposes, in a real app this would count active users
    _usersRef.onValue.listen((event) {
      if (!mounted) return;
      if (event.snapshot.value != null) {
        final data = event.snapshot.value as Map<dynamic, dynamic>;
        setState(() {
          _groupMembersCount = '${data.length} عضو';
        });
      }
    });
  }

  void _checkPrivileges() {
    if (_currentUser == null) return;
    final uid = _currentUser!.uid;

    _bannedRef.child(uid).onValue.listen((event) {
      if (mounted) setState(() => _isBanned = event.snapshot.value != null);
    });

    _mutedRef.child(uid).onValue.listen((event) {
      if (mounted) setState(() => _isMuted = event.snapshot.value != null);
    });

    _settingsRef.child('locked').onValue.listen((event) {
      if (mounted) {
        setState(
          () => _isChatLocked = (event.snapshot.value as bool?) ?? false,
        );
      }
    });

    _settingsRef.child('pinned_messages').onValue.listen((event) {
      if (mounted) {
        if (event.snapshot.value != null) {
          final data = event.snapshot.value as Map<dynamic, dynamic>;
          final list = data.values
              .map((e) => Map<dynamic, dynamic>.from(e as Map))
              .toList();
          list.sort(
            (a, b) => ((b['timestamp'] as int?) ?? 0).compareTo(
              (a['timestamp'] as int?) ?? 0,
            ),
          );
          setState(() {
            _pinnedMessagesList = list;
            _pinnedMsg = list.isNotEmpty ? list.first : null;
          });
        } else {
          _settingsRef.child('pinned').once().then((ev) {
            if (mounted) {
              if (ev.snapshot.value != null) {
                final msg = Map<dynamic, dynamic>.from(
                  ev.snapshot.value as Map,
                );
                setState(() {
                  _pinnedMessagesList = [msg];
                  _pinnedMsg = msg;
                });
              } else {
                setState(() {
                  _pinnedMessagesList = [];
                  _pinnedMsg = null;
                });
              }
            }
          });
        }
      }
    });

    if (!_isSuperAdmin) {
      _adminsRef.child(uid).onValue.listen((event) {
        if (mounted)
          setState(() => _isGroupAdmin = event.snapshot.value != null);
      });
    }
  }

  Future<void> _pickImage() async {
    if (!_isGroupAdmin) return;
    final File? file = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CustomGalleryScreen()),
    );
    if (file != null) {
      setState(() {
        _pickedImage = file;
        _editMsg = null;
      });
    }
  }

  void _addReaction(String msgId, String emoji) async {
    if (_currentUser == null) return;
    await _chatRef
        .child(msgId)
        .child('reactions')
        .child(_currentUser!.uid)
        .set(emoji);
  }

  void _pinMessage(Map<String, dynamic> msg) async {
    await _settingsRef.child('pinned').set(msg);
    await _settingsRef.child('pinned_messages/${msg['id']}').set(msg);
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('تم تثبيت الرسالة')));
    }
  }

  void _unpinMessage(String msgId) async {
    await _settingsRef.child('pinned_messages/$msgId').remove();
    if (_pinnedMessagesList.length <= 1) {
      await _settingsRef.child('pinned').remove();
    } else {
      final next = _pinnedMessagesList
          .where((m) => m['id'].toString() != msgId)
          .firstOrNull;
      if (next != null) await _settingsRef.child('pinned').set(next);
    }
  }

  void _showAllPinnedMessages() {
    if (_pinnedMessagesList.isEmpty) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xff1E1E1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Text(
                  'الرسائل المثبتة',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const Divider(color: Colors.white24, height: 1),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _pinnedMessagesList.length,
                  itemBuilder: (ctx, i) {
                    final msg = _pinnedMessagesList[i];
                    return ListTile(
                      leading: const Icon(
                        Icons.push_pin_rounded,
                        color: AppColors.accentBlue,
                      ),
                      title: Text(
                        msg['senderName'] ?? '',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      subtitle: Text(
                        msg['text'] != null && msg['text'].toString().isNotEmpty
                            ? msg['text']
                            : 'صورة المرفق',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      onTap: () {
                        Navigator.pop(ctx);
                        _scrollToMessage(msg['id'].toString());
                      },
                      trailing: _isGroupAdmin
                          ? IconButton(
                              icon: const Icon(
                                Icons.close_rounded,
                                color: Colors.white54,
                                size: 20,
                              ),
                              onPressed: () {
                                _unpinMessage(msg['id'].toString());
                                Navigator.pop(ctx);
                              },
                            )
                          : null,
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _muteUser(String uid, String name) async {
    await _mutedRef.child(uid).set({
      'name': name,
      'timestamp': ServerValue.timestamp,
    });
    if (mounted)
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('تم كتم $name')));
  }

  void _sendMessage() async {
    if (_isBanned || _isMuted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('غير مصرح لك بالكتابة حالياً المرجو التواصل مع الدعم.'),
        ),
      );
      return;
    }
    if (_isChatLocked && !_isGroupAdmin) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('الدردشة مقفلة حاليا')));
      return;
    }

    final text = _msgCtrl.text.trim();
    if (text.isEmpty && _pickedImage == null) return;

    setState(() => _isSending = true);

    try {
      // Handle Edit Msg
      if (_editMsg != null) {
        await _chatRef.child(_editMsg!['id']).update({
          'text': text,
          'isEdited': true,
        });
        setState(() {
          _editMsg = null;
          _msgCtrl.clear();
        });
        return;
      }

      String? imageUrl;
      if (_pickedImage != null) {
        imageUrl = await ImageService.uploadImage(_pickedImage!);
      }

      _msgCtrl.clear();
      final msgRef = _chatRef.push();
      final msg = {
        'id': msgRef.key,
        'senderId': _currentUser!.uid,
        'senderName': _currentUser!.displayName ?? 'مستخدم',
        'text': text,
        'imageUrl': imageUrl,
        'timestamp': ServerValue.timestamp,
        'isAdmin': _isGroupAdmin,
        'isEdited': false,
      };

      if (_replyMsg != null) {
        msg['replyToId'] = _replyMsg!['id'];
        msg['replyToName'] = _replyMsg!['senderName'];
        msg['replyToText'] = _replyMsg!['text'];
        setState(() => _replyMsg = null);
      }

      setState(() => _pickedImage = null);
      await msgRef.set(msg);
      _audioPlayer.play(AssetSource('sounds/send.mp3'));
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('خطأ: $e')));
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  void _deleteMessage(String msgId) async {
    await _chatRef.child(msgId).remove();
  }

  void _deleteSelectedMessages() async {
    for (String msgId in _selectedMessages) {
      await _chatRef.child(msgId).remove();
    }
    setState(() => _selectedMessages.clear());
  }

  void _banUser(String uid, String name) async {
    await _bannedRef.child(uid).set({
      'name': name,
      'timestamp': ServerValue.timestamp,
    });
    if (mounted)
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('تم حظر $name')));
  }

  void _promoteUser(String uid, String name) async {
    await _adminsRef.child(uid).set({'name': name});
    if (mounted)
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('تمت ترقية $name لمدير')));
  }

  void _toggleLock() async {
    await _settingsRef.child('locked').set(!_isChatLocked);
  }

  void _unmuteUser(String uid, String name) async {
    await _mutedRef.child(uid).remove();
    if (mounted)
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('تم إلغاء كتم $name')));
  }

  void _removeAdmin(String uid, String name) async {
    await _adminsRef.child(uid).remove();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تم إزالة صلاحيات الإدارة من $name')),
      );
    }
  }

  Widget _optTile(
    IconData icon,
    String title,
    VoidCallback onTap, {
    Color color = Colors.white,
  }) {
    return ListTile(
      leading: Icon(icon, color: color, size: 22),
      title: Text(
        title,
        style: TextStyle(
          color: color,
          fontSize: 15,
          fontWeight: FontWeight.bold,
        ),
      ),
      onTap: onTap,
      dense: true,
      visualDensity: VisualDensity.compact,
    );
  }

  void _scrollToMessage(String msgId) {
    final key = _msgKeys[msgId];
    if (key != null && key.currentContext != null) {
      Scrollable.ensureVisible(
        key.currentContext!,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
        alignment: 0.5,
      );
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('الرسالة أقدم من أن تظهر حالياً')),
        );
      }
    }
  }

  void _showMsgOptions(Map<String, dynamic> msg) {
    if (_currentUser == null) return;
    final isMe = msg['senderId'] == _currentUser!.uid;
    final isPinned = _pinnedMsg != null && _pinnedMsg!['id'] == msg['id'];

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss',
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (context, anim1, anim2) {
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => Navigator.pop(context),
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Scaffold(
              backgroundColor: Colors.transparent,
              body: SafeArea(
                child: Center(
                  child: GestureDetector(
                    onTap: () {}, // Consume background taps inside menu
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Message Preview
                          Directionality(
                            textDirection: ui.TextDirection.rtl,
                            child: Container(
                              margin: const EdgeInsets.symmetric(
                                horizontal: 20,
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              decoration: BoxDecoration(
                                color: isMe
                                    ? const Color(0xff2B88D8)
                                    : const Color(0xff212121),
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Colors.black26,
                                    blurRadius: 10,
                                  ),
                                ],
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    msg['senderName'] ?? 'مستخدم',
                                    style: TextStyle(
                                      color: isMe
                                          ? Colors.white
                                          : Colors.greenAccent,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  if (msg['imageUrl'] != null)
                                    Padding(
                                      padding: const EdgeInsets.only(bottom: 8),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: Image.network(
                                          msg['imageUrl'],
                                          height: 120,
                                          width: double.infinity,
                                          fit: BoxFit.cover,
                                        ),
                                      ),
                                    ),
                                  if ((msg['text'] ?? '').toString().isNotEmpty)
                                    Text(
                                      msg['text'],
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 15,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),

                          // Emojis Row
                          Container(
                            width: 280,
                            padding: const EdgeInsets.symmetric(
                              vertical: 10,
                              horizontal: 8,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xff1E1E1E).withOpacity(0.9),
                              borderRadius: BorderRadius.circular(30),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: ['👍', '❤️', '😂', '😮', '😢', '🙏']
                                  .map((emoji) {
                                    return GestureDetector(
                                      behavior: HitTestBehavior.opaque,
                                      onTap: () {
                                        _addReaction(msg['id'], emoji);
                                        Navigator.pop(context);
                                      },
                                      child: Text(
                                        emoji,
                                        style: const TextStyle(fontSize: 28),
                                      ),
                                    );
                                  })
                                  .toList(),
                            ),
                          ),
                          const SizedBox(height: 15),

                          // Options List
                          Directionality(
                            textDirection: ui.TextDirection.rtl,
                            child: Container(
                              width: 280,
                              decoration: BoxDecoration(
                                color: const Color(0xff1E1E1E).withOpacity(0.9),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(20),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (_isGroupAdmin) ...[
                                      _optTile(
                                        Icons.check_box_rounded,
                                        'تحديد',
                                        () {
                                          Navigator.pop(context);
                                          setState(
                                            () => _selectedMessages.add(
                                              msg['id'].toString(),
                                            ),
                                          );
                                        },
                                      ),
                                      const Divider(
                                        height: 1,
                                        color: Colors.white10,
                                      ),
                                    ],
                                    _optTile(Icons.reply_rounded, 'رد', () {
                                      Navigator.pop(context);
                                      setState(() => _replyMsg = msg);
                                    }),
                                    const Divider(
                                      height: 1,
                                      color: Colors.white10,
                                    ),
                                    _optTile(Icons.copy_rounded, 'نسخ', () {
                                      Clipboard.setData(
                                        ClipboardData(text: msg['text'] ?? ''),
                                      );
                                      Navigator.pop(context);
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text('تم النسخ'),
                                        ),
                                      );
                                    }),

                                    if (_isGroupAdmin) ...[
                                      const Divider(
                                        height: 1,
                                        color: Colors.white10,
                                      ),
                                      _optTile(
                                        isPinned
                                            ? Icons.push_pin_outlined
                                            : Icons.push_pin_rounded,
                                        isPinned
                                            ? 'إلغاء التثبيت'
                                            : 'تثبيت الرسالة',
                                        () {
                                          Navigator.pop(context);
                                          if (isPinned)
                                            _unpinMessage(msg['id'].toString());
                                          else
                                            _pinMessage(msg);
                                        },
                                      ),
                                    ],

                                    // Edit is for sender only
                                    if (isMe) ...[
                                      const Divider(
                                        height: 1,
                                        color: Colors.white10,
                                      ),
                                      _optTile(
                                        Icons.edit_rounded,
                                        'تعديل الرسالة',
                                        () {
                                          Navigator.pop(context);
                                          setState(() {
                                            _editMsg = msg;
                                            _msgCtrl.text = msg['text'] ?? '';
                                            _replyMsg = null;
                                            _pickedImage = null;
                                          });
                                        },
                                      ),
                                    ],

                                    // Delete is for sender OR admin
                                    if (isMe || _isGroupAdmin) ...[
                                      const Divider(
                                        height: 1,
                                        color: Colors.white10,
                                      ),
                                      _optTile(
                                        Icons.delete_rounded,
                                        'حذف الرسالة',
                                        () {
                                          _deleteMessage(msg['id']);
                                          Navigator.pop(context);
                                        },
                                        color: Colors.redAccent,
                                      ),
                                    ],

                                    // Admin Tools
                                    if (_isSuperAdmin && !isMe) ...[
                                      Container(
                                        height: 6,
                                        color: Colors.black26,
                                      ),
                                      _optTile(
                                        Icons.security,
                                        'ترقية إلى أدمن',
                                        () {
                                          _promoteUser(
                                            msg['senderId'],
                                            msg['senderName'],
                                          );
                                          Navigator.pop(context);
                                        },
                                        color: Colors.greenAccent,
                                      ),
                                      const Divider(
                                        height: 1,
                                        color: Colors.white10,
                                      ),
                                      _optTile(
                                        Icons.remove_moderator,
                                        'إزالة من الإدارة',
                                        () {
                                          _removeAdmin(
                                            msg['senderId'],
                                            msg['senderName'],
                                          );
                                          Navigator.pop(context);
                                        },
                                        color: Colors.redAccent,
                                      ),
                                      const Divider(
                                        height: 1,
                                        color: Colors.white10,
                                      ),
                                      _optTile(
                                        Icons.volume_up_rounded,
                                        'إلغاء كتم المستخدم',
                                        () {
                                          _unmuteUser(
                                            msg['senderId'],
                                            msg['senderName'],
                                          );
                                          Navigator.pop(context);
                                        },
                                        color: Colors.blueAccent,
                                      ),
                                      const Divider(
                                        height: 1,
                                        color: Colors.white10,
                                      ),
                                      _optTile(
                                        Icons.volume_off_rounded,
                                        'كتم المستخدم',
                                        () {
                                          _muteUser(
                                            msg['senderId'],
                                            msg['senderName'],
                                          );
                                          Navigator.pop(context);
                                        },
                                        color: Colors.orangeAccent,
                                      ),
                                      const Divider(
                                        height: 1,
                                        color: Colors.white10,
                                      ),
                                      _optTile(
                                        Icons.block,
                                        'حظر المستخدم',
                                        () {
                                          _banUser(
                                            msg['senderId'],
                                            msg['senderName'],
                                          );
                                          Navigator.pop(context);
                                        },
                                        color: Colors.orangeAccent,
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  String _formatTime(int timestamp) {
    return DateFormat('h:mm a')
        .format(DateTime.fromMillisecondsSinceEpoch(timestamp))
        .replaceAll('AM', 'ص')
        .replaceAll('PM', 'م');
  }

  String _formatDate(int timestamp) {
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
    final now = DateTime.now();
    if (date.year == now.year &&
        date.month == now.month &&
        date.day == now.day) {
      return 'اليوم';
    }
    final months = [
      'يناير',
      'فبراير',
      'مارس',
      'أبريل',
      'مايو',
      'يونيو',
      'يوليو',
      'أغسطس',
      'سبتمبر',
      'أكتوبر',
      'نوفمبر',
      'ديسمبر',
    ];
    return '${date.day} ${months[date.month - 1]}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black, // Dark telegram-like background
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(60),
        child: Container(
          decoration: const BoxDecoration(
            color: Color(0xff1c1c1d),
            border: Border(bottom: BorderSide(color: Colors.white10, width: 1)),
          ),
          child: SafeArea(
            child: _selectedMessages.isNotEmpty
                ? Row(
                    children: [
                      IconButton(
                        icon: const Icon(
                          Icons.close_rounded,
                          color: Colors.white,
                        ),
                        onPressed: () =>
                            setState(() => _selectedMessages.clear()),
                      ),
                      Text(
                        '${_selectedMessages.length} رسائل محددة',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(
                          Icons.delete_rounded,
                          color: Colors.redAccent,
                        ),
                        onPressed: _deleteSelectedMessages,
                      ),
                    ],
                  )
                : Row(
                    children: [
                      IconButton(
                        icon: const Icon(
                          Icons.arrow_back_rounded,
                          color: AppColors.accentBlue,
                        ),
                        onPressed: () => Navigator.pop(context),
                      ),
                      GestureDetector(
                        onTap: () {
                          if (_isGroupAdmin) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const ChatSettingsScreen(),
                              ),
                            );
                          }
                        },
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 20,
                              backgroundColor: Colors.white12,
                              backgroundImage: _groupImage != null
                                  ? NetworkImage(_groupImage!)
                                  : null,
                              child: _groupImage == null
                                  ? const Icon(
                                      Icons.groups,
                                      color: Colors.white70,
                                    )
                                  : null,
                            ),
                            const SizedBox(width: 10),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  _groupName,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                Text(
                                  _groupMembersCount,
                                  style: const TextStyle(
                                    color: Colors.white54,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      if (_isSuperAdmin || _isGroupAdmin)
                        IconButton(
                          icon: Icon(
                            _isChatLocked
                                ? Icons.lock_rounded
                                : Icons.lock_open_rounded,
                            color: _isChatLocked
                                ? Colors.redAccent
                                : AppColors.accentBlue,
                          ),
                          onPressed: _toggleLock,
                        ),
                    ],
                  ),
          ),
        ),
      ),
      body: Directionality(
        textDirection: ui.TextDirection.rtl,
        child: Column(
          children: [
            if (_isChatLocked)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 8),
                color: Colors.redAccent.withOpacity(0.9),
                child: const Text(
                  'الدردشة مقفلة. يمكن للمدراء فقط إرسال الأخبار.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            
            // Admin Statistics Dashboard (Visible only to the specified Admin Email)
            if (_isGroupAdmin && _currentUser?.email == 'hmwshy402@gmail.com') 
              StreamBuilder<Map<String, dynamic>>(
                stream: Provider.of<DataService>(context, listen: false).getAdminStats(_currentUser?.email),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return const SizedBox.shrink();
                  final stats = snapshot.data!;
                  return Container(
                    margin: const EdgeInsets.all(10),
                    padding: const EdgeInsets.all(15),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF1E3C72), Color(0xFF2A5298)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(15),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.3),
                          blurRadius: 10,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildStatItem(Icons.devices, stats['totalDevices'].toString(), 'الأجهزة'),
                        _buildStatItem(Icons.bolt, stats['onlineUsers'].toString(), 'متصل الآن', isHighlight: true),
                        _buildStatItem(Icons.tv, stats['totalChannels'].toString(), 'القنوات'),
                      ],
                    ),
                  );
                }
              ),
            if (_pinnedMsg != null)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.white10,
                  borderRadius: BorderRadius.circular(10),
                  border: const Border(
                    right: BorderSide(color: AppColors.accentBlue, width: 3),
                  ),
                ),
                child: GestureDetector(
                  onTap: () {
                    if (_pinnedMsg?['id'] != null) {
                      _scrollToMessage(_pinnedMsg!['id'].toString());
                    }
                  },
                  onLongPress: _showAllPinnedMessages,
                  child: Row(
                    children: [
                      const Icon(
                        Icons.push_pin_rounded,
                        color: AppColors.accentBlue,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'رسالة مثبتة',
                              style: TextStyle(
                                color: AppColors.accentBlue,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              _pinnedMsg!['text'] ?? 'صورة المرفق',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (_isGroupAdmin)
                        IconButton(
                          icon: const Icon(
                            Icons.close_rounded,
                            color: Colors.white54,
                            size: 20,
                          ),
                          onPressed: () {
                            if (_pinnedMsg != null) {
                              _unpinMessage(_pinnedMsg!['id'].toString());
                            }
                          },
                        ),
                    ],
                  ),
                ),
              ),
            Expanded(
              child: StreamBuilder(
                stream: _chatRef
                    .orderByChild('timestamp')
                    .limitToLast(150)
                    .onValue,
                builder: (context, snapshot) {
                  if (!snapshot.hasData ||
                      snapshot.data?.snapshot.value == null) {
                    return const Center(
                      child: Text(
                        'لا توجد رسائل',
                        style: TextStyle(color: Colors.white54),
                      ),
                    );
                  }

                  final Map<dynamic, dynamic> data =
                      snapshot.data!.snapshot.value as Map<dynamic, dynamic>;
                  final msgs = data.values
                      .map((e) => Map<String, dynamic>.from(e))
                      .toList();
                  msgs.sort(
                    (a, b) => (b['timestamp'] as int).compareTo(
                      a['timestamp'] as int,
                    ),
                  ); // descending

                  return ListView.builder(
                    reverse: true,
                    padding: const EdgeInsets.only(
                      bottom: 20,
                      right: 10,
                      left: 10,
                      top: 10,
                    ),
                    itemCount: msgs.length,
                    itemBuilder: (context, index) {
                      final msg = msgs[index];
                      final isMe = msg['senderId'] == _currentUser?.uid;
                      final isMsgAdmin = msg['isAdmin'] == true;

                      bool showDateHeader = false;
                      if (index == msgs.length - 1) {
                        showDateHeader = true; // Oldest message
                      } else {
                        final prevMsg =
                            msgs[index +
                                1]; // Next in reversed list is physically older
                        final currentDate = _formatDate(
                          msg['timestamp'] as int,
                        );
                        final prevDate = _formatDate(
                          prevMsg['timestamp'] as int,
                        );
                        if (currentDate != prevDate) showDateHeader = true;
                      }

                      final msgId = msg['id'].toString();
                      if (!_msgKeys.containsKey(msgId)) {
                        _msgKeys[msgId] = GlobalKey();
                      }

                      return Column(
                        key: _msgKeys[msgId],
                        children: [
                          if (showDateHeader)
                            Container(
                              margin: const EdgeInsets.symmetric(vertical: 15),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white12,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                _formatDate(msg['timestamp'] as int),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),

                          // ─── Admin Channel Post ───
                          if (isMsgAdmin)
                            GestureDetector(
                              onLongPress: () => _showMsgOptions(msg),
                              child: Container(
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 5,
                                ),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      const Color(0xff0f1931),
                                      const Color(0xff1a1a2e),
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  borderRadius: BorderRadius.circular(18),
                                  border: Border.all(
                                    color: AppColors.accentBlue.withOpacity(
                                      0.35,
                                    ),
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppColors.accentBlue.withOpacity(
                                        0.08,
                                      ),
                                      blurRadius: 12,
                                      spreadRadius: 1,
                                    ),
                                  ],
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // ── Channel header ──
                                    Padding(
                                      padding: const EdgeInsets.fromLTRB(
                                        12,
                                        10,
                                        12,
                                        8,
                                      ),
                                      child: Row(
                                        children: [
                                          Container(
                                            width: 38,
                                            height: 38,
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              border: Border.all(
                                                color: AppColors.accentBlue,
                                                width: 1.5,
                                              ),
                                              image: const DecorationImage(
                                                image: AssetImage(
                                                  'assets/images/logo.png',
                                                ),
                                                fit: BoxFit.cover,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Row(
                                                  children: [
                                                    Text(
                                                      msg['senderName'] ??
                                                          'المدار TV',
                                                      style: const TextStyle(
                                                        color: Colors.white,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        fontSize: 14,
                                                      ),
                                                    ),
                                                    const SizedBox(width: 4),
                                                    const Icon(
                                                      Icons.verified_rounded,
                                                      color:
                                                          AppColors.accentBlue,
                                                      size: 14,
                                                    ),
                                                  ],
                                                ),
                                                const Text(
                                                  'قناة رسمية',
                                                  style: TextStyle(
                                                    color: Colors.white38,
                                                    fontSize: 11,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          Text(
                                            _formatTime(
                                              msg['timestamp'] as int,
                                            ),
                                            style: const TextStyle(
                                              color: Colors.white24,
                                              fontSize: 11,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    // ── Divider ──
                                    Container(
                                      height: 1,
                                      color: Colors.white.withOpacity(0.06),
                                    ),
                                    // ── Image ──
                                    if (msg['imageUrl'] != null)
                                      ClipRRect(
                                        child: Image.network(
                                          msg['imageUrl'],
                                          width: double.infinity,
                                          fit: BoxFit.cover,
                                        ),
                                      ),
                                    // ── Text ──
                                    if ((msg['text'] ?? '')
                                        .toString()
                                        .isNotEmpty)
                                      Padding(
                                        padding: const EdgeInsets.fromLTRB(
                                          14,
                                          12,
                                          14,
                                          6,
                                        ),
                                        child: SelectableLinkify(
                                          text: msg['text'],
                                          onOpen: (link) async {
                                            if (!await launchUrl(
                                              Uri.parse(link.url),
                                            )) {
                                              if (context.mounted) {
                                                ScaffoldMessenger.of(
                                                  context,
                                                ).showSnackBar(
                                                  const SnackBar(
                                                    content: Text(
                                                      'لا يمكن فتح الرابط',
                                                    ),
                                                  ),
                                                );
                                              }
                                            }
                                          },
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 15,
                                            height: 1.6,
                                          ),
                                          linkStyle: const TextStyle(
                                            color: AppColors.accentBlue,
                                            decoration:
                                                TextDecoration.underline,
                                          ),
                                        ),
                                      ),
                                    // ── Reactions ──
                                    if (msg['reactions'] != null)
                                      Padding(
                                        padding: const EdgeInsets.fromLTRB(
                                          12,
                                          6,
                                          12,
                                          4,
                                        ),
                                        child: Wrap(
                                          spacing: 6,
                                          runSpacing: 4,
                                          children: (msg['reactions'] as Map<dynamic, dynamic>)
                                              .values
                                              .toSet()
                                              .map((emoji) {
                                                final count =
                                                    (msg['reactions']
                                                            as Map<
                                                              dynamic,
                                                              dynamic
                                                            >)
                                                        .values
                                                        .where(
                                                          (e) => e == emoji,
                                                        )
                                                        .length;
                                                final formatted = count >= 1000
                                                    ? '${(count / 1000).toStringAsFixed(1)}k+'
                                                    : '$count';
                                                return GestureDetector(
                                                  onTap: () {
                                                    _chatRef
                                                        .child(msg['id'])
                                                        .child(
                                                          'reactions/${_currentUser?.uid}',
                                                        )
                                                        .set(emoji);
                                                  },
                                                  child: Container(
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          horizontal: 8,
                                                          vertical: 4,
                                                        ),
                                                    decoration: BoxDecoration(
                                                      color: Colors.white10,
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            12,
                                                          ),
                                                      border: Border.all(
                                                        color: Colors.white24,
                                                      ),
                                                    ),
                                                    child: Row(
                                                      mainAxisSize:
                                                          MainAxisSize.min,
                                                      children: [
                                                        Image.asset(
                                                          'assets/images/emojis/$emoji.png',
                                                          width: 16,
                                                          height: 16,
                                                          errorBuilder:
                                                              (c, o, s) => Text(
                                                                emoji
                                                                    .toString(),
                                                                style:
                                                                    const TextStyle(
                                                                      fontSize:
                                                                          13,
                                                                    ),
                                                              ),
                                                        ),
                                                        if (count > 1) ...[
                                                          const SizedBox(
                                                            width: 4,
                                                          ),
                                                          Text(
                                                            formatted,
                                                            style:
                                                                const TextStyle(
                                                                  color: Colors
                                                                      .white70,
                                                                  fontSize: 12,
                                                                ),
                                                          ),
                                                        ],
                                                      ],
                                                    ),
                                                  ),
                                                );
                                              })
                                              .toList(),
                                        ),
                                      ),
                                    // ── Footer ──
                                    Padding(
                                      padding: const EdgeInsets.fromLTRB(
                                        14,
                                        2,
                                        14,
                                        12,
                                      ),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          if (msg['isEdited'] == true)
                                            const Text(
                                              'مُعدَّلة',
                                              style: TextStyle(
                                                color: Colors.white30,
                                                fontSize: 10,
                                              ),
                                            )
                                          else
                                            const SizedBox.shrink(),
                                          if (msg['pinnedBy'] != null)
                                            const Row(
                                              children: [
                                                Icon(
                                                  Icons.push_pin_rounded,
                                                  size: 12,
                                                  color: Colors.amber,
                                                ),
                                                SizedBox(width: 3),
                                                Text(
                                                  'مثبت',
                                                  style: TextStyle(
                                                    color: Colors.amber,
                                                    fontSize: 11,
                                                  ),
                                                ),
                                              ],
                                            ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            )
                          // ─── Regular User Message ───
                          else
                            Dismissible(
                              key: Key(msg['id'].toString()),
                              direction: DismissDirection.endToStart,
                              background: Container(
                                alignment: Alignment.centerLeft,
                                padding: const EdgeInsets.only(left: 20),
                                child: const Icon(
                                  Icons.reply_rounded,
                                  color: Colors.white,
                                ),
                              ),
                              confirmDismiss: (_) async {
                                setState(() => _replyMsg = msg);
                                return false;
                              },
                              child: GestureDetector(
                                onLongPress: () {
                                  if (_selectedMessages.isEmpty) {
                                    _showMsgOptions(msg);
                                  } else {
                                    setState(() {
                                      if (_selectedMessages.contains(
                                        msg['id'].toString(),
                                      )) {
                                        _selectedMessages.remove(
                                          msg['id'].toString(),
                                        );
                                      } else {
                                        _selectedMessages.add(
                                          msg['id'].toString(),
                                        );
                                      }
                                    });
                                  }
                                },
                                onTap: () {
                                  if (_selectedMessages.isNotEmpty) {
                                    setState(() {
                                      if (_selectedMessages.contains(
                                        msg['id'].toString(),
                                      )) {
                                        _selectedMessages.remove(
                                          msg['id'].toString(),
                                        );
                                      } else {
                                        _selectedMessages.add(
                                          msg['id'].toString(),
                                        );
                                      }
                                    });
                                  }
                                },
                                child: Container(
                                  color:
                                      _selectedMessages.contains(
                                        msg['id'].toString(),
                                      )
                                      ? Colors.blueAccent.withOpacity(0.2)
                                      : Colors.transparent,
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: Row(
                                    mainAxisAlignment: isMe
                                        ? MainAxisAlignment.start
                                        : MainAxisAlignment.end,
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      if (!isMe)
                                        GestureDetector(
                                          onTap: () {
                                            if (isMsgAdmin) {
                                              Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                  builder: (_) => ProfileScreen(
                                                    uid: msg['senderId'],
                                                  ),
                                                ),
                                              );
                                            }
                                          },
                                          child: const CircleAvatar(
                                            radius: 16,
                                            backgroundColor: Colors.white12,
                                            backgroundImage: AssetImage(
                                              'assets/images/logo.png',
                                            ),
                                          ),
                                        ),
                                      if (!isMe) const SizedBox(width: 8),

                                      Container(
                                        constraints: BoxConstraints(
                                          maxWidth:
                                              MediaQuery.of(
                                                context,
                                              ).size.width *
                                              0.75,
                                        ),
                                        decoration: BoxDecoration(
                                          color: isMe
                                              ? const Color(0xff2B88D8)
                                              : const Color(0xff212121),
                                          borderRadius: BorderRadius.only(
                                            topLeft: const Radius.circular(16),
                                            topRight: const Radius.circular(16),
                                            bottomLeft: isMe
                                                ? const Radius.circular(16)
                                                : const Radius.circular(4),
                                            bottomRight: isMe
                                                ? const Radius.circular(4)
                                                : const Radius.circular(16),
                                          ),
                                        ),
                                        padding: const EdgeInsets.all(10),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            if (!isMe) ...[
                                              Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  if (isMsgAdmin) ...[
                                                    const Icon(
                                                      Icons.verified,
                                                      color:
                                                          AppColors.accentBlue,
                                                      size: 14,
                                                    ),
                                                    const SizedBox(width: 4),
                                                  ],
                                                  Text(
                                                    msg['senderName'] ??
                                                        'مجهول',
                                                    style: TextStyle(
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      fontSize: 13,
                                                      color: isMsgAdmin
                                                          ? AppColors.accentBlue
                                                          : Colors.greenAccent,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 4),
                                            ],

                                            if (msg['replyToText'] != null)
                                              Container(
                                                margin: const EdgeInsets.only(
                                                  bottom: 6,
                                                ),
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 10,
                                                      vertical: 6,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: Colors.black26,
                                                  borderRadius:
                                                      BorderRadius.circular(6),
                                                  border: const Border(
                                                    right: BorderSide(
                                                      color: Colors.greenAccent,
                                                      width: 3,
                                                    ),
                                                  ),
                                                ),
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      msg['replyToName'],
                                                      style: const TextStyle(
                                                        fontSize: 11,
                                                        color:
                                                            Colors.greenAccent,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                      ),
                                                    ),
                                                    Text(
                                                      msg['replyToText'],
                                                      style: const TextStyle(
                                                        fontSize: 12,
                                                        color: Colors.white70,
                                                      ),
                                                      maxLines: 2,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                    ),
                                                  ],
                                                ),
                                              ),

                                            if (msg['imageUrl'] != null)
                                              Padding(
                                                padding: const EdgeInsets.only(
                                                  bottom: 8,
                                                ),
                                                child: ClipRRect(
                                                  borderRadius:
                                                      BorderRadius.circular(10),
                                                  child: Image.network(
                                                    msg['imageUrl'],
                                                    fit: BoxFit.cover,
                                                  ),
                                                ),
                                              ),

                                            if ((msg['text'] ?? '')
                                                .toString()
                                                .isNotEmpty)
                                              SelectableLinkify(
                                                text: msg['text'],
                                                onOpen: (link) async {
                                                  if (!await launchUrl(
                                                    Uri.parse(link.url),
                                                  )) {
                                                    ScaffoldMessenger.of(
                                                      context,
                                                    ).showSnackBar(
                                                      const SnackBar(
                                                        content: Text(
                                                          'Could not launch url',
                                                        ),
                                                      ),
                                                    );
                                                  }
                                                },
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 15,
                                                ),
                                                linkStyle: const TextStyle(
                                                  color: Colors.blueAccent,
                                                  decoration:
                                                      TextDecoration.underline,
                                                ),
                                              ),

                                            const SizedBox(height: 4),
                                            Row(
                                              mainAxisSize: MainAxisSize.min,
                                              mainAxisAlignment:
                                                  MainAxisAlignment.end,
                                              children: [
                                                if (msg['isEdited'] == true)
                                                  const Padding(
                                                    padding: EdgeInsets.only(
                                                      left: 6,
                                                    ),
                                                    child: Text(
                                                      'مُعدلة',
                                                      style: TextStyle(
                                                        color: Colors.white54,
                                                        fontSize: 10,
                                                      ),
                                                    ),
                                                  ),
                                                Text(
                                                  _formatTime(
                                                    msg['timestamp'] as int,
                                                  ),
                                                  style: TextStyle(
                                                    color: isMe
                                                        ? Colors.white70
                                                        : Colors.white54,
                                                    fontSize: 10,
                                                  ),
                                                ),
                                                if (isMe) ...[
                                                  const SizedBox(width: 4),
                                                  const Icon(
                                                    Icons.done_all_rounded,
                                                    color: Colors.white,
                                                    size: 12,
                                                  ),
                                                ],
                                              ],
                                            ),
                                            if (msg['reactions'] != null)
                                              Padding(
                                                padding: const EdgeInsets.only(
                                                  top: 4,
                                                ),
                                                child: Wrap(
                                                  spacing: 4,
                                                  children:
                                                      (msg['reactions']
                                                              as Map<
                                                                dynamic,
                                                                dynamic
                                                              >)
                                                          .values
                                                          .toSet()
                                                          .map((emoji) {
                                                            final count =
                                                                (msg['reactions']
                                                                        as Map<
                                                                          dynamic,
                                                                          dynamic
                                                                        >)
                                                                    .values
                                                                    .where(
                                                                      (e) =>
                                                                          e ==
                                                                          emoji,
                                                                    )
                                                                    .length;
                                                            final formattedCount =
                                                                count >= 1000
                                                                ? '${(count / 1000).toStringAsFixed(1)}k+'
                                                                : '$count';
                                                            return Container(
                                                              padding:
                                                                  const EdgeInsets.symmetric(
                                                                    horizontal:
                                                                        6,
                                                                    vertical: 2,
                                                                  ),
                                                              decoration: BoxDecoration(
                                                                color: Colors
                                                                    .white10,
                                                                borderRadius:
                                                                    BorderRadius.circular(
                                                                      10,
                                                                    ),
                                                                border: Border.all(
                                                                  color: Colors
                                                                      .white24,
                                                                ),
                                                              ),
                                                              child: Row(
                                                                mainAxisSize:
                                                                    MainAxisSize
                                                                        .min,
                                                                children: [
                                                                  Image.asset(
                                                                    'assets/images/emojis/$emoji.png',
                                                                    width: 14,
                                                                    height: 14,
                                                                    errorBuilder:
                                                                        (
                                                                          c,
                                                                          o,
                                                                          s,
                                                                        ) => Text(
                                                                          emoji
                                                                              .toString(),
                                                                          style: const TextStyle(
                                                                            fontSize:
                                                                                12,
                                                                          ),
                                                                        ),
                                                                  ),
                                                                  if (count >
                                                                      1) ...[
                                                                    const SizedBox(
                                                                      width: 4,
                                                                    ),
                                                                    Text(
                                                                      formattedCount,
                                                                      style: const TextStyle(
                                                                        color: Colors
                                                                            .white70,
                                                                        fontSize:
                                                                            10,
                                                                      ),
                                                                    ),
                                                                  ],
                                                                ],
                                                              ),
                                                            );
                                                          })
                                                          .toList(),
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                        ],
                      );
                    },
                  );
                },
              ),
            ),

            // Input Region
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 8,
              ).copyWith(bottom: 20),
              decoration: const BoxDecoration(color: Color(0xff1c1c1d)),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_replyMsg != null ||
                      _editMsg != null ||
                      _pickedImage != null)
                    Container(
                      padding: const EdgeInsets.all(10),
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: const BoxDecoration(
                        border: Border(
                          left: BorderSide(
                            color: AppColors.accentBlue,
                            width: 3,
                          ),
                        ),
                      ),
                      child: Row(
                        children: [
                          if (_pickedImage != null)
                            Padding(
                              padding: const EdgeInsets.only(left: 10),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(5),
                                child: Image.file(
                                  _pickedImage!,
                                  width: 40,
                                  height: 40,
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _editMsg != null
                                      ? 'تعديل الرسالة'
                                      : (_replyMsg != null
                                            ? 'الرد على: ${_replyMsg!['senderName']}'
                                            : 'إرفاق صورة'),
                                  style: const TextStyle(
                                    color: AppColors.accentBlue,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                if (_replyMsg != null || _editMsg != null)
                                  Text(
                                    (_editMsg ?? _replyMsg)!['text'],
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 12,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.close_rounded,
                              color: Colors.white54,
                            ),
                            onPressed: () => setState(() {
                              _replyMsg = null;
                              if (_editMsg != null) _msgCtrl.clear();
                              _editMsg = null;
                              _pickedImage = null;
                            }),
                          ),
                        ],
                      ),
                    ),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      // Send button on right as requested explicitly (with RTL textDirection it's at start index)
                      Padding(
                        padding: const EdgeInsets.only(left: 8),
                        child: CircleAvatar(
                          backgroundColor: Colors.transparent,
                          child: _isSending
                              ? const CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppColors.accentBlue,
                                )
                              : IconButton(
                                  icon: const Icon(
                                    Icons.send_rounded,
                                    color: AppColors.accentBlue,
                                    size: 28,
                                  ),
                                  onPressed: _sendMessage,
                                ),
                        ),
                      ),
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white10,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: TextField(
                            controller: _msgCtrl,
                            style: const TextStyle(color: Colors.white),
                            maxLines: 5,
                            minLines: 1,
                            textInputAction: TextInputAction.newline,
                            decoration: InputDecoration(
                              hintText:
                                  (_isChatLocked && !_isGroupAdmin) || _isBanned
                                  ? 'غير مصرح بالكتابة'
                                  : 'المراسلة...',
                              hintStyle: const TextStyle(color: Colors.white38),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              border: InputBorder.none,
                            ),
                            enabled:
                                (!_isChatLocked || _isGroupAdmin) && !_isBanned,
                          ),
                        ),
                      ),
                      // Attachment button on the left (end of RTL Row)
                      if (_isGroupAdmin && _editMsg == null)
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: IconButton(
                            icon: const Icon(
                              Icons.attach_file_rounded,
                              color: Colors.white54,
                              size: 28,
                            ),
                            onPressed: _pickImage,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(
    IconData icon,
    String value,
    String label, {
    bool isHighlight = false,
  }) {
    return Column(
      children: [
        Icon(
          icon,
          color: isHighlight ? AppColors.accentBlue : Colors.white70,
          size: 24,
        ),
        const SizedBox(height: 5),
        Text(
          value,
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w900,
            shadows: isHighlight
                ? [const Shadow(color: AppColors.accentBlue, blurRadius: 10)]
                : null,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.6),
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}
