import 'dart:math';

abstract class Weighted<T> {
  Weighted();
  late int weight;
  late T value;
}

T pickWeighted<T extends Weighted>(List<T> originalPool) {
  return pickListOfWeighted(1, originalPool)[0];
}

List<T> pickListOfWeighted<T extends Weighted>(int elementsToPick, List<T> originalPool) {
  List<T> pool = List.from(originalPool); // shallow copy

  // Generate a list of elements, where each element gets a random "weight index" from [0, sumOfWeights), which is used to pick the corresponding element
  return List.generate(min(elementsToPick, pool.length), (index) {
    int totalWeight = pool.fold(0, (acc, cur) => acc + cur.weight);
    if (totalWeight == 0) throw 'totalWeight became 0, pool=$pool';
    int weightIndex = Random().nextInt(totalWeight) + 1; // Random returns a value in range [0, max), but sum of weights is 1-indexed
    int i = 0;
    while (i < pool.length) {
      weightIndex -= pool[i].weight;
      if (weightIndex <= 0) {
        final weighted = pool[i];
        pool.removeAt(i); // side effect so we don't get same element twice
        return weighted;
      }
    }
    throw 'was not able to pick an effect, i=$i, totalWeight=$totalWeight, weightIndex=$weightIndex, pool=${pool.toString()}';
  });
}
