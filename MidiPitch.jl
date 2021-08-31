module MidiPitch

export NoteNumber, NoteInterval

using PitchADT
import PitchADT: diff, shift

struct NoteNumber <: Pitch
    val::Int64
end

struct NoteInterval <: PitchInterval
    val::Int64
end
  
diff(x::NoteNumber,y::NoteNumber)::NoteInterval = NoteInterval(y.val-x.val)
shift(i::NoteInterval,p::NoteNumber)::NoteNumber = NoteNumber(p.val+i.val)

end

