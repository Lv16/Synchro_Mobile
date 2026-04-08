import '../domain/entities/pending_sync_item.dart';

const String _metaEntityAliasKey = '__entity_alias';
const String _metaDependsOnKey = '__depends_on';
const String _localRefPrefix = '@local:';
const String _serverRefPrefix = '@ref:';

List<PendingSyncItem> pruneSyncedItemsKeepingDependencies(
  List<PendingSyncItem> items,
) {
  if (items.isEmpty) {
    return const <PendingSyncItem>[];
  }

  final byUuid = <String, PendingSyncItem>{
    for (final item in items) item.clientUuid: item,
  };
  final byAlias = <String, PendingSyncItem>{};
  for (final item in items) {
    final alias = _normalizeAlias(item.payload[_metaEntityAliasKey]);
    if (alias != null && !byAlias.containsKey(alias)) {
      byAlias[alias] = item;
    }
    if (!byAlias.containsKey(item.clientUuid)) {
      byAlias[item.clientUuid] = item;
    }
  }

  final keysToVisit = <String>[];
  for (final item in items) {
    if (item.state == SyncState.synced) {
      continue;
    }
    keysToVisit.addAll(_collectDependencyKeys(item.payload));
  }

  final retainSyncedUuids = <String>{};
  final visitedItemUuids = <String>{};
  var cursor = 0;

  while (cursor < keysToVisit.length) {
    final depKey = keysToVisit[cursor].trim();
    cursor += 1;
    if (depKey.isEmpty) {
      continue;
    }

    final depItem = byUuid[depKey] ?? byAlias[depKey];
    if (depItem == null) {
      continue;
    }
    if (!visitedItemUuids.add(depItem.clientUuid)) {
      continue;
    }

    if (depItem.state == SyncState.synced) {
      retainSyncedUuids.add(depItem.clientUuid);
    }
    keysToVisit.addAll(_collectDependencyKeys(depItem.payload));
  }

  return items
      .where((item) {
        if (item.state != SyncState.synced) {
          return true;
        }
        return retainSyncedUuids.contains(item.clientUuid);
      })
      .toList(growable: false);
}

List<String> _collectDependencyKeys(Map<String, dynamic> payload) {
  final out = <String>{};

  void addKey(dynamic raw) {
    final key = (raw ?? '').toString().trim();
    if (key.isNotEmpty) {
      out.add(key);
    }
  }

  final explicit = payload[_metaDependsOnKey];
  if (explicit is List) {
    for (final entry in explicit) {
      addKey(entry);
    }
  } else if (explicit is Map) {
    for (final entry in explicit.values) {
      addKey(entry);
    }
  } else if (explicit != null) {
    addKey(explicit);
  }

  void walk(dynamic value) {
    if (value is String) {
      final raw = value.trim();
      if (raw.startsWith(_localRefPrefix)) {
        addKey(raw.substring(_localRefPrefix.length));
      } else if (raw.startsWith(_serverRefPrefix)) {
        addKey(raw.substring(_serverRefPrefix.length));
      }
      return;
    }

    if (value is List) {
      for (final entry in value) {
        walk(entry);
      }
      return;
    }

    if (value is Map) {
      if (value.length == 1 && value.containsKey(r'$ref')) {
        addKey(value[r'$ref']);
      }
      for (final entry in value.values) {
        walk(entry);
      }
    }
  }

  walk(payload);
  return out.toList(growable: false);
}

String? _normalizeAlias(dynamic value) {
  final alias = (value ?? '').toString().trim();
  if (alias.isEmpty) {
    return null;
  }
  return alias;
}
