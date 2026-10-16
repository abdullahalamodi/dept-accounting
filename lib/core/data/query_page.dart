class QueryPage<T> {
  const QueryPage({
    required this.items,
    required this.total,
    required this.page,
  });

  factory QueryPage.read({
    required int total,
    required int page,
    required int pageSize,
    required List<T> Function(int limit, int offset) read,
  }) {
    if (pageSize < 1) throw ArgumentError.value(pageSize, 'pageSize');
    final last = total == 0 ? 1 : (total + pageSize - 1) ~/ pageSize;
    final current = page.clamp(1, last);
    return QueryPage(
      items: read(pageSize, (current - 1) * pageSize),
      total: total,
      page: current,
    );
  }

  final List<T> items;
  final int total;
  final int page;
}
