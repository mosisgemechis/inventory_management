import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/subscription_service.dart';
import '../constants/colors.dart';
import '../../features/subscription/subscription_screen.dart';

class SubscriptionBanner extends StatelessWidget {
  const SubscriptionBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<SubscriptionService>(
      builder: (context, subService, _) {
        final sub = subService.current;
        if (sub == null) return const SizedBox.shrink();

        final isExpired = sub.isExpired;
        final isTrial = sub.isTrial;
        final remaining = sub.remainingTime;

        final isLowTime = !isExpired && remaining.inMinutes < 3;

        if (!isExpired && !isLowTime) {
           return const SizedBox.shrink(); // Don't show if plenty of time left (unless expired)
        }

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: isExpired 
                ? AppColors.danger.withOpacity(0.1) 
                : (isLowTime ? Colors.amber.withOpacity(0.1) : AppColors.secondary.withOpacity(0.1)),
            border: Border(
              bottom: BorderSide(
                color: isExpired 
                    ? AppColors.danger.withOpacity(0.3) 
                    : (isLowTime ? Colors.amber.withOpacity(0.3) : AppColors.secondary.withOpacity(0.3)),
              ),
            ),
          ),
          child: Row(
            children: [
              Icon(
                isExpired ? Icons.warning_amber_rounded : Icons.info_outline_rounded,
                color: isExpired ? AppColors.danger : (isLowTime ? Colors.amber[700] : AppColors.secondary),
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      isExpired 
                        ? (isTrial ? "Your trial has expired." : "Your subscription has expired.")
                        : "${isTrial ? 'Trial' : 'Subscription'} expires in ${_formatDuration(remaining)}",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: isExpired ? AppColors.danger : (isLowTime ? Colors.amber[900] : AppColors.secondary),
                        fontSize: 13,
                      ),
                    ),
                    Text(
                      isExpired 
                        ? "Restricted to read-only mode. Subscribe to continue managing your business."
                        : "Renew your subscription to enjoy uninterrupted business management.",
                      style: TextStyle(
                        color: (isExpired ? AppColors.danger : (isLowTime ? (Colors.amber[900] ?? Colors.amber) : AppColors.secondary)).withOpacity(0.8),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const SubscriptionScreen()),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: isExpired ? AppColors.danger : (isLowTime ? Colors.amber[700] : AppColors.secondary),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  elevation: 0,
                ),
                child: Text(isExpired ? "SUBSCRIBE NOW" : "RENEW"),
              ),
            ],
          ),
        );
      },
    );
  }

  String _formatDuration(Duration duration) {
    if (duration.inMinutes < 60) {
      return "${duration.inMinutes}m ${duration.inSeconds % 60}s";
    } else {
      return "${duration.inHours}h ${duration.inMinutes % 60}m";
    }
  }
}
