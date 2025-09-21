import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:petcare/core/providers/pets_provider.dart';
import 'package:petcare/core/providers/reminders_provider.dart';
import 'package:petcare/data/models/pet.dart';
import 'package:petcare/ui/widgets/common_widgets.dart';
import 'package:petcare/ui/theme/app_colors.dart';

class PetHealthScreen extends ConsumerStatefulWidget {
  const PetHealthScreen({
    super.key,
    required this.petId,
  });

  final String petId;

  @override
  ConsumerState<PetHealthScreen> createState() => _PetHealthScreenState();
}

class _PetHealthScreenState extends ConsumerState<PetHealthScreen> {
  @override
  void initState() {
    super.initState();
    // Load reminders for this specific pet
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(remindersProvider.notifier).loadReminders(widget.petId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final pet = ref.watch(petByIdProvider(widget.petId));
    final remindersState = ref.watch(remindersProvider);

    if (pet == null) {
      return Scaffold(
        appBar: AppBar(title: Text('pets.not_found'.tr())),
        body: AppEmptyState(
          icon: Icons.pets,
          title: 'pets.not_found'.tr(),
          message: 'pets.not_found_message'.tr(),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('${pet.name} - ${'tabs.health'.tr()}'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/pets/${widget.petId}'),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.read(remindersProvider.notifier).loadReminders(widget.petId),
        child: _buildBody(context, remindersState, pet),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _addReminder(context, pet),
        icon: const Icon(Icons.add),
        label: Text('reminders.add_new'.tr()),
      ),
    );
  }

  Widget _buildBody(BuildContext context, dynamic remindersState, Pet pet) {
    if (remindersState.isLoading && remindersState.reminders.isEmpty) {
      return const Center(
        child: AppLoadingIndicator(message: 'Loading reminders...'),
      );
    }

    if (remindersState.error != null) {
      return AppErrorState(
        message: remindersState.error!,
        onRetry: () => ref.read(remindersProvider.notifier).loadReminders(widget.petId),
      );
    }

    final petReminders = remindersState.reminders.where((reminder) => reminder.petId == widget.petId).toList();

    if (petReminders.isEmpty) {
      return AppEmptyState(
        icon: Icons.favorite,
        title: 'reminders.empty_title'.tr(),
        message: 'reminders.empty_message'.tr(),
        action: ElevatedButton.icon(
          onPressed: () => _addReminder(context, pet),
          icon: const Icon(Icons.add),
          label: Text('reminders.add_first'.tr()),
        ),
      );
    }

    // Group reminders by status
    final overdueReminders = petReminders.where((r) => !r.done && r.scheduledAt.isBefore(DateTime.now())).toList();
    final upcomingReminders = petReminders.where((r) => !r.done && r.scheduledAt.isAfter(DateTime.now())).toList();
    final completedReminders = petReminders.where((r) => r.done).toList();

    return ListView(
      padding: const EdgeInsets.only(bottom: 80), // Space for FAB
      children: [
        if (overdueReminders.isNotEmpty) ...[
          _ReminderSection(
            title: 'reminders.overdue'.tr(),
            reminders: overdueReminders,
            pet: pet,
            color: AppColors.error,
          ),
          const SizedBox(height: 16),
        ],
        if (upcomingReminders.isNotEmpty) ...[
          _ReminderSection(
            title: 'reminders.upcoming'.tr(),
            reminders: upcomingReminders,
            pet: pet,
            color: AppColors.warning,
          ),
          const SizedBox(height: 16),
        ],
        if (completedReminders.isNotEmpty) ...[
          _ReminderSection(
            title: '완료된 알림',
            reminders: completedReminders,
            pet: pet,
            color: AppColors.success,
          ),
        ],
      ],
    );
  }

  void _addReminder(BuildContext context, Pet pet) {
    // TODO: Navigate to add reminder with pre-selected pet
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Add reminder for ${pet.name} - Coming Soon')),
    );
  }
}

class _ReminderSection extends StatelessWidget {
  const _ReminderSection({
    required this.title,
    required this.reminders,
    required this.pet,
    required this.color,
  });

  final String title;
  final List<dynamic> reminders;
  final Pet pet;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Container(
                width: 4,
                height: 20,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${reminders.length}',
                  style: TextStyle(
                    color: color,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        ...reminders.map((reminder) => _ReminderCard(
          reminder: reminder,
          pet: pet,
          color: color,
        )),
      ],
    );
  }
}

class _ReminderCard extends StatelessWidget {
  const _ReminderCard({
    required this.reminder,
    required this.pet,
    required this.color,
  });

  final dynamic reminder;
  final Pet pet;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final isOverdue = reminder.scheduledAt.isBefore(DateTime.now()) && !reminder.done;
    final isUpcoming = reminder.scheduledAt.isAfter(DateTime.now()) && !reminder.done;
    final isCompleted = reminder.done;

    return AppCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                isCompleted 
                    ? Icons.check_circle 
                    : isOverdue 
                        ? Icons.warning 
                        : Icons.schedule,
                color: color,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    reminder.title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      decoration: isCompleted ? TextDecoration.lineThrough : null,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    DateFormat('MMM dd, yyyy - HH:mm').format(reminder.scheduledAt),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      decoration: isCompleted ? TextDecoration.lineThrough : null,
                    ),
                  ),
                  if (reminder.note != null && reminder.note.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      reminder.note,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        decoration: isCompleted ? TextDecoration.lineThrough : null,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                isCompleted 
                    ? '완료' 
                    : isOverdue 
                        ? 'overdue'.tr() 
                        : 'upcoming'.tr(),
                style: TextStyle(
                  color: color,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
