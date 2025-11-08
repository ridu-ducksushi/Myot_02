import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:petcare/core/providers/records_provider.dart';
import 'package:petcare/core/providers/pets_provider.dart';
import 'package:petcare/data/models/record.dart';
import 'package:petcare/ui/widgets/common_widgets.dart';
import 'package:petcare/ui/theme/app_colors.dart';

class RecordsScreen extends ConsumerStatefulWidget {
  const RecordsScreen({super.key});

  @override
  ConsumerState<RecordsScreen> createState() => _RecordsScreenState();
}

class _RecordsScreenState extends ConsumerState<RecordsScreen> {
  @override
  void initState() {
    super.initState();
    // Load records when screen initializes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(recordsProvider.notifier).loadRecords();
    });
  }

  @override
  Widget build(BuildContext context) {
    final recordsState = ref.watch(recordsProvider);
    final todaysRecords = ref.watch(todaysRecordsProvider);

    return Scaffold(
      appBar: AppCustomAppBar(
        title: Text('records.title'.tr()),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showAddRecordDialog(context),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.read(recordsProvider.notifier).loadRecords(),
        child: _buildBody(context, recordsState, todaysRecords),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddRecordDialog(context),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildBody(BuildContext context, RecordsState state, List<Record> todaysRecords) {
    if (state.isLoading && state.records.isEmpty) {
      return const Center(
        child: AppLoadingIndicator(message: 'Loading records...'),
      );
    }

    if (state.error != null) {
      return AppErrorState(
        message: state.error!,
        onRetry: () => ref.read(recordsProvider.notifier).loadRecords(),
      );
    }

    return CustomScrollView(
      slivers: [
        // Today's Records Section
        if (todaysRecords.isNotEmpty) ...[
          SliverToBoxAdapter(
            child: SectionHeader(
              title: 'records.today'.tr(),
              subtitle: '${todaysRecords.length} ${'records.entries'.tr()}',
            ),
          ),
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) => _RecordCard(record: todaysRecords[index]),
              childCount: todaysRecords.length,
            ),
          ),
        ],

        // All Records Section
        SliverToBoxAdapter(
          child: SectionHeader(
            title: 'records.all'.tr(),
            subtitle: '${state.records.length} ${'records.total'.tr()}',
          ),
        ),

        if (state.records.isEmpty)
          SliverFillRemaining(
            child: AppEmptyState(
              icon: Icons.list_alt,
              title: 'records.empty_title'.tr(),
              message: 'records.empty_message'.tr(),
              action: ElevatedButton.icon(
                onPressed: () => _showAddRecordDialog(context),
                icon: const Icon(Icons.add),
                label: Text('records.add_first'.tr()),
              ),
            ),
          )
        else
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) => _RecordCard(record: state.records[index]),
              childCount: state.records.length,
            ),
          ),

        // Bottom padding for FAB
        const SliverToBoxAdapter(
          child: SizedBox(height: 80),
        ),
      ],
    );
  }

  void _showAddRecordDialog(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => const _AddRecordSheet(),
    );
  }
}

class _RecordCard extends ConsumerWidget {
  const _RecordCard({required this.record});

  final Record record;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final typeColor = AppColors.getRecordTypeColor(record.type);
    final pet = ref.watch(petByIdProvider(record.petId));

    return AppCard(
      onTap: () => _showRecordDetails(context, record),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Type Icon
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: typeColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(25),
                border: Border.all(color: typeColor.withOpacity(0.3)),
              ),
              child: Icon(
                _getRecordIcon(record.type),
                color: typeColor,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            
            // Record Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          record.title,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      RecordTypeChip(type: record.type, size: ChipSize.small),
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
                  if (record.content != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      record.content!,
                      style: Theme.of(context).textTheme.bodySmall,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: 8),
                  Text(
                    DateFormat('MMM dd, yyyy • HH:mm').format(record.at),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            
            // Arrow
            Icon(
              Icons.chevron_right,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }

  IconData _getRecordIcon(String type) {
    switch (type.toLowerCase()) {
      case 'meal':
        return Icons.restaurant;
      case 'snack':
        return Icons.cookie;
      case 'med':
      case 'medicine':
        return Icons.medical_services;
      case 'vaccine':
        return Icons.vaccines;
      case 'visit':
        return Icons.local_hospital;
      case 'weight':
        return Icons.monitor_weight;
      case 'litter':
        return Icons.cleaning_services;
      case 'play':
        return Icons.sports_tennis;
      case 'groom':
        return Icons.content_cut;
      default:
        return Icons.note;
    }
  }

  void _showRecordDetails(BuildContext context, Record record) {
    // TODO: Navigate to record details
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Record details: ${record.title}')),
    );
  }
}

class _AddRecordSheet extends ConsumerStatefulWidget {
  const _AddRecordSheet();

