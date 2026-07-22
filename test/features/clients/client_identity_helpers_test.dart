import 'package:flutter_test/flutter_test.dart';
import 'package:sahara_club_spa_web/features/clients/client_identity_helpers.dart';

void main() {
  group('client identity helpers', () {
    test('normalizes Baja/MX phone numbers into a stable canonical value', () {
      expect(normalizeClientPhone('646 151 9597'), '526461519597');
      expect(normalizeClientPhone('+52 646 151 9597'), '526461519597');
      expect(normalizeClientPhone('+5216461519597'), '526461519597');
      expect(normalizeClientPhone('0052 646 151 9597'), '526461519597');
      expect(normalizeClientPhone(''), '');
    });

    test(
      'formats canonical phones for display without changing unknown shapes',
      () {
        expect(displayPhoneFromCanonical('526461519597'), '646 151 9597');
        expect(displayPhoneFromCanonical('16025877771'), '16025877771');
      },
    );

    test(
      'normalizes emails and ignores synthetic placeholders for matching',
      () {
        expect(normalizeClientEmail(' ANA@Example.COM '), 'ana@example.com');
        expect(isSyntheticClientEmail('cliente@sahara.local'), isTrue);
        expect(isSyntheticClientEmail('ana@example.com'), isTrue);
        expect(isSyntheticClientEmail('ana@gmail.com'), isFalse);
        expect(
          clientEmailsLikelyMatch('ana@example.com', 'ANA@example.com'),
          isFalse,
        );
        expect(
          clientEmailsLikelyMatch('ana@gmail.com', 'ANA@gmail.com'),
          isTrue,
        );
      },
    );

    test('detects probable duplicates by phone, email, or anchored name', () {
      expect(clientPhonesLikelyMatch('6461519597', '+52 646 151 9597'), isTrue);
      expect(
        clientsLikelyDuplicate(
          leftPhone: '6461519597',
          rightPhone: '+52 646 151 9597',
          leftEmail: null,
          rightEmail: null,
          leftName: 'Ana Lopez',
          rightName: 'Ana Maria',
        ),
        isTrue,
      );
      expect(
        clientsLikelyDuplicate(
          leftPhone: null,
          rightPhone: null,
          leftEmail: 'ana@gmail.com',
          rightEmail: 'ANA@gmail.com',
          leftName: null,
          rightName: null,
        ),
        isTrue,
      );
      expect(
        clientsLikelyDuplicate(
          leftPhone: null,
          rightPhone: '6461519597',
          leftEmail: null,
          rightEmail: null,
          leftName: 'Ana Lopez',
          rightName: ' ana lopez ',
        ),
        isTrue,
      );
      expect(
        clientsLikelyDuplicate(
          leftPhone: null,
          rightPhone: null,
          leftEmail: null,
          rightEmail: null,
          leftName: 'Ana Lopez',
          rightName: 'Ana Lopez',
        ),
        isFalse,
      );
    });

    test('chooses the oldest client record as canonical', () {
      expect(
        canonicalClientRecordId(
          leftId: 'client-b',
          leftCreatedAt: DateTime.utc(2026, 7, 22),
          rightId: 'client-a',
          rightCreatedAt: DateTime.utc(2026, 7, 21),
        ),
        'client-a',
      );
      expect(
        canonicalClientRecordId(
          leftId: 'client-b',
          leftCreatedAt: DateTime.utc(2026, 7, 22),
          rightId: 'client-a',
          rightCreatedAt: DateTime.utc(2026, 7, 22),
        ),
        'client-a',
      );
    });
  });
}
