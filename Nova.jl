module Nova

using MIDI, DataFrames
using ListType, OptionType, Chakra
using Viewpoints

export data

function loadmidi(filepaths)

    df = DataFrame(id=[],particles=[],pitch=[],onset=[],duration=[],velocity=[])
    
    for fp in filepaths

        file = readMIDIFile(fp)

        tracks = file.tracks
        trackids = []
        
        for (t,track) in enumerate(tracks)
            trackid = string(fp,"/track",t)
            push!(trackids,trackid)

            notes = getnotes(track,file.tpq)
            noteids =[]
            
            for (n,note) in enumerate(notes)

                noteid = string(trackid,"/note",n)
                push!(noteids,noteid)
                
                pitch = Int(note.pitch)
                onset = Int(note.position)
                duration = Int(note.duration)
                velocity = Int(note.velocity)
                push!(df,Dict(:id=>noteid,
                              :particles=>[],
                              :pitch=>pitch,
                              :onset=>onset,
                              :duration=>duration,
                              :velocity=>velocity))
            end

            push!(df,Dict(:id=>trackid,
                          :particles=>noteids,
                          :pitch=>missing,
                          :onset=>missing,
                          :duration=>missing,
                          :velocity=>missing))
            
        end

        fileid = fp
        push!(df,Dict(:id=>fileid,
                      :particles=>trackids,
                      :pitch=>missing,
                      :onset=>missing,
                      :duration=>missing,
                      :velocity=>missing))
        
    end
    return df
    
end

export Id, Obj, Str

Id = String
Obj = DataFrameRow{DataFrame,DataFrames.Index}
Str = DataFrame

Chakra.@Attribute :pitch Int
Chakra.@Attribute :onset Int
Chakra.@Attribute :duration Int
Chakra.@Attribute :velocity Int

function Chakra.find(x::Id,s::Str)::Option{Obj}
    o = s[s.id .== x,:]
    if isempty(o)
        return none
    end
    return o[1,:]
end

function Chakra.getatt(::Att{a,T},o::Obj)::Option{T} where {a,T}
    val = o[a]
    if val isa Missing
        return none
    end
    return val
end

function Chakra.domain(s::Str)::List{Id}
    s.id
end

function Chakra.particles(o::Obj)::List{Id}
    o[:particles]
end

pitchvp = vp(:pitch)
onsetvp = vp(:onset)
ioivp = compose(link(onsetvp,delay(onsetvp,1)),(x,y)->x-y)

filenames = readdir("nova")
paths = map(fn->string("nova/",fn),filenames)
data = loadmidi(paths)

end
