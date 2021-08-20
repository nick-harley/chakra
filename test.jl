module Types

struct Unit end

unit = Unit()

const Option{T} = UnionOf{T,Unit}

const List{T} = Vector{T}

end


module Id

export Id

abstract type Id

end


module Att

export Att, typ

abstract type Att

function typ(a::Att)::DataType end

end 


module CObj

export CObj

using Types, Id, Att

abstract type CObj

function delimit(ps::List{Id})::CObj end
function getAtt(o::CObj,a::Att)::Option{typ(a)} end
function setAtt(o::CObj,a::Att,v)::CObj end
function getParticles(o::CObj)::List{Id} end

end


module Struc

export Struc, empty, insert, lookup, domain

using Types, Id, Att, CObj

abstract type Struc

function empty()::Struc end
function insert(s::Struc,x::Id,o::Cobj)::Struc end
function lookup(s::Struc,x::Id)::Struc end
function domain(s::Struc)::List{Id} end

end 
