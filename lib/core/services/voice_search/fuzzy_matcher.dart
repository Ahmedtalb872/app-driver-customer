/// String-similarity utility backing [PlaceCorrector] (Stage 3 of the
/// voice-search pipeline). Deliberately dependency-free (no pub package) -
/// correction only ever compares short place-name tokens/phrases, where a
/// plain normalized Levenshtein distance is simple to reason about, has no
/// extra install/build cost, and is fast enough to run inline as the user
/// speaks.
class FuzzyMatcher {
  const FuzzyMatcher._();

  /// 1.0 for an identical string, 0.0 for two strings with nothing in
  /// common. `1 - editDistance / max(len(a), len(b))` - a single
  /// inserted/deleted/substituted character in a 4-5 letter word (roughly
  /// what "بكر" -> "بكار" is) still scores around 0.75-0.8.
  static double similarity(String a, String b) {
    if (a == b) return 1.0;
    if (a.isEmpty || b.isEmpty) return 0.0;
    final distance = _levenshtein(a, b);
    final maxLen = a.length > b.length ? a.length : b.length;
    return 1.0 - (distance / maxLen);
  }

  static int _levenshtein(String a, String b) {
    final la = a.length;
    final lb = b.length;
    var previousRow = List<int>.generate(lb + 1, (j) => j);
    var currentRow = List<int>.filled(lb + 1, 0);

    for (var i = 1; i <= la; i++) {
      currentRow[0] = i;
      for (var j = 1; j <= lb; j++) {
        final substitutionCost = a[i - 1] == b[j - 1] ? 0 : 1;
        final deletion = previousRow[j] + 1;
        final insertion = currentRow[j - 1] + 1;
        final substitution = previousRow[j - 1] + substitutionCost;
        currentRow[j] = [
          deletion,
          insertion,
          substitution,
        ].reduce((x, y) => x < y ? x : y);
      }
      final swap = previousRow;
      previousRow = currentRow;
      currentRow = swap;
    }
    return previousRow[lb];
  }
}
