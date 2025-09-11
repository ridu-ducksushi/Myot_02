import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:petcare/core/providers/reminders_provider.dart';
import 'package:petcare/core/providers/pets_provider.dart';
import 'package:petcare/data/models/reminder.dart';
import 'package:petcare/ui/widgets/common_widgets.dart';
import 'package:petcare/ui/theme/app_colors.dart';

class RemindersScreen extends ConsumerStatefulWidget {
  const RemindersScreen({super.key});

  @override
  ConsumerState<RemindersScreen> createState() => _RemindersScreenState();
}

class _RemindersScreenState extends ConsumerState<RemindersScreen> {
  @override
  void initState() {
    super.initState();
    // Load reminders when screen initializes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(remindersProvider.notifier).loadReminders();
    });
  }

  @override
  Widget build(BuildContext context) {
    final remindersState = ref.watch(remindersProvider);
    final upcomingReminders = ref.watch(upcomingRemindersProvider);
    final overdueReminders = ref.watch(overdueRemindersProvider);

    return Scaffold(
      appBar: AppCustomAppBar(
        title: Text('reminders.title'.tr()),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showAddReminderDialog(context),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.read(remindersProvider.notifier).loadReminders(),
        child: _buildBody(context, remindersState, upcomingReminders, overdueReminders),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddReminderDialog(context),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildBody(
    BuildContext context, 
    RemindersState state, 
    List<Reminder> upcoming,
    List<Reminder> overdue,
  ) {
    if (state.isLoading && state.reminders.isEmpty) {
      return const Center(
        child: AppLoadingIndicator(message: 'Loading reminders...'),
      );
    }

    if (state.error != null) {
      return AppErrorState(
        message: state.error!,
        onRetry: () => ref.read(remindersProvider.notifier).loadReminders(),
      );
    }

    return CustomScrollView(
      slivers: [
        // Overdue Section
        if (overdue.isNotEmpty) ...[
          SliverToBoxAdapter(
            child: SectionHeader(
              title: 'reminders.overdue'.tr(),
              subtitle: '${overdue.length} ${'reminders.urgent'.tr()}',
            ),
          ),
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) => _ReminderCard(
                reminder: overdue[index], 
                isOverdue: true,
              ),
              childCount: overdue.length,
            ),
          ),
        ],

        // Upcoming Section
        if (upcoming.isNotEmpty) ...[
          SliverToBoxAdapter(
            child: SectionHeader(
              title: 'reminders.upcoming'.tr(),
              subtitle: '${upcoming.length} ${'reminders.next_week'.tr()}',
            ),
          ),
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) => _ReminderCard(reminder: upcoming[index]),
              childCount: upcoming.length,
            ),
          ),
        ],

        // All Reminders Section
        SliverToBoxAdapter(
          child: SectionHeader(
            title: 'reminders.all'.tr(),
            subtitle: '${state.reminders.length} ${'reminders.total'.tr()}',
          ),
        ),

        if (state.reminders.isEmpty)
          SliverFillRemaining(
            child: AppEmptyState(
              icon: Icons.notification_add,
              title: 'reminders.empty_title'.tr(),
              message: 'reminders.empty_message'.tr(),
              action: ElevatedButton.icon(
                onPressed: () => _showAddReminderDialog(context),
                icon: const Icon(Icons.add),
                label: Text('reminders.add_first'.tr()),
              ),
            ),
          )
        else
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) => _ReminderCard(reminder: state.reminders[index]),
              childCount: state.reminders.length,
            ),
          ),

        // Bottom padding for FAB
        const SliverToBoxAdapter(
          child: SizedBox(height: 80),
        ),
      ],
    );
  }

  void _showAddReminderDialog(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => const _AddReminderSheet(),
    );
  }
}

class _ReminderCard extends ConsumerWidget {
  const _ReminderCard({
    required this.reminder,
    this.isOverdue = false,
  });

