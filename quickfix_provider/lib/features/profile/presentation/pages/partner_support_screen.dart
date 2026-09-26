import 'package:flutter/material.dart';

class PartnerSupportScreen extends StatefulWidget {
  const PartnerSupportScreen({super.key});

  @override
  State<PartnerSupportScreen> createState() => _PartnerSupportScreenState();
}

class _PartnerSupportScreenState extends State<PartnerSupportScreen> {
  final List<Map<String, dynamic>> _messages = [
    {
      'sender': 'ai',
      'name': 'QuickFix Partner AI',
      'text': 'Welcome Partner! How can we assist your shop today? Ask about payouts, KYC, technician assignments, or commissions.',
      'time': 'Just now'
    }
  ];

  final TextEditingController _controller = TextEditingController();

  final List<String> _quickOptions = [
    'Payout / Settlement issue',
    'KYC Document verification',
    'Technician re-assignment',
    'Commission & Visiting fee query',
  ];

  void _sendMessage(String text) {
    if (text.trim().isEmpty) return;
    setState(() {
      _messages.add({
        'sender': 'user',
        'name': 'Partner',
        'text': text.trim(),
        'time': 'Just now'
      });
      _controller.clear();
    });

    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted) {
        setState(() {
          _messages.add({
            'sender': 'ai',
            'name': 'QuickFix Partner AI',
            'text': _getPartnerAiReply(text),
            'time': 'Just now'
          });
        });
      }
    });
  }

  String _getPartnerAiReply(String query) {
    final q = query.toLowerCase();
    if (q.contains('payout') || q.contains('settlement')) {
      return 'Daily shop settlements are auto-processed at 11:00 PM. Check settlements ledger under Profile -> Financial Ledger for details.';
    } else if (q.contains('kyc') || q.contains('document')) {
      return 'KYC verifications take up to 24 hours. Ensure Aadhaar & PAN images are clear without crop under Profile -> Verification.';
    } else if (q.contains('commission')) {
      return 'Standard platform commission is 15% on completed bookings. Visiting inspection fee is 100% credited to your shop wallet.';
    }
    return 'Your query has been logged. A Partner Account Manager has been assigned to your shop ticket and will reply shortly.';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text('Partner Support & Helpdesk', style: TextStyle(color: Colors.white, fontSize: 16)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[index];
                final isUser = msg['sender'] == 'user';
                return Align(
                  alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isUser ? const Color(0xFF3B82F6) : const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(msg['name'], style: TextStyle(color: isUser ? Colors.white70 : Colors.greenAccent, fontSize: 10, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Text(msg['text'], style: const TextStyle(color: Colors.white, fontSize: 13)),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          SizedBox(
            height: 38,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _quickOptions.length,
              itemBuilder: (context, index) {
                final opt = _quickOptions[index];
                return GestureDetector(
                  onTap: () => _sendMessage(opt),
                  child: Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.blue.withOpacity(0.4)),
                    ),
                    child: Text(opt, style: const TextStyle(color: Colors.blueAccent, fontSize: 11, fontWeight: FontWeight.bold)),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            color: const Color(0xFF1E293B),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    decoration: const InputDecoration(
                      hintText: 'Type partner query...',
                      hintStyle: TextStyle(color: Colors.white38, fontSize: 13),
                      border: InputBorder.none,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send, color: Colors.blueAccent),
                  onPressed: () => _sendMessage(_controller.text),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
