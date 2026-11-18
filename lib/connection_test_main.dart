import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const MaterialApp(home: ConnectionTestPage()));
}

class ConnectionTestPage extends StatefulWidget {
  const ConnectionTestPage({super.key});

  @override
  State<ConnectionTestPage> createState() => _ConnectionTestPageState();
}

class _ConnectionTestPageState extends State<ConnectionTestPage> {
  final _controller = TextEditingController();
  final _col = FirebaseFirestore.instance.collection('connectionTest');

  String _authStatus = '① ログイン（匿名）を確認中…';
  String _dbStatus = '② データベースを確認中…';
  bool _authOk = false;
  bool _dbOk = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _connect();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _connect() async {
    try {
      await FirebaseAuth.instance
          .signInAnonymously()
          .timeout(const Duration(seconds: 15));
      if (!mounted) return;
      setState(() {
        _authOk = true;
        _authStatus = '① ログインできました（匿名）';
      });
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      setState(() => _authStatus =
          '① 失敗: ${e.code}\n→ Authentication の「ログイン方法」で「匿名」を有効にしてください');
      return;
    } catch (e) {
      if (!mounted) return;
      setState(() => _authStatus = '① 失敗: $e');
      return;
    }

    try {
      await _col.limit(1).get().timeout(const Duration(seconds: 15));
      if (!mounted) return;
      setState(() {
        _dbOk = true;
        _dbStatus = '② データベースにつながりました';
      });
    } on FirebaseException catch (e) {
      if (!mounted) return;
      setState(() => _dbStatus =
          '② 失敗: ${e.code}\n→ Firestoreを作成したか、ルールを公開したか確認してください');
    } catch (e) {
      if (!mounted) return;
      setState(() => _dbStatus = '② 失敗: $e');
    }
  }

  Future<void> _save() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    setState(() => _saving = true);
    try {
      await _col
          .add({'text': text, 'createdAt': FieldValue.serverTimestamp()})
          .timeout(const Duration(seconds: 15));
      _controller.clear();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('保存できませんでした: $e')));
    }
    if (mounted) setState(() => _saving = false);
  }

  Widget _status(String text, bool ok) {
    return Card(
      color: ok ? Colors.green.shade50 : Colors.grey.shade100,
      child: ListTile(
        leading: Icon(ok ? Icons.check_circle : Icons.hourglass_empty,
            color: ok ? Colors.green : Colors.grey),
        title: Text(text),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('ScreenBridge つながりテスト')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _status(_authStatus, _authOk),
            _status(_dbStatus, _dbOk),
            const SizedBox(height: 8),
            TextField(
              controller: _controller,
              enabled: _dbOk,
              decoration: const InputDecoration(
                labelText: 'データベースに保存するメッセージ',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: (_dbOk && !_saving) ? _save : null,
                child: Text(_saving ? '保存中…' : '保存する'),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: _dbOk
                  ? StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                      stream: _col
                          .orderBy('createdAt', descending: true)
                          .limit(10)
                          .snapshots(),
                      builder: (context, snap) {
                        if (snap.hasError) {
                          return Text('読み込みエラー: ${snap.error}');
                        }
                        if (!snap.hasData) {
                          return const Center(child: CircularProgressIndicator());
                        }
                        final docs = snap.data!.docs;
                        if (docs.isEmpty) {
                          return const Center(child: Text('まだ保存されたデータはありません'));
                        }
                        return ListView(
                          children: docs
                              .map((d) => ListTile(
                                    leading: const Icon(Icons.chat_bubble_outline),
                                    title: Text('${d.data()['text'] ?? ''}'),
                                  ))
                              .toList(),
                        );
                      },
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }
}