module MidiPitch

export NoteNumber, NoteInterval, diff, shift

using PitchADT

struct NoteNumber <: Pitch
    val::Int64
end

struct NoteInterval <: PitchInterval
    val::Int64
end
  
function diff(x::NoteNumber,y::NoteNumber)::NoteInterval
    NoteInterval(y.val-x.val)
end

function shift(i::NoteInterval,p::NoteNumber)::NoteNumber
    NoteNumber(p.val+i.val)
end

end

