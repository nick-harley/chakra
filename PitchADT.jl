module PitchADT

export Pitch, PitchInterval, diff, shift, typ

using Typeside, GIS

abstract type Pitch <: GIS.Point end
abstract type PitchInterval <: GIS.Interval end

function diff(p1::Pitch,p2::Pitch)::PitchInterval end
function shift(i::PitchInterval,p::Pitch)::Pitch end

Typeside.@associatedType :pitch Pitch
Typeside.@associatedType :pint PitchInterval

end
