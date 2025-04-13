// Copyright (c) 2025 Lee Man Hoi Simon. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// MIT license that can be found in the LICENSE file.

part of '../../collective.dart';

/// A specialized [Signal] that represents a notification event between cells in a reactive system.
///
/// The `Post` class carries a map of events (tagged by [N]) and their associated data payloads
/// as they propagate through the cell network. Each post maintains a reference to its origin cell.
///
/// This is the primary mechanism for propagating change notifications and events between
/// connected cells in the system.
///
/// Type parameters:
/// - [C]: The type of the originating cell (must extend [Cell])
/// - [N]: The type of event tags (must extend [Tag])
///
/// @param from: Source cell that posted
/// @param body: Content of the post
///
/// Example:
/// ```dart
/// // Example:
/// final event = Post<Cell, Symbol>(
///   from: sourceCell,
///   body: {#update: [1, 2, 3]}
/// );
/// ```
class Post<C extends Cell, N extends Tag> extends Signal<Map<N,Iterable>> {

  /// The cell that originated this post
  final C from;

  /// Creates a new post with the given source and event data.
  ///
  /// Parameters:
  /// - [from]: The originating cell of this notification
  /// - [body]: A map of events and their associated data payloads
  Post({required this.from, required Map<N,Iterable> body})
      : super(Map<N,Iterable>.unmodifiable(body));

}

/// A signal that carries collection change information
class CollectivePost extends Post<Cell, CollectiveEvent> {

  CollectivePost._({required super.from, required super.body}) : super();

  /// Creates an unmodifiable view of this post
  late final CollectivePost unmodifiable = _UnmodifiableCollectivePost._(this);
}

class _UnmodifiableCollectivePost extends CollectivePost {

  _UnmodifiableCollectivePost._(CollectivePost source)
      : super._(
      from: source.from,
      body: Map<CollectiveEvent,Iterable>.fromEntries(
            source.body!.entries.map<MapEntry<CollectiveEvent,Iterable>>((en) {
              return MapEntry<CollectiveEvent,Iterable>(en.key, en.value.map((v) {
                if (v is ValueChange) {
                  return v.unmodifiable;
                } else if (v is Cell) {
                  return v.unmodifiable;
                }
                return v;
              }));
            })
        )
      );
}

/// Specialized receptor for handling Collective signals
class CollectiveReceptor<E, IN extends Signal, OU extends Signal> extends ReceptorBase<Collective<E>, IN, OU> {

  /// Default unchanged receptor
  static const unchanged = CollectiveReceptor._();

  static final _receptors = <Type,CollectiveReceptor>{};

  /// Factory for creating a receptor
  factory CollectiveReceptor({SignalTransform<Collective<E>,IN,OU>? transform, dynamic user}) {
    if (IN == CollectivePost && OU == CollectivePost && transform == null && user == null) {
      final receptor = _receptors.containsKey(E)
          ? _receptors[E] : _receptors[E] = CollectiveReceptor<E,CollectivePost,CollectivePost>._();
      return receptor as CollectiveReceptor<E,IN,OU>;
    }
    return CollectiveReceptor._(transform: transform, user: user);
  }

  const CollectiveReceptor._({
    super.transform,
    super.user
  }) : super();

  /// Processes collection change signals
  @override
  OU? call({required covariant Collective<E> cell, required covariant IN signal, Set<Cell>? notified}) {

    if (identical((cell as CollectiveCell)._properties.receptor, this)) {

      if (cell is Deputy) {
        return super.call(cell: cell, signal: signal);
      }

      if (signal is CollectivePost && signal.from != cell) {
        final collective = cell as CollectiveCell;
        final container = collective._properties.container;
        final containerType = collective._properties.containerType;

        bool partial = false;
        final map = <CollectiveEvent, Set>{};

        void tryAdd(E e) {
          if (containerType.add<E>(collective, container, e)) {
            (map[Collective.elementAdded] ??= <E>{}).add(e);
            if (e is CollectiveCell) {
              e._properties.synapses.link(e, host: collective);
            }
          } else {
            partial = true;
          }
        }

        for (var en in signal.body!.entries) {

          switch(en.key) {
            case Collective.elementUpdated:
              for (var c in en.value) {
                if (c is ElementValueChange && c.element is E) {
                  if (container.contains(c.element)) {
                    (map[Collective.elementUpdated] ??= <ElementValueChange<E,dynamic>>{}).add(c);
                  } else {
                    tryAdd(c.element);
                  }
                }
              }
              break;

            case Collective.elementAdded:
              if (en.value.isNotEmpty) {
                en.value.whereType<E>().forEach(tryAdd);
              }
              break;

            case Collective.elementRemoved:
              if (en.value.isNotEmpty) {
                for (var e in en.value) {
                  if (containerType.remove<E>(collective, container, e)) {
                    (map[Collective.elementRemoved] ??= <E>{}).add(e);
                    if (e is CollectiveCell) {
                      e._properties.synapses.unlink(collective);
                    }
                  } else {
                    partial = true;
                  }
                }
              }
              break;
          }
        }

        Signal? post;
        if (map.isNotEmpty) {
          if (signal.body!.length == 1) {
            if (map.keys.single == Collective.elementUpdated) {
              post = partial
                  ? CollectivePost._(from: signal.from, body: {Collective.elementUpdated: map.values.first.cast()})
                  : signal;
            }
          } else if (partial) {
            post = CollectivePost._(from: signal.from, body: map);
          }
        }

        if (post != null && post is IN) {
          return super.call(cell: cell, signal: post, notified: notified);
        }

      } else {
        return super.call(cell: cell, signal: signal, notified: notified);
      }
    }

    return null;
  }

}
