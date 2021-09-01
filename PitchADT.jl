module PitchADT

export Pitch, PitchInterval, diff, shift

using Typeside

abstract type Pitch end
abstract type PitchInterval end

function diff(p1::Pitch,p2::Pitch)::PitchInterval end
function shift(i::PitchInterval,p::Pitch)::Pitch end

Typeside.@associatedType(:pitch,Pitch)
Typeside.@associatedType(:pint,PitchInterval)

end
