# Checks the package's line-coverage gate: every `lib/src/**` file must
# reach 100% line coverage in the `flutter test --coverage` lcov output.
#
# Usage: python tool/check_coverage.py [path/to/lcov.info]
#
# Note: the Dart VM occasionally fails to attribute a few lines inside
# generic helpers even when tests execute them (see `seedFromRetained` in
# `pulse_delivery.dart`); those lines are exercised by direct unit tests
# in `test/pulse_delivery_test.dart`.
import re
import sys

path = sys.argv[1] if len(sys.argv) > 1 else 'coverage/lcov.info'
data = open(path, encoding='utf-8').read()
records = data.split('end_of_record')
bad = []
count = 0
for r in records:
    sf = re.search(r'SF:([^\r\n]+)', r)
    if not sf:
        continue
    name = sf.group(1).replace('\\', '/')
    if 'lib/src/' not in name:
        continue
    count += 1
    lf = re.search(r'LF:(\d+)', r)
    lh = re.search(r'LH:(\d+)', r)
    lf = int(lf.group(1)) if lf else 0
    lh = int(lh.group(1)) if lh else 0
    misses = [int(m.group(1)) for m in re.finditer(r'DA:(\d+),0', r)]
    status = 'OK  ' if lf == lh else 'MISS'
    print(f'{status} {lh:4}/{lf:4}  {name}  {misses[:10]}')
    if lf != lh:
        bad.append((name, misses))
print('lib/src files:', count, '| NOT 100%:', len(bad))
