module MidiPitch

export NoteNumber, NoteInterval, convert

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

convert(::Type{NoteNumber},n::Int64) = NoteNumber(n)
convert(::Type{Int64},n::NoteNumber) = n.val

end

