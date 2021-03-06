#__precompile__()
module KoalaLightGBM

export LGBMRegressor, LGBMBinaryClassifier

import Koala: SupervisedModel, BaseType, Transformer
import Koala: params
import KoalaTransforms: MakeCategoricalsIntTransformer, DataFrameToArrayTransformer
import KoalaTransforms: ToIntTransformer, ToIntScheme, RegressionTargetTransformer
import KoalaTransforms: IdentityTransformer
import DataFrames: AbstractDataFrame, eltypes
try
    import LightGBM
catch exception
    display(Base.md"Problem loading the module `LGBM` module. Perhaps
              Microsoft's LightGBM is not installed (install with
              `Pkg.clone(\"https://github.com/Allardvm/LightGBM.jl.git\")`
               or that the system environment `LIGHTGBM_PATH` has not been 
               set to its location. ")
    throw(exception)
end

# to be extended (but not explicitly rexported):
import Koala: setup, fit, predict
import Koala: default_transformer_X, default_transformer_y, transform, inverse_transform

# development only:
# import ADBUtilities: @dbg, @colon

## CUSTOM TRANSFORMER FOR INPUTS

# Note: We need any features designated as categorical to be
# represented as integers, and then the entire dataframe converted to
# a float array. By default (`categorical_features` empty) all
# non-real columns are considerered categorical.


mutable struct LGBMTransformer_X <: Transformer
    sorted::Bool
    categorical_features::Vector{Symbol}
    map_unseen_to_minus_one::Bool
end

LGBMTransformer_X(; sorted=false, categorical_features=Symbol[],
                  map_unseen_to_minus_one=false) =
    LGBMTransformer_X(sorted, categorical_features, map_unseen_to_minus_one)

struct LGBMScheme_X <: BaseType
    features::Vector{Symbol}
    categorical_features::Vector{Symbol}
    schemes::Vector{ToIntScheme}
    to_int_transformer::ToIntTransformer
end

function fit(transformer::LGBMTransformer_X, X::AbstractDataFrame, parallel, verbosity)

    to_int_transformer = ToIntTransformer(sorted=transformer.sorted,
                                          initial_label=0,
                                          map_unseen_to_minus_one=
                                          transformer.map_unseen_to_minus_one)
    categorical_features = copy(transformer.categorical_features)
    features = names(X)
    if isempty(categorical_features)
        types = eltypes(X)
        for j in eachindex(types)
            if !(types[j] <: AbstractFloat)
                push!(categorical_features, features[j])
            end
        end
    end

    schemes = ToIntScheme[]
    for feature in categorical_features 
        push!(schemes, fit(to_int_transformer, X[feature], parallel, verbosity))
    end

    return LGBMScheme_X(features, categorical_features, schemes, to_int_transformer)

end

function transform(transformer::LGBMTransformer_X, scheme_X, X::AbstractDataFrame)
    issubset(Set(scheme_X.features), Set(names(X))) ||
        error("DataFrame feature incompatibility encountered.")
    Xt = copy(X[scheme_X.features])
    
    for j in eachindex(scheme_X.categorical_features)
        ftr = scheme_X.categorical_features[j]
        Xt[ftr] = transform(scheme_X.to_int_transformer, scheme_X.schemes[j], Xt[ftr])
    end
    return convert(Array{Float64}, Xt)
end

"""
## `type LGBMRegressor`

See
!(https://github.com/Allardvm/LightGBM)[https://github.com/Allardvm/LightGBM]
for some details. For tuning see
![https://github.com/Microsoft/LightGBM/blob/master/docs/Parameters-Tuning.rst](https://github.com/Microsoft/LightGBM/blob/master/docs/Parameters-Tuning.rst)

"""
mutable struct LGBMRegressor <: SupervisedModel{LightGBM.LGBMRegression}

    num_iterations::Int                  # num_iterations in internal model
    learning_rate::Float64
    num_leaves::Int 
    max_depth::Int 
    tree_learner::String 
    num_threads::Int 
    histogram_pool_size::Float64
    min_data_in_leaf::Int              # aka min_patterns_split
    min_sum_hessian_in_leaf::Float64 
    lambda_l1::Float64
    lambda_l2::Float64
    feature_fraction::Float64 
    feature_fraction_seed::Int
    bagging_fraction::Float64
    bagging_freq::Int 
    bagging_seed::Int
    early_stopping_round::Int
    max_bin::Int 
    data_random_seed::Int 
    init_score::String 
    is_sparse::Bool 
    save_binary::Bool
    is_unbalance::Bool
    metric::String
    metric_freq::Int 
    is_training_metric::Bool 
    ndcg_at::Vector{Int} 
    num_machines::Int 
    local_listen_port::Int 
    time_out::Int 
    machine_list_file::String
    validation_fraction::Float64  # if zero then no validation errors
                                  # computed or reported

end

# lazy keyword constructor:
LGBMRegressor(;num_iterations=10, learning_rate=.1, num_leaves=127, max_depth=-1,
              tree_learner="serial", num_threads=Sys.CPU_CORES,
              histogram_pool_size=-1.,
              min_data_in_leaf=100, min_sum_hessian_in_leaf=10.,
              lambda_l1 = 0.0, lambda_l2 = 0.0,
              feature_fraction=1., feature_fraction_seed=0,
              bagging_fraction=1., bagging_freq=1, bagging_seed=0,
              early_stopping_round=4, max_bin=255,
              data_random_seed=0, init_score="", is_sparse=true,
              save_binary=false, is_unbalance=false, metric="l2",
              metric_freq=1, is_training_metric=false,
              ndcg_at=Int[], num_machines=1, local_listen_port=12400, time_out=120,
              machine_list_file="", 
              validation_fraction=0.0) = LGBMRegressor(num_iterations, learning_rate,
                                                       num_leaves, max_depth,
                                                       tree_learner, num_threads,
                                                       histogram_pool_size,
                                                       min_data_in_leaf,
                                                       min_sum_hessian_in_leaf,
                                                       lambda_l1,
                                                       lambda_l2,
                                                       feature_fraction,
                                                       feature_fraction_seed,
                                                       bagging_fraction, bagging_freq,
                                                       bagging_seed,
                                                       early_stopping_round,
                                                       max_bin, data_random_seed,
                                                       init_score, is_sparse,
                                                       save_binary, is_unbalance,
                                                       metric, metric_freq,
                                                       is_training_metric, ndcg_at,
                                                       num_machines, local_listen_port,
                                                       time_out, machine_list_file,
                                                       validation_fraction)

default_transformer_X(model::LGBMRegressor) =
    LGBMTransformer_X()
default_transformer_y(model::LGBMRegressor) =
    RegressionTargetTransformer()

"""
## `type LGBMBinaryClassifier`

See
!(https://github.com/Allardvm/LightGBM)[https://github.com/Allardvm/LightGBM]
for some details. For tuning see
![https://github.com/Microsoft/LightGBM/blob/master/docs/Parameters-Tuning.rst](https://github.com/Microsoft/LightGBM/blob/master/docs/Parameters-Tuning.rst)

"""
mutable struct LGBMBinaryClassifier <: SupervisedModel{LightGBM.LGBMBinary}

    num_iterations::Int                  # num_iterations in internal model
    learning_rate::Float64
    num_leaves::Int 
    max_depth::Int 
    tree_learner::String 
    num_threads::Int 
    histogram_pool_size::Float64
    min_data_in_leaf::Int              # aka min_patterns_split
    min_sum_hessian_in_leaf::Float64 
    lambda_l1::Float64
    lambda_l2::Float64
    feature_fraction::Float64 
    feature_fraction_seed::Int
    bagging_fraction::Float64
    bagging_freq::Int 
    bagging_seed::Int
    early_stopping_round::Int
    max_bin::Int 
    data_random_seed::Int 
    init_score::String 
    is_sparse::Bool 
    save_binary::Bool
    is_unbalance::Bool
    metric::String
    metric_freq::Int 
    is_training_metric::Bool 
    ndcg_at::Vector{Int} 
    num_machines::Int 
    local_listen_port::Int 
    time_out::Int 
    machine_list_file::String
    validation_fraction::Float64  # if zero then no validation errors
                                  # computed or reported

end

# lazy keyword constructor:
LGBMBinaryClassifier(;num_iterations=10, learning_rate=.1, num_leaves=127, max_depth=-1,
              tree_learner="serial", num_threads=Sys.CPU_CORES,
              histogram_pool_size=-1.,
              min_data_in_leaf=100, min_sum_hessian_in_leaf=10.,
              lambda_l1 = 0.0, lambda_l2 = 0.0,
              feature_fraction=1., feature_fraction_seed=0,
              bagging_fraction=1., bagging_freq=1, bagging_seed=0,
              early_stopping_round=4, max_bin=255,
              data_random_seed=0, init_score="", is_sparse=true,
              save_binary=false, is_unbalance=false, metric="l2",
              metric_freq=1, is_training_metric=false,
              ndcg_at=Int[], num_machines=1, local_listen_port=12400, time_out=120,
              machine_list_file="", 
              validation_fraction=0.0) = LGBMBinaryClassifier(num_iterations, learning_rate,
                                                       num_leaves, max_depth,
                                                       tree_learner, num_threads,
                                                       histogram_pool_size,
                                                       min_data_in_leaf,
                                                       min_sum_hessian_in_leaf,
                                                       lambda_l1,
                                                       lambda_l2,
                                                       feature_fraction,
                                                       feature_fraction_seed,
                                                       bagging_fraction, bagging_freq,
                                                       bagging_seed,
                                                       early_stopping_round,
                                                       max_bin, data_random_seed,
                                                       init_score, is_sparse,
                                                       save_binary, is_unbalance,
                                                       metric, metric_freq,
                                                       is_training_metric, ndcg_at,
                                                       num_machines, local_listen_port,
                                                       time_out, machine_list_file,
                                                       validation_fraction)

default_transformer_X(model::LGBMBinaryClassifier) =
    LGBMTransformer_X()
default_transformer_y(model::LGBMBinaryClassifier) =
    IdentityTransformer()


## SETUP AND FIT METHODS

LGBM = Union{LGBMRegressor, LGBMBinaryClassifier}

function setup(model::LGBM,
               X,
               y,
               scheme_X, parallel, verbosity)

    # since LightGBM does not accept subbarrays:
    XX = X[:,:]
    yy = y[:]
    
    features = scheme_X.features
    categorical_features = scheme_X.categorical_features
    categorical_feature_indices = map(categorical_features) do cat
        findfirst(features) do ftr ftr == cat end
    end
    
    return XX, yy, categorical_feature_indices
end

# the following function wraps parameters in the appropriate
# LightGBM.jl estimator (unfitted "predictor" in our parlance):
wrap(model::LGBMRegressor, parameters) = LightGBM.LGBMRegression(;parameters...)
wrap(model::LGBMBinaryClassifier, parameters) = LightGBM.LGBMBinary(;parameters...)

function fit(model::LGBM, cache::Tuple{Array,Vector{T},Vector}, add, parallel, verbosity) where T

    X, y, categorical_feature_indices = cache

    # Microsoft's LightGBM has option for reporting running validation
    # scores; so we split the data if `validation_fraction` is bigger
    # than zero:
    train_fraction = 1 - model.validation_fraction
    if model.validation_fraction != 0.0
        train, valid = split(eachindex(y), train_fraction)
        Xvalid = X[valid,:]
        yvalid = y[valid]
        X = X[train,:]
        y = y[train]
    end

    parameters = params(model)
    delete!(parameters, :validation_fraction) # not sent to inner fit
    parameters[:metric] = [parameters[:metric],]
    if model.feature_fraction_seed == 0
        parameters[:feature_fraction_seed] = round(Int, time())
    end
    if model.bagging_seed == 0
        parameters[:bagging_seed] = round(Int, time())
    end
    if model.data_random_seed == 0
        parameters[:data_random_seed] = round(Int, time())
    end
    if !parallel
        parameters[:num_threads] = 1
    end

    parameters[:categorical_feature] = categorical_feature_indices

    predictor = wrap(model, parameters)

    valid_pairs = Tuple{Matrix{Float64},Vector{T}}[]
    if model.validation_fraction != 0.0
        push!(valid_pairs, (Xvalid, yvalid))
    end
    output = values(LightGBM.fit(predictor, X, y, valid_pairs...;
                                 verbosity=verbosity)) |> collect

    report = Dict{Symbol,Array{Float64,1}}()

    if !isempty(output)
        report[:rms_raw_validation_errors] = output[1][model.metric]
    end
       
    return predictor, report, (X, y, categorical_feature_indices)
end

function predict(model::LGBM, predictor, X, parallel, verbosity)
    return LightGBM.predict(predictor, X, verbosity=0)
end

end # module

