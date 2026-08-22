extension MapExtension<K, V> on Map<K, V> {
  Iterable<(K, V)> get records => entries.map((e) => (e.key, e.value));
}
