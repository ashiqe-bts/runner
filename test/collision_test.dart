import 'package:flutter_test/flutter_test.dart';
import 'package:skyway_courier/game/collision.dart';

void main() {
  bool hit(List<double> a, List<double> b, {double radius = .2}) =>
      sweptSphereBox(
        from: a,
        to: b,
        min: [-1, -1, -1],
        max: [1, 1, 1],
        radius: radius,
      );
  test('continuous sweep catches traversal even when endpoints miss', () {
    expect(hit([0, 0, -5], [0, 0, 5]), true);
    expect(hit([-5, 0, 0], [5, 0, 0]), true);
  });
  test('rounded corners do not collide like an expanded AABB', () {
    expect(hit([1.19, 1.19, 0], [1.19, 1.19, 0]), false);
    expect(hit([1.1, 1.1, 0], [1.1, 1.1, 0]), true);
  });
  test('parallel and stationary paths are finite and accurate', () {
    expect(hit([2, 0, -5], [2, 0, 5]), false);
    expect(hit([0, 0, 0], [0, 0, 0]), true);
    expect(hit([5, 5, 5], [5, 5, 5]), false);
  });
  test('negative-side and positive-side sweeps are symmetric', () {
    expect(hit([-1.15, -3, 0], [-1.15, 3, 0]), true);
    expect(hit([1.15, -3, 0], [1.15, 3, 0]), true);
  });
}
