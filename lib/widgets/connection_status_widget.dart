import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ConnectionStatusWidget extends StatefulWidget {
  final String playerId;
  const ConnectionStatusWidget({super.key, required this.playerId});

  @override
  State<ConnectionStatusWidget> createState() => _ConnectionStatusWidgetState();
}

class _ConnectionStatusWidgetState extends State<ConnectionStatusWidget> {
  bool _connected = true;
  late final FirebaseFirestore _firestore;

  @override
  void initState() {
    super.initState();
    _firestore = FirebaseFirestore.instance;
    _listenStatus();
  }

  void _listenStatus() {
    _firestore
        .collection('players')
        .doc(widget.playerId)
        .snapshots()
        .listen((snap) {
      if (!snap.exists) return;
      setState(() => _connected = snap.data()?['online'] ?? false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          _connected ? Icons.wifi : Icons.wifi_off,
          color: _connected ? Colors.greenAccent : Colors.redAccent,
          size: 18,
        ),
        const SizedBox(width: 4),
        Text(
          _connected ? "Online" : "Offline",
          style: TextStyle(
            color: _connected ? Colors.greenAccent : Colors.redAccent,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}