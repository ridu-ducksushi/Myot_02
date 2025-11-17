import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:petcare/utils/app_constants.dart';
import 'package:table_calendar/table_calendar.dart';

Future<DateTime?> showRecordCalendarDialog({
  required BuildContext context,
  required DateTime initialDate,
  required Set<DateTime> markedDates,
  DateTime? firstDay,
  DateTime? lastDay,
}) async {
  DateTime focusedDay = initialDate;
  DateTime? tempSelected = initialDate;

  return showDialog<DateTime>(
    context: context,
    builder: (dialogContext) => Dialog(
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.defaultPadding),
        child: StatefulBuilder(
          builder: (context, setState) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TableCalendar(
                  firstDay: firstDay ?? DateTime(2000),
                  lastDay: lastDay ?? DateTime.now(),
                  focusedDay: focusedDay,
                  calendarFormat: CalendarFormat.month,
                  selectedDayPredicate: (day) => isSameDay(day, tempSelected),
                  onDaySelected: (selectedDay, newFocusedDay) {
                    setState(() {
                      tempSelected = selectedDay;
                      focusedDay = newFocusedDay;
                    });
                    Navigator.pop(
                      dialogContext,
                      DateTime(
                        selectedDay.year,
                        selectedDay.month,
                        selectedDay.day,
                      ),
                    );
                  },
                  headerStyle: const HeaderStyle(
                    formatButtonVisible: false,
                    titleCentered: true,
                  ),
                  calendarStyle: CalendarStyle(
                    todayDecoration: BoxDecoration(
                      color: Theme.of(
                        dialogContext,
                      ).colorScheme.primary.withOpacity(0.3),
                      shape: BoxShape.circle,
                    ),
                    selectedDecoration: BoxDecoration(
                      color: Theme.of(dialogContext).colorScheme.primary,
                      shape: BoxShape.circle,
                    ),
                  ),
                  calendarBuilders: CalendarBuilders(
                    defaultBuilder: (context, day, focusedDay) {
                      final hasRecord = markedDates.any(
                        (d) => isSameDay(d, day),
                      );
                      if (!hasRecord) return null;
                      return _CalendarDayMarker(
                        day: day,
                        textStyle: const TextStyle(fontSize: 16),
                        markerColor: Theme.of(context).colorScheme.primary,
                      );
                    },
                    todayBuilder: (context, day, focusedDay) {
                      final hasRecord = markedDates.any(
                        (d) => isSameDay(d, day),
                      );
                      return DecoratedBox(
                        decoration: BoxDecoration(
                          color: Theme.of(
                            context,
                          ).colorScheme.primary.withOpacity(0.3),
                          shape: BoxShape.circle,
                        ),
                        child: _CalendarDayMarker(
                          day: day,
                          bold: true,
                          markerColor: hasRecord
                              ? Theme.of(context).colorScheme.primary
                              : null,
                        ),
                      );
                    },
                    selectedBuilder: (context, day, focusedDay) {
                      final hasRecord = markedDates.any(
                        (d) => isSameDay(d, day),
                      );
                      return DecoratedBox(
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primary,
                          shape: BoxShape.circle,
                        ),
                        child: _CalendarDayMarker(
                          day: day,
                          bold: true,
                          textColor: Colors.white,
                          markerColor: hasRecord ? Colors.white : null,
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: AppConstants.largeSpacing),
                const SizedBox(height: AppConstants.largeSpacing),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => Navigator.pop(dialogContext),
                    child: Text('common.cancel'.tr()),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    ),
  );
}

class _CalendarDayMarker extends StatelessWidget {
  const _CalendarDayMarker({
    required this.day,
    this.bold = false,
    this.textColor,
    this.markerColor,
    this.textStyle,
  });

  final DateTime day;
  final bool bold;
  final Color? textColor;
  final Color? markerColor;
  final TextStyle? textStyle;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '${day.day}',
            style: (textStyle ?? const TextStyle(fontSize: 16)).copyWith(
              fontWeight: bold ? FontWeight.bold : FontWeight.normal,
              color: textColor,
            ),
          ),
          if (markerColor != null)
            Container(
              width: AppConstants.calendarMarkerSize,
              height: AppConstants.calendarMarkerSize,
              margin: const EdgeInsets.only(
                top: AppConstants.calendarMarkerGap,
              ),
              decoration: BoxDecoration(
                color: markerColor,
                shape: BoxShape.circle,
              ),
            ),
        ],
      ),
    );
  }
}
