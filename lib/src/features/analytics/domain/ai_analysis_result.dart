/// Type of AI insight
enum AiInsightType { tempo, overspend, budget, trend, category, income, other }

/// Parses an [AiInsightType] from a string.
AiInsightType _parseInsightType(String? type) {
  if (type == null) return AiInsightType.other;
  final lower = type.toLowerCase();

  // Direct enum name match
  for (final t in AiInsightType.values) {
    if (t.name == lower || lower.contains(t.name)) {
      return t;
    }
  }

  // Russian name mappings
  const russianMappings = {
    'темп': AiInsightType.tempo,
    'перерасход': AiInsightType.overspend,
    'бюджет': AiInsightType.budget,
    'лимит': AiInsightType.budget,
    'тренд': AiInsightType.trend,
    'категори': AiInsightType.category,
    'доход': AiInsightType.income,
  };

  for (final entry in russianMappings.entries) {
    if (lower.contains(entry.key)) {
      return entry.value;
    }
  }

  return AiInsightType.other;
}

/// A single AI-generated insight about spending habits.
class AiInsight {
  final String title;
  final AiInsightType type;
  final String observed;
  final String why;
  final String action7d;
  final String impact;

  const AiInsight({
    required this.title,
    required this.type,
    required this.observed,
    required this.why,
    required this.action7d,
    required this.impact,
  });

  factory AiInsight.fromJson(Map<String, dynamic> json) {
    return AiInsight(
      title: (json['title'] as String?) ?? '',
      type: _parseInsightType(json['type'] as String?),
      observed: (json['observed'] as String?) ?? '',
      why: (json['why'] as String?) ?? '',
      action7d: (json['action7d'] as String?) ?? '',
      impact: (json['impact'] as String?) ?? '',
    );
  }

  /// Returns true if this insight has valid content.
  bool get isValid =>
      title.isNotEmpty && observed.isNotEmpty && action7d.isNotEmpty;
}

/// Result of AI spending analysis.
class AiAnalysisResult {
  final List<AiInsight> insights;
  final String summary;
  final DateTime generatedAt;

  const AiAnalysisResult({
    required this.insights,
    required this.summary,
    required this.generatedAt,
  });

  factory AiAnalysisResult.fromJson(Map<String, dynamic> json) {
    final rawInsights = json['insights'];
    List<AiInsight> parsedInsights = [];

    if (rawInsights is List) {
      parsedInsights =
          rawInsights
              .whereType<Map<String, dynamic>>()
              .map((e) => AiInsight.fromJson(e))
              .where((insight) => insight.isValid)
              .toList();
    }

    return AiAnalysisResult(
      insights: parsedInsights,
      summary: (json['summary'] as String?) ?? '',
      generatedAt: DateTime.now(),
    );
  }

  /// Returns true if the analysis has valid, usable content.
  bool get isValid => insights.isNotEmpty && insights.length >= 2;
}
