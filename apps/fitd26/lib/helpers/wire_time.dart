/// Timezone handling for challenge times crossing the wire.
///
/// The room service historically emitted NAIVE ISO-8601 strings (no `Z`, no
/// offset) produced from `DateTime.now()` in a UTC container; it now emits
/// explicit UTC strings with a `Z` suffix. Both shapes denote a UTC instant,
/// so this module parses them identically:
///
///   parseWireTime('2026-08-21T10:00:00.000Z')  // UTC, correct instant
///   parseWireTime('2026-08-21T10:00:00.000')   // legacy: treated as UTC
///
/// The result is always a UTC [DateTime]. Compare instants directly with
/// `DateTime.now()` (`isAfter`, `difference` — both are instant-correct
/// across zones) and convert `.toLocal()` only at display edges.
library;

/// Parses an ISO-8601 timestamp from the room service as a UTC instant.
///
/// A string carrying an explicit zone designator (`Z` or `±hh:mm`) is parsed
/// as written and normalized to UTC. A legacy NAIVE string (no designator)
/// is interpreted as UTC — NOT as local time, which is `DateTime.parse`'s
/// default and would shift the instant by the client's offset.
DateTime parseWireTime(String iso) {
  if (hasZoneDesignator(iso)) return DateTime.parse(iso).toUtc();
  return DateTime.parse('${iso}Z');
}

/// True when [iso] carries an explicit zone designator: a trailing `Z`/`z`
/// or a `±hh:mm` / `±hhmm` / `±hh` offset after the time part. (The `-`
/// separators in the date part are not zone designators.)
bool hasZoneDesignator(String iso) {
  if (iso.endsWith('Z') || iso.endsWith('z')) return true;
  final t = iso.indexOf('T');
  if (t < 0) return false;
  final time = iso.substring(t + 1);
  return time.contains('+') || time.contains('-');
}
