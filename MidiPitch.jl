module MidiPitch

export MidiNoteNumber, MidiNoteInterval, diff, shift

using PitchADT

struct MidiNoteNumber <: Pitch
    val::Int64
end

struct MidiNoteInterval <: PitchInterval
    val::Int64
end
  
function diff(x::MidiNoteNumber,y::MidiNoteNumber)::MidiNoteInterval
    MidiNoteInterval(y.val-x.val)
end

function shift(i::MidiNoteInterval,p::MidiNoteNumber)::MidiNoteNumber
    MidiNoteNumber(p.val+i.val)
end

end

