import 'dart:math';

class RgbColor {
  RgbColor(this.r, this.g, this.b, [this.a = 255]);

  final int r, g, b, a;
}

class XyzColor {
  XyzColor(this.x, this.y, this.z, [this.o = 1]);

  final double x, y, z, o;

  static int _f(double t) {
    if (t > 0.0031308) {
      return ((1.055 * pow(t, 1 / 2.4) - 0.055) * 255).round();
    } else {
      return (t * 12.92 * 255).round();
    }
  }

  RgbColor toRgb() {
    final double xp = x / 100;
    final double yp = y / 100;
    final double zp = z / 100;

    return RgbColor(
      _f(xp * 3.2406 + yp * -1.5372 + zp * -0.4986),
      _f(xp * -0.9689 + yp * 1.8758 + zp * 0.0415),
      _f(xp * 0.0557 + yp * -0.2040 + zp * 1.0570),
      (o * 255).round(),
    );
  }
}

class CielabColor {
  CielabColor(this.l, this.a, this.b, {this.o = 1});

  final double l, a, b, o;
  static final XyzColor _white = XyzColor(95.047, 100, 108.883);

  static double _f(double t) {
    final cube = pow(t, 3);
    if (cube > 0.008856) {
      return cube.toDouble();
    } else {
      return (t - 16 / 116) / 7.787;
    }
  }

  XyzColor toXyz() {
    return XyzColor(
      _f(a / 500 + (l + 16) / 116) * _white.x,
      _f((l + 16) / 116) * _white.y,
      _f((l + 16) / 116 - b / 200) * _white.z,
      o,
    );
  }
}
