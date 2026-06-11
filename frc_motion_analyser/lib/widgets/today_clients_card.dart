import 'package:flutter/material.dart';

import '../models/client_summary.dart';
import '../theme/tokens.dart';
import '../utils/client_display.dart';

/// "今日客戶" card — DESIGN SPEC.md §3 版面 + 驗收標準 (empty state).
class TodayClientsCard extends StatelessWidget {
  const TodayClientsCard({
    super.key,
    required this.clients,
    required this.now,
    required this.onAddClient,
    required this.onSelectClient,
  });

  final List<ClientSummary> clients;
  final DateTime now;
  final VoidCallback onAddClient;
  final ValueChanged<ClientSummary> onSelectClient;

  @override
  Widget build(BuildContext context) {
    if (clients.isEmpty) {
      return _EmptyClientsState(onAddClient: onAddClient);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.line),
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: Column(
        children: [
          for (var i = 0; i < clients.length; i++)
            _ClientRow(
              client: clients[i],
              now: now,
              showDivider: i != clients.length - 1,
              onTap: () => onSelectClient(clients[i]),
            ),
        ],
      ),
    );
  }
}

class _ClientRow extends StatelessWidget {
  const _ClientRow({
    required this.client,
    required this.now,
    required this.showDivider,
    required this.onTap,
  });

  final ClientSummary client;
  final DateTime now;
  final bool showDivider;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final display = clientHighlightDisplay(client, now);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 13),
        decoration: BoxDecoration(
          border: showDivider
              ? const Border(bottom: BorderSide(color: AppColors.line))
              : null,
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.surface2,
                border: Border.all(color: AppColors.line),
              ),
              child: Text(
                client.initials,
                style: AppText.display(
                  size: 14,
                  weight: FontWeight.w600,
                  color: AppColors.orange,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    client.name,
                    style: AppText.body(size: 14, weight: FontWeight.w600),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    clientMetaText(client, now),
                    style: AppText.data(size: 11, color: AppColors.muted),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  display.valueText,
                  style: AppText.data(size: 13, color: display.color),
                ),
                if (display.labelText.isNotEmpty)
                  Text(
                    display.labelText,
                    style: AppText.data(size: 9, color: AppColors.muted),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// 驗收標準: 無客戶時顯示empty state（邀請加入第一位客戶，唔係空白）。
class _EmptyClientsState extends StatelessWidget {
  const _EmptyClientsState({required this.onAddClient});

  final VoidCallback onAddClient;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.line),
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: Column(
        children: [
          Text(
            '今日未有預約客戶',
            style: AppText.body(size: 14, weight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          Text(
            '新增第一位客戶，開始第一次FRC評估',
            textAlign: TextAlign.center,
            style: AppText.data(size: 11, color: AppColors.muted),
          ),
          const SizedBox(height: 14),
          GestureDetector(
            onTap: onAddClient,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 10,
              ),
              decoration: BoxDecoration(
                color: AppColors.orange,
                borderRadius: BorderRadius.circular(AppRadius.chip),
              ),
              child: Text(
                '+ 新增客戶',
                style: AppText.body(
                  size: 13,
                  weight: FontWeight.w600,
                  color: AppColors.ink,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
