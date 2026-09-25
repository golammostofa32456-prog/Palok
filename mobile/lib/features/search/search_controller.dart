class SearchController {
  String query = '';

  void setQuery(String value) {
    query = value.trim();
  }

  bool get hasQuery {
    return query.isNotEmpty;
  }

  void clear() {
    query = '';
  }
}
