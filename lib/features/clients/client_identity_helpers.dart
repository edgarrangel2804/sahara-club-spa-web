String normalizeClientPhone(String? raw) {
  var digits = (raw ?? '').replaceAll(RegExp(r'\D'), '');
  if (digits.startsWith('00')) {
    digits = digits.substring(2);
  }
  if (digits.length == 10) {
    return '52$digits';
  }
  if (digits.length == 13 && digits.startsWith('521')) {
    return '52${digits.substring(3)}';
  }
  if (digits.length == 12 && digits.startsWith('52')) {
    return digits;
  }
  return digits;
}

String displayPhoneFromCanonical(String canonical) {
  final value = canonical.trim();
  if (value.length == 12 && value.startsWith('52')) {
    final local = value.substring(2);
    return '${local.substring(0, 3)} ${local.substring(3, 6)} ${local.substring(6)}';
  }
  return value;
}

String normalizeClientEmail(String? raw) {
  return (raw ?? '').trim().toLowerCase();
}

bool isSyntheticClientEmail(String? raw) {
  final email = normalizeClientEmail(raw);
  if (email.isEmpty) return false;
  return email.contains('synthetic') ||
      email.contains('noemail') ||
      email.endsWith('@sahara.local') ||
      email.endsWith('@saharaclubspa.local') ||
      email.endsWith('@example.com');
}

bool clientPhonesLikelyMatch(String? left, String? right) {
  final a = normalizeClientPhone(left);
  final b = normalizeClientPhone(right);
  return a.isNotEmpty && a == b;
}

bool clientEmailsLikelyMatch(String? left, String? right) {
  final a = normalizeClientEmail(left);
  final b = normalizeClientEmail(right);
  if (a.isEmpty || b.isEmpty) return false;
  if (isSyntheticClientEmail(a) || isSyntheticClientEmail(b)) return false;
  return a == b;
}

bool clientsLikelyDuplicate({
  required String? leftPhone,
  required String? rightPhone,
  required String? leftEmail,
  required String? rightEmail,
  required String? leftName,
  required String? rightName,
}) {
  if (clientPhonesLikelyMatch(leftPhone, rightPhone)) return true;
  if (clientEmailsLikelyMatch(leftEmail, rightEmail)) return true;
  final aName = (leftName ?? '').trim().toLowerCase();
  final bName = (rightName ?? '').trim().toLowerCase();
  if (aName.isEmpty || bName.isEmpty || aName != bName) return false;
  return normalizeClientPhone(leftPhone).isNotEmpty ||
      normalizeClientPhone(rightPhone).isNotEmpty ||
      normalizeClientEmail(leftEmail).isNotEmpty ||
      normalizeClientEmail(rightEmail).isNotEmpty;
}

String canonicalClientRecordId({
  required String leftId,
  required DateTime leftCreatedAt,
  required String rightId,
  required DateTime rightCreatedAt,
}) {
  if (leftCreatedAt.isBefore(rightCreatedAt)) return leftId;
  if (rightCreatedAt.isBefore(leftCreatedAt)) return rightId;
  return leftId.compareTo(rightId) <= 0 ? leftId : rightId;
}
