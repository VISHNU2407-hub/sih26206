import 'package:flutter/material.dart';

class PermissionStatusCard extends StatelessWidget {
  final bool smsGranted;
  final bool phoneGranted;
  final bool locationGranted;
  final int guardianCount;

  const PermissionStatusCard({
    super.key,
    required this.smsGranted,
    required this.phoneGranted,
    required this.locationGranted,
    required this.guardianCount,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            colors: [
              Colors.white,
              Colors.grey.shade50,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.security,
                    color: const Color(0xFFE91E63),
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Emergency Status',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFFE91E63),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _buildPermissionRow(
                'SMS Permission',
                smsGranted,
                Icons.sms,
              ),
              const SizedBox(height: 12),
              _buildPermissionRow(
                'Phone Permission',
                phoneGranted,
                Icons.phone,
              ),
              const SizedBox(height: 12),
              _buildPermissionRow(
                'Location Permission',
                locationGranted,
                Icons.location_on,
              ),
              const SizedBox(height: 12),
              _buildGuardianCountRow(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPermissionRow(String label, bool granted, IconData icon) {
    return Row(
      children: [
        Icon(
          icon,
          size: 18,
          color: granted ? Colors.green : Colors.orange,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[700],
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: granted
                ? Colors.green.withOpacity(0.1)
                : Colors.orange.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: granted ? Colors.green : Colors.orange,
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                granted ? Icons.check_circle : Icons.warning,
                size: 14,
                color: granted ? Colors.green : Colors.orange,
              ),
              const SizedBox(width: 4),
              Text(
                granted ? 'Granted' : 'Not Granted',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: granted ? Colors.green : Colors.orange,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildGuardianCountRow() {
    final hasGuardians = guardianCount > 0;
    return Row(
      children: [
        Icon(
          Icons.contacts,
          size: 18,
          color: hasGuardians ? Colors.green : Colors.orange,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            'Guardians Available',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[700],
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: hasGuardians
                ? Colors.green.withOpacity(0.1)
                : Colors.orange.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: hasGuardians ? Colors.green : Colors.orange,
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                hasGuardians ? Icons.check_circle : Icons.warning,
                size: 14,
                color: hasGuardians ? Colors.green : Colors.orange,
              ),
              const SizedBox(width: 4),
              Text(
                '$guardianCount',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: hasGuardians ? Colors.green : Colors.orange,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
