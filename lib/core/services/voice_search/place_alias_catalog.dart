import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import 'arabic_text_normalizer.dart';

/// One entry from `assets/data/places.json`: a canonical local place name
/// plus every spelling/mishearing a speech recognizer is known to produce
/// for it. New places are added by editing that JSON file alone - neither
/// this class nor [PlaceCorrector] needs to change to pick them up.
class PlaceAliasEntry {
  PlaceAliasEntry({required this.id, required this.canonical, required this.aliases, this.category});

  final String id;
  final String canonical;
  final List<String> aliases;
  final String? category;

  factory PlaceAliasEntry.fromJson(Map<String, dynamic> json) {
    return PlaceAliasEntry(
      id: json['id'] as String,
      canonical: json['canonical'] as String,
      aliases: (json['aliases'] as List? ?? const [])
          .map((e) => e as String)
          .toList(),
      category: json['category'] as String?,
    );
  }

  /// Every surface form (the canonical name plus all aliases) worth
  /// comparing a spoken phrase against, pre-normalized once here so
  /// [PlaceCorrector] never re-normalizes the same alias for every window
  /// it tries.
  late final List<String> normalizedSurfaceForms = [
    ArabicTextNormalizer.normalize(canonical),
    ...aliases.map(ArabicTextNormalizer.normalize),
  ];
}

/// Loads and caches `assets/data/places.json` - the editable local-place
/// alias dataset. A singleton so the (small) JSON asset is only ever parsed
/// once per app run; [reload] exists for tests/tooling that need to force a
/// re-read.
class PlaceAliasCatalog {
  PlaceAliasCatalog._();

  static final PlaceAliasCatalog instance = PlaceAliasCatalog._();

  static const _assetPath = 'assets/data/places.json';

  List<PlaceAliasEntry>? _entries;

  Future<List<PlaceAliasEntry>> load() async {
    final cached = _entries;
    if (cached != null) return cached;

    try {
      final raw = await rootBundle.loadString(_assetPath);
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      final list = (decoded['places'] as List? ?? const [])
          .cast<Map<String, dynamic>>()
          .map(PlaceAliasEntry.fromJson)
          .toList();
      _entries = list;
      return list;
    } catch (_) {
      // Missing/malformed asset never blocks voice search - it just runs
      // without local corrections, falling back entirely to the server's
      // own fuzzy search (Stage 5, see search_destinations).
      _entries = const [];
      return const [];
    }
  }

  void reload() => _entries = null;
}
