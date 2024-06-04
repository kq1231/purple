import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timely/modules/completed_tasks/completed_tasks_repository.dart';
import 'package:timely/modules/tab_3/models/tab_3_model.dart';
import 'package:timely/reusables.dart';
import 'package:timely/modules/completed_tasks/task_model.dart';
import "dart:collection";

// This is the repository for tab 3.
// Repositories have one job: communicate with the external, third world.
// In our case, this repository is supposed to perform CRUD operations
// on tab 3 database.
// The methods of the repository are then used by the controllers.
// Using repositories eliminates code duplication as we do not have to copy-and-paste
// the same CRUD logic across all our providers.

class Tab3RepositoryNotifier extends Notifier<void> {
  @override
  void build() {}

  Future<Map<String, dynamic>> fetchModels({bool? fetchCompleted}) async {
    final scheduled = (ref.read(dbFilesProvider)).requireValue[3]![0];
    final nonScheduled = (ref.read(dbFilesProvider)).requireValue[3]![1];

    final scheduledContent = jsonDecode(await scheduled.readAsString());
    final nonScheduledContent = jsonDecode(await nonScheduled.readAsString());

    File completedFile = ref.read(dbFilesProvider).requireValue[3]!.last;
    Map completedContent = jsonDecode(await completedFile.readAsString());

    final dates = fetchCompleted == true
        ? completedContent['scheduled'].keys.toList()
        : scheduledContent.keys.toList();

    Map<String, dynamic> tab3Models = {
      "scheduled": {},
      "nonScheduled": [],
    };

    if (fetchCompleted == true) {
      for (String date in dates) {
        tab3Models["scheduled"]![date] = [];
        for (Map content in completedContent['scheduled'][date] ?? {}) {
          tab3Models["scheduled"]![date]!.add(
            Tab3Model.fromJson(
              DateTime.parse(date),
              content,
            ),
          );
        }
      }
    } else {
      for (String date in dates) {
        tab3Models["scheduled"]![date] = [];
        for (Map content in scheduledContent[date]) {
          tab3Models["scheduled"]![date]!.add(
            Tab3Model.fromJson(
              DateTime.parse(date),
              content,
            ),
          );
        }
      }

      tab3Models["scheduled"] =
          SplayTreeMap<String, List>.from(tab3Models["scheduled"], (a, b) {
        return a.compareTo(b);
      });

      for (var date in tab3Models["scheduled"].keys) {
        List<Tab3Model> models =
            tab3Models["scheduled"][date].cast<Tab3Model>();
        models.sort((a, b) => DateTime(0, 0, 0, a.time!.hour, a.time!.minute)
            .difference(DateTime(0, 0, 0, b.time!.hour, b.time!.minute))
            .inSeconds);
      }
    }

    if (fetchCompleted == true) {
      for (Map modelMap in completedContent["unscheduled"]) {
        tab3Models["nonScheduled"] = [
          ...tab3Models["nonScheduled"],
          Tab3Model.fromJson(null, modelMap)
        ];
      }
    } else {
      for (Map modelMap in nonScheduledContent) {
        tab3Models["nonScheduled"] = [
          ...tab3Models["nonScheduled"],
          Tab3Model.fromJson(null, modelMap)
        ];
      }
    }

    return tab3Models;
  }

  Future<List<Tab3Model>> fetchNonScheduledModels() async {
    final nonScheduled = (ref.read(dbFilesProvider)).requireValue[3]![1];
    final nonScheduledContent = jsonDecode(await nonScheduled.readAsString());

    List<Tab3Model> models = [];

    for (Map modelMap in nonScheduledContent) {
      models.add(Tab3Model.fromJson(null, modelMap));
    }

    return models;
  }

  Future<void> writeModel(Tab3Model model) async {
    final scheduledFile = (ref.read(dbFilesProvider)).requireValue[3]![0];
    final nonScheduledFile = (ref.read(dbFilesProvider)).requireValue[3]![1];

    final scheduledContent = jsonDecode(await scheduledFile.readAsString());
    final nonScheduledContent =
        jsonDecode(await nonScheduledFile.readAsString());

    var jsonifiedModel = model.toJson();

    if (model.date != null && model.time != null) {
      String date = model.date.toString().substring(0, 10);

      if (!scheduledContent.keys.contains(date)) {
        scheduledContent[date] = [];
      }

      scheduledContent[date] = [
        ...scheduledContent[date], // -> Existing data
        // New data:
        jsonifiedModel,
      ];
      await scheduledFile.writeAsString(jsonEncode(scheduledContent));
    } else {
      nonScheduledContent.add(
        jsonifiedModel,
      );
      await nonScheduledFile.writeAsString(jsonEncode(nonScheduledContent));
    }
  }

  Future<void> deleteModel(Tab3Model model, {bool? completed}) async {
    // Fetch the data
    final scheduled = (ref.read(dbFilesProvider)).requireValue[3]![0];
    final nonScheduled = (ref.read(dbFilesProvider)).requireValue[3]![1];

    final scheduledContent = jsonDecode(await scheduled.readAsString());
    final nonScheduledContent = jsonDecode(await nonScheduled.readAsString());

    // TODO Inshaa Allah :: Implement Delete for Completed Tasks
    // File completedFile = ref.read(dbFilesProvider).requireValue[3]!.last;
    // Map completedContent = jsonDecode(await completedFile.readAsString());

    // Loop through the dates
    // Delete the model from the data if model.uuid == $model.uuid
    for (String date in scheduledContent.keys) {
      scheduledContent[date].removeWhere((modelMap) {
        return modelMap["ID"] == model.uuid;
      });
    }

    // Remove the date entirely if it is empty
    scheduledContent.removeWhere((key, value) => value.length == 0);

    // Persist the data
    await scheduled.writeAsString(jsonEncode(scheduledContent));

    nonScheduledContent.removeWhere((element) => element["ID"] == model.uuid);
    await nonScheduled.writeAsString(jsonEncode(nonScheduledContent));
  }

  Future<void> editModel(Tab3Model model) async {
    await deleteModel(model);
    await writeModel(model);
  }

  Future<void> markComplete(Tab3Model model) async {
    // Delete from pending
    await deleteModel(model);

    // Write to completed
    File completedFile = (ref.read(dbFilesProvider)).requireValue[3]!.last;
    Map content = jsonDecode(await completedFile.readAsString());

    // If model was a scheduled one, then save it along with the date
    if (model.date != null) {
      content['scheduled'][model.date.toString().substring(0, 10)] = [
        model.toJson(),
        ...content['scheduled'][model.date.toString().substring(0, 10)] ?? {}
      ];
    } else {
      content['unscheduled'] = [...content['unscheduled'], model.toJson()];
    }

    await completedFile.writeAsString(jsonEncode(content));

    // ------ Mark globally complete -------
    Task task = Task(
      name: model.name,
      tabNumber: 3,
      model: model,
      timestamp: DateTime.now(),
    );
    await ref
        .read(completedTasksRepositoryProvider.notifier)
        .markGloballyComplete(task);
  }
}

final tab3RepositoryProvider =
    NotifierProvider<Tab3RepositoryNotifier, void>(Tab3RepositoryNotifier.new);
