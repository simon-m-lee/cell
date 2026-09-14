// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

part of '../../model.dart';





















































abstract class Reference {

  
  
  
  
  
  
  
  
  
  
  ModelReference<M> model<M extends Model>([dynamic source]);

  
  
  
  
  
  Iterable<Type> get modelTypes;

  
  
  
  
  
  
  T fromMap<T extends Relatable>(Map<String, dynamic> map, {int cascade = 0, Set<Model>? lookup});

  
  
  T fromJson<T extends Relatable>(String json, {int cascade = 0, Set<Model>? lookup});

  
  
  
  
  
  
  TypeValue typeValue(String typeString);
}
















abstract class RelatableReference {

  
  
  
  final Relatable? _source;

  
  const RelatableReference([this._source]);

  
  
  
  Relatable? get source => _source!;
}

















abstract class ModelReference<M extends Model> {

  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  const ModelReference();

  
  M fromMap(Map<String, dynamic> map, {int cascade = 0, Set<Model>? lookup});

  
  M fromJson(String json, {int cascade = 0, Set<Model>? lookup});

  
  
  TestOne<M> get testRule;

  
  
  Iterable<FieldReference<M, dynamic>> get fieldReferences;
}