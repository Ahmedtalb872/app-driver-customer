import 'package:flutter_test/flutter_test.dart';

import 'package:alhudhud/models/models.dart';

void main() {
  group('DocumentType', () {
    test('dbValue round-trips through fromDb for every value', () {
      for (final type in DocumentType.values) {
        expect(DocumentTypeX.fromDb(type.dbValue), type);
      }
    });

    test('every type except additionalDocument is mandatory', () {
      for (final type in DocumentType.values) {
        expect(type.isMandatory, type != DocumentType.additionalDocument);
      }
    });

    test(
      'exactly the identity/license/registration/insurance types typically have expiry',
      () {
        const expected = {
          DocumentType.nationalIdFront,
          DocumentType.nationalIdBack,
          DocumentType.drivingLicenseFront,
          DocumentType.drivingLicenseBack,
          DocumentType.vehicleRegistrationFront,
          DocumentType.vehicleRegistrationBack,
          DocumentType.vehicleInsurance,
        };
        for (final type in DocumentType.values) {
          expect(type.typicallyHasExpiry, expected.contains(type));
        }
      },
    );

    test('fromDb falls back to additionalDocument for an unknown value', () {
      expect(
        DocumentTypeX.fromDb('something_unexpected'),
        DocumentType.additionalDocument,
      );
    });
  });

  group('DocumentStatus', () {
    test('dbValue round-trips through fromDb for every value', () {
      for (final status in DocumentStatus.values) {
        expect(DocumentStatusX.fromDb(status.dbValue), status);
      }
    });

    test('fromDb defaults to pending for an unknown value', () {
      expect(DocumentStatusX.fromDb('nonsense'), DocumentStatus.pending);
    });
  });

  group('CaptainDocument', () {
    test('mandatoryTypes has exactly 9 entries, allTypes has 10', () {
      expect(CaptainDocument.mandatoryTypes.length, 9);
      expect(CaptainDocument.allTypes.length, 10);
      expect(CaptainDocument.allTypes.toSet(), DocumentType.values.toSet());
      expect(
        CaptainDocument.mandatoryTypes.contains(
          DocumentType.additionalDocument,
        ),
        isFalse,
      );
    });

    test('fromRow parses a full row correctly', () {
      final doc = CaptainDocument.fromRow({
        'id': 'doc-1',
        'captain_id': 'captain-1',
        'document_type': 'national_id_front',
        'file_path': 'captains/captain-1/national_id_front/123_id.jpg',
        'file_name': 'id.jpg',
        'mime_type': 'image/jpeg',
        'file_size': 204800,
        'uploaded_at': '2026-07-01T10:00:00Z',
        'expires_at': '2030-01-01T00:00:00Z',
        'status': 'approved',
        'rejection_reason': null,
        'reviewed_by': 'admin-1',
        'reviewed_at': '2026-07-02T10:00:00Z',
      });

      expect(doc.id, 'doc-1');
      expect(doc.captainId, 'captain-1');
      expect(doc.documentType, DocumentType.nationalIdFront);
      expect(doc.mimeType, 'image/jpeg');
      expect(doc.fileSize, 204800);
      expect(doc.status, DocumentStatus.approved);
      expect(doc.reviewedBy, 'admin-1');
      expect(doc.isEffectivelyExpired, isFalse);
    });

    test('isEffectivelyExpired is true once expiresAt is in the past', () {
      final doc = CaptainDocument.fromRow({
        'id': 'doc-2',
        'captain_id': 'captain-1',
        'document_type': 'vehicle_insurance',
        'file_path': 'captains/captain-1/vehicle_insurance/1_ins.pdf',
        'file_name': 'ins.pdf',
        'mime_type': 'application/pdf',
        'file_size': 51200,
        'uploaded_at': '2020-01-01T00:00:00Z',
        'expires_at': '2021-01-01T00:00:00Z',
        'status': 'approved',
      });

      expect(doc.isEffectivelyExpired, isTrue);
    });

    test('isEffectivelyExpired is false when expiresAt is null', () {
      final doc = CaptainDocument.fromRow({
        'id': 'doc-3',
        'captain_id': 'captain-1',
        'document_type': 'profile_photo',
        'file_path': 'captains/captain-1/profile_photo/1_p.jpg',
        'file_name': 'p.jpg',
        'mime_type': 'image/jpeg',
        'file_size': 10240,
        'uploaded_at': '2026-07-01T00:00:00Z',
        'status': 'pending',
      });

      expect(doc.expiresAt, isNull);
      expect(doc.isEffectivelyExpired, isFalse);
    });
  });
}
