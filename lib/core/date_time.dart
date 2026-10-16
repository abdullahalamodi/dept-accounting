String formatDocumentDateTime(String value) {
  // Older documents only recorded a calendar date.
  if (value.length == 10) return value;
  final date = DateTime.tryParse(value)?.toLocal();
  return date == null
      ? value
      : date.toIso8601String().substring(0, 16).replaceFirst('T', ' ');
}
