module Predictions

export Prediction

using NGrams

struct Prediction{S,T}
    ngram::NGram{S,T}
    distribution::Distribution{T}
    estimate::Float64
    order::Int
    function Prediction(g::NGram{S,T},dist,p,o) where {S,T}
        return new{S,T}(g,dist,p,o)
    end
end

end