  final Reminder reminder;
  final bool isOverdue;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pet = ref.watch(petByIdProvider(reminder.petId));
    final now = DateTime.now();
    final isToday = reminder.scheduledAt.day == now.day &&
                   reminder.scheduledAt.month == now.month &&
                   reminder.scheduledAt.year == now.year;

    return AppCard(
      onTap: () => _showReminderDetails(context, reminder),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Priority/Status Indicator
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: isOverdue 
                    ? AppColors.error.withOpacity(0.1)
                    : reminder.done
                        ? AppColors.success.withOpacity(0.1)
                        : AppColors.warning.withOpacity(0.1),
                borderRadius: BorderRadius.circular(25),
                border: Border.all(
                  color: isOverdue 
                      ? AppColors.error.withOpacity(0.3)
                      : reminder.done
                          ? AppColors.success.withOpacity(0.3)
                          : AppColors.warning.withOpacity(0.3),
                ),
              ),
              child: Icon(
                reminder.done
                    ? Icons.check_circle
                    : isOverdue
                        ? Icons.warning
                        : Icons.schedule,
                color: isOverdue 
                    ? AppColors.error
                    : reminder.done
                        ? AppColors.success
                        : AppColors.warning,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            
            // Reminder Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          reminder.title,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            decoration: reminder.done ? TextDecoration.lineThrough : null,
                          ),
                        ),
                      ),
                      if (isToday)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.info.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            'reminders.today'.tr(),
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppColors.info,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                    ],
                  ),
                  if (pet != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      pet.name,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                  if (reminder.note != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      reminder.note!,
                      style: Theme.of(context).textTheme.bodySmall,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        Icons.schedule,
                        size: 14,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        DateFormat('MMM dd, yyyy • HH:mm').format(reminder.scheduledAt),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: isOverdue ? AppColors.error : null,
                          fontWeight: isOverdue ? FontWeight.w600 : null,
                        ),
                      ),
                      if (reminder.repeatRule != null) ...[
                        const SizedBox(width: 8),
                        Icon(
                          Icons.repeat,
                          size: 14,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          reminder.repeatRule!,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            
            // Actions
            Column(
              children: [
                if (!reminder.done)
                  IconButton(
                    icon: Icon(
                      Icons.check_circle_outline,
                      color: AppColors.success,
                    ),
                    onPressed: () => _markAsDone(ref, reminder.id),
                  ),
                Icon(
                  Icons.chevron_right,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _markAsDone(WidgetRef ref, String reminderId) {
    ref.read(remindersProvider.notifier).markReminderDone(reminderId);
  }

  void _showReminderDetails(BuildContext context, Reminder reminder) {
    // TODO: Navigate to reminder details
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Reminder details: ${reminder.title}')),
    );
  }
}

class _AddReminderSheet extends ConsumerStatefulWidget {
  const _AddReminderSheet();

  @override
  ConsumerState<_AddReminderSheet> createState() => _AddReminderSheetState();
}

class _AddReminderSheetState extends ConsumerState<_AddReminderSheet> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _noteController = TextEditingController();
  
  String _selectedType = 'medicine';
  String? _selectedPetId;
  DateTime _scheduledDateTime = DateTime.now().add(const Duration(hours: 1));
  String? _repeatRule;
  
  final List<String> _reminderTypes = [
    'medicine', 'vaccine', 'visit', 'grooming', 'feeding', 'exercise', 'other'
  ];

  final List<String> _repeatOptions = [
    'daily', 'weekly', 'monthly', 'yearly'
  ];

  @override
  void dispose() {
    _titleController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final petsState = ref.watch(petsProvider);
    
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: DraggableScrollableSheet(
        initialChildSize: 0.9,
        maxChildSize: 0.9,
        minChildSize: 0.5,
        expand: false,
        builder: (context, scrollController) {
          return Container(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  // Handle
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.outline,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Title
                  Text(
                    'reminders.add_new'.tr(),
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 24),
                  
                  // Form fields
                  Expanded(
                    child: ListView(
                      controller: scrollController,
                      children: [
                        // Pet Selection
                        DropdownButtonFormField<String>(
                          value: _selectedPetId,
                          decoration: InputDecoration(
                            labelText: 'reminders.select_pet'.tr(),
                            prefixIcon: const Icon(Icons.pets),
                          ),
                          items: petsState.pets.map((pet) {
                            return DropdownMenuItem(
                              value: pet.id,
                              child: Text(pet.name),
                            );
                          }).toList(),
                          validator: (value) {
                            if (value == null) {
                              return 'reminders.pet_required'.tr();
                            }
                            return null;
                          },
                          onChanged: (value) {
                            setState(() {
                              _selectedPetId = value;
                            });
                          },
                        ),
                        const SizedBox(height: 16),
                        
                        // Reminder Type
                        DropdownButtonFormField<String>(
                          value: _selectedType,
                          decoration: InputDecoration(
                            labelText: 'reminders.type'.tr(),
                            prefixIcon: const Icon(Icons.category),
                          ),
                          items: _reminderTypes.map((type) {
                            return DropdownMenuItem(
                              value: type,
                              child: Text(type.toUpperCase()),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setState(() {
                              _selectedType = value!;
                            });
                          },
                        ),
                        const SizedBox(height: 16),
                        
                        AppTextField(
                          controller: _titleController,
                          labelText: 'reminders.title'.tr(),
                          prefixIcon: const Icon(Icons.title),
                          validator: (value) {
                            if (value?.trim().isEmpty ?? true) {
                              return 'reminders.title_required'.tr();
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        
                        AppTextField(
                          controller: _noteController,
                          labelText: 'reminders.note'.tr(),
                          prefixIcon: const Icon(Icons.note),
                          maxLines: 3,
                        ),
                        const SizedBox(height: 16),
                        
                        ListTile(
                          leading: const Icon(Icons.schedule),
                          title: Text('reminders.scheduled_time'.tr()),
                          subtitle: Text(
                            DateFormat('MMM dd, yyyy • HH:mm').format(_scheduledDateTime),
                          ),
                          onTap: _selectDateTime,
                          contentPadding: EdgeInsets.zero,
                        ),
                        const SizedBox(height: 16),
                        
                        // Repeat Option
                        DropdownButtonFormField<String?>(
                          value: _repeatRule,
                          decoration: InputDecoration(
                            labelText: 'reminders.repeat'.tr(),
                            prefixIcon: const Icon(Icons.repeat),
                          ),
                          items: [
                            DropdownMenuItem<String?>(
                              value: null,
                              child: Text('reminders.no_repeat'.tr()),
                            ),
                            ..._repeatOptions.map((option) {
                              return DropdownMenuItem(
                                value: option,
                                child: Text(option.toUpperCase()),
                              );
                            }),
                          ],
                          onChanged: (value) {
                            setState(() {
                              _repeatRule = value;
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                  
                  // Buttons
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: Text('common.cancel'.tr()),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: FilledButton(
                          onPressed: _saveReminder,
                          child: Text('common.save'.tr()),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _selectDateTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _scheduledDateTime,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    
    if (date != null && mounted) {
      final time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(_scheduledDateTime),
      );
      
      if (time != null) {
        setState(() {
          _scheduledDateTime = DateTime(
            date.year,
            date.month,
            date.day,
            time.hour,
            time.minute,
          );
        });
      }
    }
  }

  Future<void> _saveReminder() async {
    if (!_formKey.currentState!.validate()) return;
    
    final reminder = Reminder(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      petId: _selectedPetId!,
      type: _selectedType,
      title: _titleController.text.trim(),
      note: _noteController.text.trim().isEmpty ? null : _noteController.text.trim(),
      scheduledAt: _scheduledDateTime,
      repeatRule: _repeatRule,
      createdAt: DateTime.now(),
    );
    
    await ref.read(remindersProvider.notifier).addReminder(reminder);
    
    if (mounted) {
      Navigator.of(context).pop();
    }
  }
}
