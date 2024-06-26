import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timely/modules/home/controllers/tasks_today_controller.dart';
import 'package:timely/modules/home/repositories/tasks_today_repo.dart';
import 'package:timely/modules/tab_3/controllers/output_controller.dart';
import 'package:timely/modules/tab_3/models/ad_hoc_model.dart';
import 'package:timely/modules/tab_3/repositories/tab_3_repo.dart';

class Tab3InputNotifier extends Notifier<AdHocModel> {
  @override
  AdHocModel build() {
    return AdHocModel(
      name: "",
      priority: 1,
      date: DateTime.now(),
      notifOn: true,
    );
  }

  setActivity(String activity) {
    state.name = activity;
  }

  setDate(DateTime date) {
    state = state.copyWith(date: date);
  }

  setTime(TimeOfDay time) {
    state =
        state.copyWith(time: time, reminders: {}); // Also, reset any reminders
  }

  void setPriority(int index) {
    state = state.copyWith(priority: index);
  }

  void removeDateAndTime() {
    state.date = null;
    state.startTime = null;
  }

  Future<void> syncToDB() async {
    state.uuid == null
        ? await (ref.read(tab3RepositoryProvider.notifier).writeModel(state))
        : await (ref.read(tab3RepositoryProvider.notifier).editModel(state));

    ref.invalidate(tab3OutputProvider);

    await ref.read(tasksTodayRepositoryProvider.notifier).generateTodaysTasks();
    ref.invalidate(tasksTodayOutputProvider);
  }

  void setModel(AdHocModel model) async {
    state = model;
  }
}

final tab3InputProvider =
    NotifierProvider<Tab3InputNotifier, AdHocModel>(Tab3InputNotifier.new);
