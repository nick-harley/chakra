module PitchADT

export Pitch, PitchInterval, diff, shift

using Chakra

abstract type Pitch end
abstract type PitchInterval end

function diff(p1::Pitch,p2::Pitch)::PitchInterval end
function shift(i::PitchInterval,p::Pitch)::Pitch end

Chakra.@associatedType(:pitch,Pitch)
Chakra.@associatedType(:pint,PitchInterval)

end
