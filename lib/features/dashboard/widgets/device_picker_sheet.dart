import 'package:flutter/material.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_constants.dart';
import '../../../providers/robot_provider.dart';
import '../../../shared/widgets/glass_card.dart';

/// Modal bottom sheet: scan for nearby/bonded Bluetooth devices and
/// connect to the one running the robot's firmware.
class DevicePickerSheet extends StatefulWidget {
  const DevicePickerSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => const DevicePickerSheet(),
    );
  }

  @override
  State<DevicePickerSheet> createState() => _DevicePickerSheetState();
}

class _DevicePickerSheetState extends State<DevicePickerSheet> {
  bool _connectingTo;
  String? _connectingAddress;

  _DevicePickerSheetState() : _connectingTo = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<RobotProvider>().scanForDevices();
    });
  }

  Future<void> _connect(BluetoothDevice device) async {
    setState(() {
      _connectingTo = true;
      _connectingAddress = device.address;
    });
    final ok = await context.read<RobotProvider>().connectToDevice(device);
    if (!mounted) return;
    setState(() => _connectingTo = false);
    if (ok) {
      Navigator.of(context).pop();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not connect. Try again.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final robot = context.watch<RobotProvider>();

    return DraggableScrollableSheet(
      initialChildSize: 0.62,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: AppColors.charcoalElevated,
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(AppConstants.radiusXLarge),
            ),
          ),
          padding: const EdgeInsets.fromLTRB(
            AppConstants.spaceLg,
            AppConstants.spaceSm,
            AppConstants.spaceLg,
            AppConstants.spaceLg,
          ),
          child: Column(
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.textTertiary.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Row(
                children: [
                  Text(
                    'PAIR ROBOT',
                    style: GoogleFonts.outfit(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const Spacer(),
                  if (robot.isScanning)
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.cyan,
                      ),
                    )
                  else
                    IconButton(
                      icon: const Icon(Icons.refresh_rounded, color: AppColors.cyan),
                      onPressed: () => context.read<RobotProvider>().scanForDevices(),
                    ),
                ],
              ),
              const SizedBox(height: AppConstants.spaceSm),
              Text(
                'Select the Bluetooth module paired with your spider robot.',
                style: GoogleFonts.inter(
                  fontSize: 12.5,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: AppConstants.spaceMd),
              Expanded(
                child: robot.discoveredDevices.isEmpty
                    ? _EmptyState(scanning: robot.isScanning)
                    : ListView.separated(
                        controller: scrollController,
                        itemCount: robot.discoveredDevices.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: AppConstants.spaceSm),
                        itemBuilder: (context, index) {
                          final device = robot.discoveredDevices[index];
                          final isThisConnecting =
                              _connectingTo && _connectingAddress == device.address;
                          return GlassCard(
                            onTap: _connectingTo ? null : () => _connect(device),
                            padding: const EdgeInsets.all(AppConstants.spaceMd),
                            child: Row(
                              children: [
                                Container(
                                  width: 38,
                                  height: 38,
                                  decoration: BoxDecoration(
                                    color: AppColors.cyan.withValues(alpha: 0.14),
                                    borderRadius: BorderRadius.circular(11),
                                  ),
                                  child: const Icon(
                                    Icons.bluetooth_rounded,
                                    color: AppColors.cyan,
                                    size: 19,
                                  ),
                                ),
                                const SizedBox(width: AppConstants.spaceMd),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        device.name?.isNotEmpty == true
                                            ? device.name!
                                            : 'Unknown device',
                                        style: GoogleFonts.outfit(
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.textPrimary,
                                          fontSize: 14.5,
                                        ),
                                      ),
                                      Text(
                                        device.address,
                                        style: GoogleFonts.inter(
                                          fontSize: 11.5,
                                          color: AppColors.textTertiary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (isThisConnecting)
                                  const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: AppColors.cyan,
                                    ),
                                  )
                                else
                                  const Icon(
                                    Icons.chevron_right_rounded,
                                    color: AppColors.textTertiary,
                                  ),
                              ],
                            ),
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
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.scanning});
  final bool scanning;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.bluetooth_searching_rounded,
            size: 40,
            color: AppColors.textTertiary.withValues(alpha: 0.6),
          ),
          const SizedBox(height: AppConstants.spaceMd),
          Text(
            scanning ? 'Scanning for devices…' : 'No devices found yet.',
            style: GoogleFonts.inter(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}
