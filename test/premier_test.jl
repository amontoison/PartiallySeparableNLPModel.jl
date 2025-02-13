m = Model()
n = 100
@variable(m, x[1:n])
@NLobjective(m, Min, sum( x[j] * x[j+1] + (x[j+1]+5*x[j])^2 for j in 1:n-1 ) + (sin(x[1]))^2 + x[n-1]^3 )
evaluator = JuMP.NLPEvaluator(m)
MathOptInterface.initialize(evaluator, [:ExprGraph])
Expr_ = MathOptInterface.objective_expr(evaluator)
expr_tree = CalculusTreeTools.transform_to_expr_tree(Expr_)
complete_expr_tree = CalculusTreeTools.create_complete_tree(expr_tree)
x = ones(n)
x = Vector{Float64}([1.0:n;])

sps1 = PartiallySeparableNLPModels.deduct_partially_separable_structure(Expr_, n)
sps2 = PartiallySeparableNLPModels.deduct_partially_separable_structure(expr_tree, n)
sps3 = PartiallySeparableNLPModels.deduct_partially_separable_structure(complete_expr_tree, n)

θ = 1e-6
obj1 = PartiallySeparableNLPModels.evaluate_SPS(sps1, x)
obj2 = PartiallySeparableNLPModels.evaluate_SPS(sps2, x)
obj3 = PartiallySeparableNLPModels.evaluate_SPS(sps3, x)
obj4 = PartiallySeparableNLPModels.evaluate_obj_pre_compiled(sps1, x)

grad1 =  PartiallySeparableNLPModels.evaluate_gradient(sps1, x)
grad2 =  PartiallySeparableNLPModels.evaluate_gradient(sps2, x)
grad3 = PartiallySeparableNLPModels.evaluate_gradient(sps3, x)
moi_grad = similar(x)
MathOptInterface.eval_objective_gradient(evaluator, moi_grad, x)

@testset "tests évaluation" begin
	@test PartiallySeparableNLPModels.evaluate_SPS(sps1, x) == PartiallySeparableNLPModels.evaluate_SPS(sps2, x)
	@test PartiallySeparableNLPModels.evaluate_SPS(sps2, x) == PartiallySeparableNLPModels.evaluate_SPS(sps3, x)
	@test PartiallySeparableNLPModels.evaluate_SPS(sps2, x) ≈ MathOptInterface.eval_objective(evaluator, x)
end

@testset "tests gradient" begin
	MOI_gradient = Vector{ eltype(x) }(undef,n)
	MathOptInterface.eval_objective_gradient(evaluator, MOI_gradient, x)

	@test PartiallySeparableNLPModels.evaluate_gradient(sps1, x) == PartiallySeparableNLPModels.evaluate_gradient(sps2, x)
	@test PartiallySeparableNLPModels.evaluate_gradient(sps2, x) == PartiallySeparableNLPModels.evaluate_gradient(sps3, x)
	@test PartiallySeparableNLPModels.evaluate_gradient(sps2, x) ≈ MOI_gradient
end