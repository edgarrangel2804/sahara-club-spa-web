const int kGiftCardDedicationMaxLength = 350;

class GiftCardFormInput {
  const GiftCardFormInput({
    required this.recipientName,
    required this.recipientPhone,
    required this.senderName,
    required this.validFrom,
    required this.termsAccepted,
    this.dedicationMessage = '',
    this.sendCopyToBuyer = false,
  });

  final String recipientName;
  final String recipientPhone;
  final String senderName;
  final DateTime validFrom;
  final bool termsAccepted;
  final String dedicationMessage;
  final bool sendCopyToBuyer;
}

class GiftCardFormValidation {
  const GiftCardFormValidation({
    required this.ok,
    this.message,
    this.recipientPhoneE164,
    this.dedicationMessage = '',
    this.validFrom,
    this.expiresOn,
    this.sendCopyToBuyer = false,
  });

  final bool ok;
  final String? message;
  final String? recipientPhoneE164;
  final String dedicationMessage;
  final DateTime? validFrom;
  final DateTime? expiresOn;
  final bool sendCopyToBuyer;
}

GiftCardFormValidation validateGiftCardForm(
  GiftCardFormInput input, {
  DateTime? now,
}) {
  final today = dateOnly(now ?? DateTime.now());
  final validFrom = dateOnly(input.validFrom);
  final recipientName = input.recipientName.trim();
  final senderName = input.senderName.trim();
  if (recipientName.isEmpty) {
    return const GiftCardFormValidation(
      ok: false,
      message: 'Escribe el nombre del destinatario.',
    );
  }
  final phone = normalizeGiftCardPhoneE164(input.recipientPhone);
  if (phone == null) {
    return const GiftCardFormValidation(
      ok: false,
      message: 'Escribe un WhatsApp valido.',
    );
  }
  if (senderName.isEmpty) {
    return const GiftCardFormValidation(
      ok: false,
      message: 'Escribe el nombre de quien regala.',
    );
  }
  if (validFrom.isBefore(today)) {
    return const GiftCardFormValidation(
      ok: false,
      message: 'La fecha de inicio no puede ser pasada.',
    );
  }
  if (!input.termsAccepted) {
    return const GiftCardFormValidation(
      ok: false,
      message: 'Acepta las condiciones para continuar.',
    );
  }

  final dedication = sanitizeGiftCardDedication(input.dedicationMessage);
  return GiftCardFormValidation(
    ok: true,
    recipientPhoneE164: phone,
    dedicationMessage: dedication,
    validFrom: validFrom,
    expiresOn: addGiftCardCalendarMonths(validFrom, 3),
    sendCopyToBuyer: input.sendCopyToBuyer,
  );
}

String sanitizeGiftCardDedication(String value) {
  final normalized = value
      .replaceAll('\r\n', '\n')
      .replaceAll('\r', '\n')
      .replaceAll(RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]'), '')
      .replaceAll(RegExp(r'<[^>\n]*>'), '')
      .replaceAll(RegExp(r'[<>]'), '')
      .replaceAll(RegExp(r'\n{3,}'), '\n\n')
      .trim();
  final chars = normalized.runes.toList();
  if (chars.length <= kGiftCardDedicationMaxLength) return normalized;
  return String.fromCharCodes(chars.take(kGiftCardDedicationMaxLength));
}

String? normalizeGiftCardPhoneE164(String value) {
  var digits = value.replaceAll(RegExp(r'\D'), '');
  if (digits.startsWith('00')) digits = digits.substring(2);
  if (digits.length == 13 && digits.startsWith('521')) {
    digits = '52${digits.substring(digits.length - 10)}';
  } else if (digits.length == 10) {
    digits = '52$digits';
  }
  if (!RegExp(r'^[1-9]\d{9,14}$').hasMatch(digits)) return null;
  return '+$digits';
}

DateTime dateOnly(DateTime value) =>
    DateTime(value.year, value.month, value.day);

DateTime addGiftCardCalendarMonths(DateTime value, int months) {
  final monthIndex = value.month - 1 + months;
  final year = value.year + (monthIndex ~/ 12);
  final month = (monthIndex % 12) + 1;
  final day = value.day.clamp(1, daysInMonth(year, month)).toInt();
  return DateTime(year, month, day);
}

int daysInMonth(int year, int month) => DateTime(year, month + 1, 0).day;

String giftCardDateParam(DateTime value) {
  final d = dateOnly(value);
  return '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}

String giftCardDateLabel(DateTime value) {
  final d = dateOnly(value);
  return '${d.day.toString().padLeft(2, '0')}/'
      '${d.month.toString().padLeft(2, '0')}/'
      '${d.year.toString().padLeft(4, '0')}';
}

bool shouldIgnoreGiftCardTap({required bool submitting}) => submitting;
