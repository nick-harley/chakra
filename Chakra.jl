module Chakra

export delimit, setAtt, getAtt, particles, emprty, insert, lookup, domain

using Typeside

abstract type Id end
abstract type Cobj end
abstract type Struc end

function delimit(ps::List{Id})::Cobj
    error("No implementation of delim")
end

function setAtt(o::Cobj,a::Symbol,v)::Cobj
    error("No implementation of setAtt")
end

function getAtt(o::Cobj,a::Symbol)::Option{Any}
    error("No implementation of getAtt")
end

function particles(o::Cobj)::List{Id}
    error("No implementation of getParts")
end

function empty()::Struc
    error("No implementation of emp")
end

function insert(x::Id,o::Cobj,s::Struc)::Struc
    error("No implementation of ins")
end

function lookup(x::Id,s::Struc)::Option{Cobj}
    error("No implementation of lup")
end

function domain(s::Struc)::List{Id}
    error("No implementation of dom")
end

end
