/**
 * Common models (source: core/model/common/Id.kt, Ids.kt)
 */

/** ID model: response of APIs that only return an id */
export class Id {
  id: number = 0;
}

/** Batch ids request (e.g. batch delete) */
export class Ids {
  ids: number[] = [];
}
