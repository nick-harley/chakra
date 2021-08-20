module ChakraSpec

export Id, Cobj, Struc, delimit, setAtt, getAtt, particles, empty, insert, lookup, domain

using Typeside

abstract type Id end
abstract type Cobj end
abstract type Struc end

function delimit(ps::List{Id})::Cobj end
function setAtt(o::Cobj,a,v)::Cobj end
function getAtt(o::Cobj,a)::Option{Any} end
function particles(o::Cobj)::List{Id} end
function empty()::Struc end
function insert(x::Id,o::Cobj,s::Struc)::Struc end
function lookup(x::Id,s::Struc)::Option{Cobj} end
function domain(s::Struc)::List{Id} end

end
