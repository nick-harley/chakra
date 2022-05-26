module Views

using OptionType
using Viewpoints

export View

struct View{S,T}

    # A view of a sequence
    
    target::Vector{Option{T}}
    source::Vector{Option{S}}
    targetind::Vector{Int}
    sourceind::Vector{Int}
    targetelements::Vector{T}
    sourceelements::Vector{S}

    function View(elems::Vector{Tuple{Option{S},
                                      Option{T}}}) where {S,T}

        # construct a view from a vector of tuples
        
        # vector of target attribtue
        t = last.(elems)
        s = first.(elems)
        tind = [i for (i,e) in enumerate(t) if e != none]
        sind = [i for (i,e) in enumerate(s) if e != none]
        telems = t[tind]
        selems = s[sind]

        return new{S,T}(t,s,tind,sind,telems,selems)
    end

    function View(seq::Vector,
                  src::Viewpoints.Viewpoint{S},
                  trg::Viewpoints.Viewpoint{T}) where {S,T}

        # construct a view from a sequence and two viewpoints
        
        return View(Tuple{Option{S},Option{T}}[zip(vp_map(src,seq),vp_map(trg,seq))...])
    end
end

# length of a view
Base.length(v::View) = length(v.targetind)


# end of module
end