  @override
  ConsumerState<_AddRecordSheet> createState() => _AddRecordSheetState();
}

class _AddRecordSheetState extends ConsumerState<_AddRecordSheet> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  final FocusNode _titleFocusNode = FocusNode();
  final FocusNode _contentFocusNode = FocusNode();
  
  String _selectedType = 'meal';
  String? _selectedPetId;
  DateTime _selectedDateTime = DateTime.now();
  
  final List<String> _recordTypes = [
    'meal', 'snack', 'med', 'vaccine', 'visit', 'weight', 'litter', 'play', 'groom', 'other'
  ];

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    _titleFocusNode.dispose();
    _contentFocusNode.dispose();
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
                    'records.add_new'.tr(),
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
                            labelText: 'records.select_pet'.tr(),
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
                              return 'records.pet_required'.tr();
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
                        
                        // Record Type
                        DropdownButtonFormField<String>(
                          value: _selectedType,
                          decoration: InputDecoration(
                            labelText: 'records.type'.tr(),
                            prefixIcon: const Icon(Icons.category),
                          ),
                          items: _recordTypes.map((type) {
                            return DropdownMenuItem(
                              value: type,
                              child: Row(
                                children: [
                                  Icon(
                                    _getRecordIcon(type),
                                    size: 16,
                                    color: AppColors.getRecordTypeColor(type),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(type.toUpperCase()),
                                ],
                              ),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setState(() {
                              _selectedType = value!;
                            });
                            FocusScope.of(context).requestFocus(_contentFocusNode);
                          },
                        ),
                        const SizedBox(height: 16),
                        
                        AppTextField(
                          controller: _titleController,
                          labelText: 'records.title'.tr(),
                          prefixIcon: const Icon(Icons.title),
                          textInputAction: TextInputAction.next,
                          autofocus: true,
                          focusNode: _titleFocusNode,
                          onSubmitted: (_) =>
                              FocusScope.of(context).requestFocus(_contentFocusNode),
                          validator: (value) {
                            if (value?.trim().isEmpty ?? true) {
                              return 'records.title_required'.tr();
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        
                        AppTextField(
                          controller: _contentController,
                          labelText: 'records.content'.tr(),
                          prefixIcon: const Icon(Icons.note),
                          maxLines: 3,
                          focusNode: _contentFocusNode,
                        ),
                        const SizedBox(height: 16),
                        
                        ListTile(
                          leading: const Icon(Icons.schedule),
                          title: Text('records.datetime'.tr()),
                          subtitle: Text(
                            DateFormat('MMM dd, yyyy • HH:mm').format(_selectedDateTime),
                          ),
                          onTap: _selectDateTime,
                          contentPadding: EdgeInsets.zero,
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
                          onPressed: _saveRecord,
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

  IconData _getRecordIcon(String type) {
    switch (type.toLowerCase()) {
      case 'meal':
        return Icons.restaurant;
      case 'snack':
        return Icons.cookie;
      case 'med':
      case 'medicine':
        return Icons.medical_services;
      case 'vaccine':
        return Icons.vaccines;
      case 'visit':
        return Icons.local_hospital;
      case 'weight':
        return Icons.monitor_weight;
      case 'litter':
        return Icons.cleaning_services;
      case 'play':
        return Icons.sports_tennis;
      case 'groom':
        return Icons.content_cut;
      default:
        return Icons.note;
    }
  }

  Future<void> _selectDateTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _selectedDateTime,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    
    if (date != null && mounted) {
      final time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(_selectedDateTime),
      );
      
      if (time != null) {
        setState(() {
          _selectedDateTime = DateTime(
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

  Future<void> _saveRecord() async {
    if (!_formKey.currentState!.validate()) return;
    
    final record = Record(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      petId: _selectedPetId!,
      type: _selectedType,
      title: _titleController.text.trim(),
      content: _contentController.text.trim().isEmpty ? null : _contentController.text.trim(),
      at: _selectedDateTime,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    
    await ref.read(recordsProvider.notifier).addRecord(record);
    
    if (mounted) {
      Navigator.of(context).pop();
    }
  }
}
