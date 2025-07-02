import 'package:flutter/material.dart';
import '../services/notification_service.dart';
import 'package:intl/intl.dart';

class Notificationhistorypage extends StatefulWidget {
  final VoidCallback onClose;

  const Notificationhistorypage({super.key, required this.onClose});

  @override
  State<Notificationhistorypage> createState() => _NotificationhistorypageState();
}

class _NotificationhistorypageState extends State<Notificationhistorypage> {
  late Future<List<Map<String, dynamic>>> _notificationsFuture;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    setState(() {
      _isLoading = true;
    });

    _notificationsFuture = NotificationService.getNotificationHistory();

    setState(() {
      _isLoading = false;
    });
  }

  String _formatTime(String timestamp) {
    try {
      final dateTime = DateTime.parse(timestamp);
      return DateFormat.Hm().format(dateTime); // Format as hours:minutes (24-hour)
    } catch (e) {
      debugPrint('Error formatting time: $e');
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  IconButton(
                    onPressed: widget.onClose,
                    icon: const Icon(
                      Icons.arrow_back,
                      color: Colors.black54,
                      size: 24,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      body: _isLoading
        ? const Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
            ),
          )
        : FutureBuilder<List<Map<String, dynamic>>>(
            future: _notificationsFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
                  ),
                );
              } else if (snapshot.hasError) {
                return Center(
                  child: Text(
                    'Error loading notifications',
                    style: TextStyle(
                      color: Colors.red,
                      fontSize: 16,
                    ),
                  ),
                );
              } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return const Center(
                  child: Text(
                    'No notifications yet',
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: 16,
                      decoration: TextDecoration.none,
                    ),
                  ),
                );
              }

              final notifications = snapshot.data!;
              return RefreshIndicator(
                onRefresh: _loadNotifications,
                child: ListView.separated(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  itemCount: notifications.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 16),
                  itemBuilder: (context, index) {
                    final notification = notifications[index];
                    final status = notification['status'] ?? '';
                    final details = notification['details'] ?? '';
                    final createdAt = notification['created_at'] ?? '';
                    final time = _formatTime(createdAt);

                    final capitalizedStatus = status.isNotEmpty 
                        ? status[0].toUpperCase() + status.substring(1)
                        : '';

                    return Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 12,
                            height: 12,
                            margin: const EdgeInsets.only(top: 5),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: status.toLowerCase().contains('enter') 
                                  ? Colors.green 
                                  : Colors.red,
                            ),
                          ),
                          const SizedBox(width: 12),
                          
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  capitalizedStatus,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    color: Colors.black,
                                    decoration: TextDecoration.none,
                                  ),
                                ),
                                if (details.isNotEmpty) 
                                  Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Text(
                                      details,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        color: Colors.grey,
                                        decoration: TextDecoration.none,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          
                          Text(
                            time,
                            style: const TextStyle(
                              fontSize: 14,
                              color: Colors.grey,
                              decoration: TextDecoration.none,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              );
            },
          ),
    );
  }
}