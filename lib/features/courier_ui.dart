import 'package:flutter/material.dart';

const ink = Color(0xff164d40),
    panel = Color(0xffe0f3cc),
    mint = Color(0xff28795c),
    muted = Color(0xff486e59),
    gold = Color(0xffffda55);

ThemeData courierTheme() => ThemeData(
  brightness: Brightness.light,
  scaffoldBackgroundColor: const Color(0xff25594f),
  fontFamily: 'Fredoka',
  colorScheme: ColorScheme.fromSeed(
    seedColor: mint,
    primary: ink,
    secondary: gold,
    surface: panel,
  ),
  textTheme: ThemeData.light().textTheme.apply(
    fontFamily: 'Fredoka',
    bodyColor: ink,
    displayColor: ink,
  ),
  filledButtonTheme: FilledButtonThemeData(
    style: FilledButton.styleFrom(
      backgroundColor: gold,
      foregroundColor: ink,
      disabledBackgroundColor: const Color(0xffb9ccb0),
      disabledForegroundColor: const Color(0xff52674e),
      minimumSize: const Size(48, 56),
      elevation: 3,
      shadowColor: ink,
      side: const BorderSide(color: ink, width: 2),
      textStyle: const TextStyle(
        fontFamily: 'Fredoka',
        fontSize: 17,
        fontWeight: FontWeight.w700,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(17)),
    ),
  ),
  outlinedButtonTheme: OutlinedButtonThemeData(
    style: OutlinedButton.styleFrom(
      minimumSize: const Size(48, 48),
      side: const BorderSide(color: ink, width: 2),
    ),
  ),
  textButtonTheme: TextButtonThemeData(
    style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
  ),
  iconButtonTheme: IconButtonThemeData(
    style: IconButton.styleFrom(
      minimumSize: const Size(48, 48),
      foregroundColor: ink,
    ),
  ),
  progressIndicatorTheme: const ProgressIndicatorThemeData(
    color: mint,
    linearTrackColor: Color(0xffa6c7a4),
  ),
  dividerColor: const Color(0xffa6c7a4),
  useMaterial3: true,
);

class CourierPanel extends StatelessWidget {
  const CourierPanel({
    super.key,
    required this.child,
    this.color = panel,
    this.padding = const EdgeInsets.all(16),
  });
  final Widget child;
  final Color color;
  final EdgeInsetsGeometry padding;
  @override
  Widget build(BuildContext context) => Container(
    padding: padding,
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: ink.withValues(alpha: .7), width: 1.5),
      boxShadow: const [
        BoxShadow(color: Color(0xff34755b), offset: Offset(0, 4)),
      ],
    ),
    child: Material(type: MaterialType.transparency, child: child),
  );
}

class CourierIconButton extends StatelessWidget {
  const CourierIconButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
  });
  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  @override
  Widget build(BuildContext context) => IconButton.filled(
    tooltip: label,
    onPressed: onPressed,
    style: IconButton.styleFrom(
      backgroundColor: panel,
      foregroundColor: ink,
      minimumSize: const Size(48, 48),
      side: const BorderSide(color: ink, width: 1.5),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
    ),
    icon: Icon(icon),
  );
}

class CoinCounter extends StatelessWidget {
  const CoinCounter(this.value, {super.key});
  final int value;
  @override
  Widget build(BuildContext context) => Semantics(
    label: '$value coins',
    child: CourierPanel(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.monetization_on_rounded,
            color: Color(0xffad720d),
            size: 24,
          ),
          const SizedBox(width: 6),
          Text(
            '$value',
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 17),
          ),
        ],
      ),
    ),
  );
}

/// Pure vector scenery; no remote images, blur filters or extra scene tickers.
class LobbyBackdrop extends StatelessWidget {
  const LobbyBackdrop({super.key});
  @override
  Widget build(BuildContext context) => const ExcludeSemantics(
    child: CustomPaint(painter: _LobbyPainter(), size: Size.infinite),
  );
}

class _LobbyPainter extends CustomPainter {
  const _LobbyPainter();
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xffa6e7bf), Color(0xff64bc99), Color(0xff216952)],
        ).createShader(rect),
    );
    final light = Path()
      ..moveTo(size.width * .1, 0)
      ..lineTo(size.width * .55, 0)
      ..lineTo(size.width, size.height * .8)
      ..close();
    canvas.drawPath(
      light,
      Paint()..color = Colors.white.withValues(alpha: .10),
    );
    for (var i = 0; i < 11; i++) {
      final x = (i * .113 - .08) * size.width;
      final top = size.height * (.40 + (i % 4) * .035);
      final width = size.width * .105;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, top, width, size.height * .46),
          const Radius.circular(9),
        ),
        Paint()..color = const Color(0xff3b957c).withValues(alpha: .28),
      );
      for (var j = 0; j < 4; j++) {
        canvas.drawRect(
          Rect.fromLTWH(x + width * .2, top + 15 + j * 20, width * .55, 3),
          Paint()..color = const Color(0xffccf2c3).withValues(alpha: .4),
        );
      }
    }
    for (var i = 0; i < 19; i++) {
      final p = Offset(
        ((i * 73 + 21) % 317) / 317 * size.width,
        ((i * 127 + 37) % 797) / 797 * size.height,
      );
      canvas.drawCircle(
        p,
        i.isEven ? 2 : 1,
        Paint()..color = Colors.white.withValues(alpha: .35),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _LobbyPainter oldDelegate) => false;
}
