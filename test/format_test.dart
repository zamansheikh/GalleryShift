import 'package:flutter_test/flutter_test.dart';
import 'package:gallery_shift/util/format.dart';

void main() {
  test('formatBytes', () {
    expect(formatBytes(0), '0 MB');
    expect(formatBytes(512), '1 KB');
    expect(formatBytes(3 * 1024 * 1024 + 400 * 1024), '3.4 MB');
    expect(formatBytes(250 * 1024 * 1024), '250 MB');
    expect(formatBytes(1288490189), '1.2 GB');
  });

  test('formatCount adds thousands separators', () {
    expect(formatCount(7), '7');
    expect(formatCount(1204), '1,204');
    expect(formatCount(1234567), '1,234,567');
  });

  test('formatDuration', () {
    expect(formatDuration(const Duration(seconds: 32)), '0:32');
    expect(formatDuration(const Duration(minutes: 3, seconds: 5)), '3:05');
    expect(
      formatDuration(const Duration(hours: 1, minutes: 2, seconds: 3)),
      '1:02:03',
    );
  });

  test('plural', () {
    expect(plural(1, 'item'), '1 item');
    expect(plural(1500, 'item'), '1,500 items');
  });
}
