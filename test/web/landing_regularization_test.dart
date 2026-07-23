import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sahara_club_spa_web/config/web_media_paths.dart';

void main() {
  group('Landing media regularization', () {
    test('uses the recovered main web video with case-sensitive path', () {
      expect(kHeroVideoWebUrl, 'assets/assets/videos/Portada-2.mp4');
      expect(kHeroVideoWebUrl, isNot(contains('portada.mp4')));

      final assetPath = kHeroVideoWebUrl.replaceFirst('assets/', '');
      final video = File(assetPath);
      expect(video.existsSync(), isTrue);
      expect(video.lengthSync(), greaterThan(0));
    });

    test('keeps poster and music fallbacks resolvable from web paths', () {
      for (final webPath in [kHeroPosterWebUrl, kBackgroundMusicWebUrl]) {
        final assetPath = webPath.replaceFirst('assets/', '');
        expect(File(assetPath).existsSync(), isTrue, reason: assetPath);
      }
    });

    test('declared pubspec asset directories exist and are populated', () {
      final pubspec = File('pubspec.yaml').readAsStringSync();
      final declaredAssets = RegExp(
        r'^\s+-\s+(assets/[^\r\n]+)$',
        multiLine: true,
      ).allMatches(pubspec).map((match) => match.group(1)!.trim()).toList();

      expect(declaredAssets, contains('assets/images/'));
      expect(declaredAssets, contains('assets/videos/'));
      expect(declaredAssets, contains('assets/musica/'));
      expect(declaredAssets, contains('assets/experiencia/'));

      for (final asset in declaredAssets) {
        final entityType = asset.endsWith('/')
            ? FileSystemEntityType.directory
            : FileSystemEntityType.file;
        expect(FileSystemEntity.typeSync(asset), entityType, reason: asset);
        if (entityType == FileSystemEntityType.directory) {
          expect(
            Directory(asset).listSync().whereType<File>(),
            isNotEmpty,
            reason: asset,
          );
        }
      }
    });

    test('experience pillars use recovered multimedia assets', () {
      final source = File(
        'lib/widgets/experience_section.dart',
      ).readAsStringSync();
      for (final asset in [
        'assets/experiencia/01-presencia.png',
        'assets/experiencia/02-conexion.png',
        'assets/experiencia/03-transformacion.png',
      ]) {
        expect(source, contains(asset));
        expect(File(asset).existsSync(), isTrue, reason: asset);
      }
    });
  });

  group('Landing sections and navigation', () {
    test('landing composes public sections and concierge overlay', () {
      final source = File('lib/pages/landing_page.dart').readAsStringSync();
      for (final widgetName in [
        'HeroSection',
        'ServicesSection',
        'ExperienceSection',
        'FeaturedSection',
        'ContactSection',
        'Footer',
        'Navbar',
        'ConciergeChat',
      ]) {
        expect(source, contains(widgetName));
      }
    });

    test('navbar keeps links to every public landing section', () {
      final source = File('lib/pages/landing_page.dart').readAsStringSync();
      for (final target in [
        '_heroKey',
        '_servicesKey',
        '_experienceKey',
        '_newsKey',
        '_contactKey',
      ]) {
        expect(source, contains(target));
      }
      for (var index = 0; index <= 4; index++) {
        expect(source, contains('case $index:'));
      }
    });
  });

  group('Store and admin safeguards', () {
    test('store keeps Gift Card Digital fulfillment path', () {
      final source = File(
        'lib/features/store/store_page.dart',
      ).readAsStringSync();
      expect(source, contains('GiftCardPage'));
      expect(source, contains('StoreProductType.giftCard'));
      expect(source, contains('_fallbackGiftCardProduct'));
      expect(source, contains('categoryKey: \'gift_cards\''));
    });

    test('AI panel stays client-side and does not expose runtime secrets', () {
      final source = File(
        'lib/features/admin/ai_control_panel.dart',
      ).readAsStringSync();
      expect(source, contains('ai_settings'));
      expect(source, isNot(contains('SERVICE_ROLE')));
      expect(source, isNot(contains('SUPABASE_SERVICE_ROLE_KEY')));
      expect(source, isNot(contains('get_anthropic_api_key')));
      expect(source, contains('Apagado'));
      expect(source, contains('Piloto'));
      expect(source, contains('Publico'));
    });

    test(
      'concierge client delegates to hardened edge function with local caps',
      () {
        final source = File(
          'lib/widgets/concierge_chat.dart',
        ).readAsStringSync();
        expect(source, contains('web_concierge'));
        expect(source, contains('_maxMessagesToSend = 16'));
        expect(source, contains('_maxMessageChars = 1200'));
        expect(source, isNot(contains('SERVICE_ROLE')));
        expect(source, isNot(contains('ANTHROPIC')));
      },
    );
  });
}
