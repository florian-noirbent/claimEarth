## Defines why an item use or throw was refused, as reported by RunItemController.use_refused.
class_name ItemUseRefusal
extends RefCounted


## The first moment of a run blocks uses so the Start press cannot fire an item.
const START_LOCK := &"start_lock"
## The thrown flag has not resolved yet.
const FLAG_IN_FLIGHT := &"flag_in_flight"
## The selected item has nothing left.
const EMPTY := &"empty"
## An in-place tool found nothing it could change.
const NO_EFFECT := &"no_effect"
