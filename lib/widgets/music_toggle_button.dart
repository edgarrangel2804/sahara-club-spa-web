import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/global_audio_player.dart';

class MusicToggleButton extends StatelessWidget {
  const MusicToggleButton({super.key});

  @override
  Widget build(BuildContext context) {
    final player = GlobalAudioPlayer();
    return ValueListenableBuilder<bool>(
      valueListenable: player.isPlayingListenable,
      builder: (context, isPlaying, _) {
        return SafeArea(
          child: Align(
            alignment: Alignment.bottomRight,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: player.toggle,
                  borderRadius: BorderRadius.circular(999),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: isPlaying
                          ? const Color(0xFFC6A76A)
                          : Colors.black.withValues(alpha: 0.72),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: isPlaying
                            ? const Color(0xFFC6A76A)
                            : Colors.white.withValues(alpha: 0.22),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.18),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isPlaying ? Icons.pause_rounded : Icons.music_note_rounded,
                          color: isPlaying ? Colors.black : Colors.white,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          isPlaying ? 'Pausar musica' : 'Activar musica',
                          style: GoogleFonts.inter(
                            color: isPlaying ? Colors.black : Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
