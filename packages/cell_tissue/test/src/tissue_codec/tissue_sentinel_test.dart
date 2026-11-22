// Sentinel identity, distinctness, and the `==`-collision contract.
import 'package:cell_tissue/cell_tissue.dart';
import 'package:test/test.dart';

void main() {
  group('tissue sentinels', () {
    test('each sentinel is a const singleton identical to itself', () {
      expect(identical(tissueNullTestRule, tissueNullTestRule), isTrue);
      expect(identical(tissueNullBind, tissueNullBind), isTrue);
      expect(identical(tissueNullContainer, tissueNullContainer), isTrue);
      expect(identical(tissueNullUser, tissueNullUser), isTrue);
      expect(identical(tissueNullElements, tissueNullElements), isTrue);
      expect(identical(tissueNullCapacity, tissueNullCapacity), isTrue);
      expect(identical(tissueNullValue, tissueNullValue), isTrue);
    });

    test('sentinels are pairwise distinct', () {
      final all = [
        tissueNullTestRule,
        tissueNullBind,
        tissueNullContainer,
        tissueNullUser,
        tissueNullElements,
        tissueNullCapacity,
        tissueNullValue,
      ];
      for (var i = 0; i < all.length; i++) {
        for (var j = 0; j < all.length; j++) {
          if (i != j) {
            expect(identical(all[i], all[j]), isFalse,
                reason: 'sentinel $i equals sentinel $j');
          }
        }
      }
    });

    test('a user value that is equal by == is not a sentinel', () {
      // Sentinel identity is by `identical`; an equal-by-value object must
      // not be mistaken for the sentinel in the override resolvers.
      expect(tissueNullUser == tissueNullUser, isTrue);
      expect(tissueNullUser == 'tissueNullUser', isFalse);
      expect(identical(tissueNullUser, Object()), isFalse);
    });
  });
}
