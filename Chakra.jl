module Chakra

using ListType, OptionType

export FN
export Att
export delimit, particles, setatt, getatt, empty, find, insert, domain
export sequence



struct FN{A,B}
    domain::Vector{DataType}
    codomain::DataType
    body::Function
    FN(dom::Vector{DataType},cod::DataType,f::Function) = begin
        if cod != Base._return_type(f,Tuple(dom))
            error("Type mismatch.")
        end
        new{Tuple{dom...},cod}(dom,cod,f)
    end
    FN(dom::Vector{DataType},cod::DataType) = begin
        
    end
end
function (f::FN{A,B})(xs...)::B where {A,B}
    typeof(xs) != A ? error("Wront argument type.") : f.body(xs...)
end




typ(::Val{a}) where a = error("The attribute name $a has not been associated with a type.")

typ(n::Symbol)::DataType = typ(Val{n}())

macro Attribute(n,T)    
    esc(:(Chakra.typ(::Val{$n}) = $T))
end

struct Att{a,T}
    a::Symbol
    T::DataType
    Att(a::Symbol) = begin
        T = typ(a)
        new{a,T}(a,T)
    end
end


function delimit(ps::List{Id}) where Id
    error("No implementation of delimit.")
end
function particles(o::Obj) where Obj
    error("No implementation of particles.")
end
function getatt(::Att{a,T},o::Obj) where {a,T,Obj}
    error("No implementation of getatt.")
end
function setatt(::Att{a,T},v::T,o::Obj) where {a,T,Obj}
    error("No implementation of setatt.")
end
function empty(T::DataType)
    error("No implementation of empty.")
end
function insert(x::Id,o::Obj,s::Str) where {Id,Obj,Str}
    error("No implementation of insert.")
end
function find(x::Id,s::Str) where {Id,Str}
    error("No implementation of find.")
end
function domain(s::Str) where Str
    error("No implementation of domain.")
end




# ADDITIONAL OPERATIONS

delimit(Id::DataType) = delimit(Id[])

getatt(a::Symbol,o) = getatt(Att(a),o)

setatt(a::Symbol,v,o) = setatt(Att(a),v,o)

sequence(xs::List,s)::Option{List} = begin
    list_rec(nil(),(h,t,r)->obind(find(h,s),o->obind(r,rec->cons(o,rec))),xs)
end



#end of module
end
