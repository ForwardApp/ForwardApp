import 'package:aught/screens/contactUs_screen.dart';
import 'package:aught/screens/policyOfPrivacy_screen.dart';
import 'package:flutter/material.dart';
import 'package:aught/widgets/SideBarElements/sidebar_button.dart';
import 'package:aught/screens/notificationHistory_screen.dart';
import 'package:aught/screens/setting_screen.dart';

class Sidebar extends StatelessWidget {
  final VoidCallback onClose;

  const Sidebar({super.key, required this.onClose});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: MediaQuery.of(context).size.width * 1, // 0.9 for 90% width
      height: double.infinity,
      color: Colors.white,
      child: SafeArea(
        child: Column(
          children: [
            // Top bar with close button
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  IconButton(
                    onPressed: onClose,
                    icon: const Icon(
                      Icons.close,
                      color: Colors.black54,
                      size: 32,
                    ),
                  ),
                ],
              ),
            ),
            // Sidebar content in Expanded
            Expanded(
              child: ListView(
                children: [
                  SidebarButton(
                    icon: Icons.notifications,
                    label: 'Notification History',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder:
                              (context) => Notificationhistorypage(
                                onClose: () {
                                  Navigator.pop(context);
                                },
                              ),
                        ),
                      );
                    },
                  ),
                  const Divider(
                    height: 1,
                    thickness: 1,
                    indent: 16,
                    endIndent: 16,
                  ),
                  SidebarButton(
                    icon: Icons.settings,
                    label: 'Settings',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder:
                              (context) => Settingpage(
                                onClose: () {
                                  Navigator.pop(context);
                                },
                              ),
                        ),
                      );
                    },
                  ),
                  const Divider(
                    height: 1,
                    thickness: 1,
                    indent: 16,
                    endIndent: 16,
                  ),
                  SidebarButton(
                    icon: Icons.help_outline,
                    label: 'Contact Us',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder:
                              (context) => Contactuspage(
                                onClose: () {
                                  Navigator.pop(context);
                                },
                              ),
                        ),
                      );
                    },
                  ),
                  const Divider(
                    height: 1,
                    thickness: 1,
                    indent: 16,
                    endIndent: 16,
                  ),
                  SidebarButton(
                    icon: Icons.privacy_tip,
                    label: 'Privacy Policy',
                     onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder:
                              (context) => Policyofprivacy(
                                onClose: () {
                                  Navigator.pop(context);
                                },
                              ),
                        ),
                      );
                    },
                  ),
                  const Divider(
                    height: 1,
                    thickness: 1,
                    indent: 16,
                    endIndent: 16,
                  ),
                ],
              ),
            ),
            // Company logo at the bottom
            Padding(
              padding: const EdgeInsets.only(bottom: 10.0),
              child: Center(
                child: Image.asset(
                  'lib/assets/companylogo copy.webp',
                  height: 60,
                  width: 120,
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}