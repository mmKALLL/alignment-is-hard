import 'dart:collection';

// Called StackList to avoid conflict with Material's Stack component
class StackList<T> {
  StackList(List<T> elements) {
    _queue = Queue.from(elements);
  }
  late Queue<T> _queue;

  void push(T element) {
    _queue.addLast(element);
  }

  T? pop() {
    return this.isEmpty ? null : _queue.removeLast();
  }

  T? peek() {
    return this.isEmpty ? null : _queue.last;
  }

  void clear() {
    _queue.clear();
  }

  bool get isEmpty => _queue.isEmpty;
  bool get isNotEmpty => _queue.isNotEmpty;
  int get length => this._queue.length;
}
