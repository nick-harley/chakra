# Multiple Viewpoint Representation

## Chakra:

defines the abstract operations of chakra
- Id, Obj, Struc
- delim, get, set, parts
- empty, ins, fnd, dom

## ChakraImp:

an implementation of the chakra interface
- Id, Obj, Struc
- delim, get, set, parts
- empty, ins, fnd, dom

## Viewpoints:

defines the type of viewpoints and operations for composing them
- AtomicViewpoint, LinkedViewpoint, DerivedViewpoint, DelayedViewpoint
- vp_map (matching function)

## Models:

defines the types of models and distributions and operations for computing probabilities
- NGram, NGramModel, HGramModel, Predictor, Distribution
- Smoothing, Escape
- information_content, entropy, entropy_max

## Explorer:

basic demonstration of the functionality
