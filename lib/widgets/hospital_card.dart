import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/hospital_model.dart';

class HospitalCard extends StatelessWidget {
  final Hospital hospital;

  const HospitalCard({super.key, required this.hospital});

  Future<void> _callHospital() async {
    if (!hospital.hasPhone) return;
    final uri = Uri(scheme: 'tel', path: hospital.phone);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  bool get _hasValidCoordinates {
    return hospital.latitude >= -90 &&
        hospital.latitude <= 90 &&
        hospital.longitude >= -180 &&
        hospital.longitude <= 180 &&
        hospital.hasValidCoordinates;
  }

  Future<void> _openDirections(BuildContext context) async {
    if (!_hasValidCoordinates) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Directions are not available.')),
      );
      return;
    }

    final destination = '${hospital.latitude},${hospital.longitude}';
    final navigationUri = Uri(
      scheme: 'google.navigation',
      queryParameters: {'q': destination},
    );
    final geoUri = Uri.parse(
      'geo:${hospital.latitude},${hospital.longitude}?q=$destination',
    );
    final webUri = Uri.https('www.google.com', '/maps/dir/', {
      'api': '1',
      'destination': destination,
    });

    final launched =
        await _tryLaunchMapUri(navigationUri) ||
        await _tryLaunchMapUri(geoUri) ||
        await _tryLaunchMapUri(webUri);

    if (!launched && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open maps.')),
      );
    }
  }

  Future<bool> _tryLaunchMapUri(Uri uri) async {
    try {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      return false;
    }
  }

  String _formatDistrictName(String district) {
    return district
        .split('_')
        .map((word) {
          if (word == 'ysr') return 'YSR';
          return word[0].toUpperCase() + word.substring(1);
        })
        .join(' ');
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            colors: [Colors.white, Colors.grey.shade50],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.red.shade200, width: 1),
                    ),
                    child: Icon(
                      Icons.local_hospital,
                      color: Colors.red.shade700,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          hospital.name,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Colors.black87,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.blue.shade50,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.location_city,
                                    size: 12,
                                    color: Colors.blue.shade700,
                                  ),
                                  const SizedBox(width: 3),
                                  Text(
                                    _formatDistrictName(hospital.district),
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.blue.shade700,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.green.shade50,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.straighten,
                                    size: 12,
                                    color: Colors.green.shade700,
                                  ),
                                  const SizedBox(width: 3),
                                  Text(
                                    '${hospital.distanceKm.toStringAsFixed(1)} km',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.green.shade700,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (hospital.address.isNotEmpty && hospital.address != 'nan') ...[
                Row(
                  children: [
                    Icon(Icons.place, size: 14, color: Colors.grey.shade600),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        hospital.address,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade700,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
              ],
              if (hospital.hasPhone) ...[
                Row(
                  children: [
                    Icon(Icons.phone, size: 14, color: Colors.grey.shade600),
                    const SizedBox(width: 6),
                    Text(
                      hospital.phone,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade700,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.green.shade100,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.phone_in_talk,
                            size: 11,
                            color: Colors.green.shade700,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            'Available',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.green.shade700,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
              ] else ...[
                Row(
                  children: [
                    Icon(
                      Icons.phone_disabled,
                      size: 14,
                      color: Colors.grey.shade400,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Phone not available',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade500,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
              ],
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: hospital.hasPhone ? _callHospital : null,
                      icon: const Icon(Icons.call, size: 18),
                      label: const Text('Call'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: hospital.hasPhone
                            ? Colors.green.shade600
                            : Colors.grey.shade300,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        elevation: 1,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _hasValidCoordinates
                          ? () => _openDirections(context)
                          : null,
                      icon: const Icon(Icons.directions, size: 18),
                      label: const Text('Directions'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _hasValidCoordinates
                            ? Colors.blue.shade600
                            : Colors.grey.shade300,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        elevation: 1,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
