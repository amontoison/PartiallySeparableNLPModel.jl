function create_initial_point_Rosenbrock(n)
	point_initial = Vector{Float64}(undef, n)
	for i in 1:n
		if mod(i,2) == 1
			point_initial[i] = -1.2
		elseif mod(i,2) == 0
			point_initial[i] = 1.0
		else
			error("bizarre")
		end
	end
	return point_initial
end

function create_Rosenbrock_JuMP_Model(n :: Int)
	m = Model()
	@variable(m, x[1:n])
	@NLobjective(m, Min, sum( 100 * (x[j-1]^2 - x[j])^2 + (x[j-1] - 1)^2  for j in 2:n)) #rosenbrock function
	evaluator = JuMP.NLPEvaluator(m)
	MathOptInterface.initialize(evaluator, [:ExprGraph, :Hess])
	obj = MathOptInterface.objective_expr(evaluator)
	vec_var = JuMP.all_variables(m)
	vec_value = create_initial_point_Rosenbrock(n)
	JuMP.set_start_value.(vec_var, vec_value)
	return (m, evaluator,obj)
end

function create_Rosenbrock_JuMP_Model2(n :: Int)
	m = Model()
	@variable(m, x[1:n])
	@NLobjective(m, Min, sum( 100 * (x[j-1]^2 - x[j])^2 + (x[j-1] )^2  for j in 2:n)) #rosenbrock function
	evaluator = JuMP.NLPEvaluator(m)
	MathOptInterface.initialize(evaluator, [:ExprGraph, :Hess])
	obj = MathOptInterface.objective_expr(evaluator)
	vec_var = JuMP.all_variables(m)
	vec_value = create_initial_point_Rosenbrock(n)
	JuMP.set_start_value.(vec_var, vec_value)
	return (m, evaluator,obj)
end

n = 100
(m, evaluator,obj) = create_Rosenbrock_JuMP_Model(n)

x = ones(n)
x_Float32 = ones(Float32,n)

y = (x-> 2*x).(ones(n))
y_Float32 = (x-> 2*x).( ones(Float32,n))

rdm = rand(n)
rdm_Float32 = similar(y_Float32)
map!( x -> Float32(x), rdm_Float32, rdm)

expr_tree_obj = CalculusTreeTools.transform_to_expr_tree(obj)
comp_ext = CalculusTreeTools.create_complete_tree(expr_tree_obj)
comp_ext2 = CalculusTreeTools.transform_to_expr_tree(obj)

# détection de la structure partiellement séparable
SPS1 = PartiallySeparableNLPModels.deduct_partially_separable_structure(obj, n)
obj2 = CalculusTreeTools.transform_to_expr_tree(obj)
SPS2 = PartiallySeparableNLPModels.deduct_partially_separable_structure(obj2, n)
SPS3 = PartiallySeparableNLPModels.deduct_partially_separable_structure(comp_ext, n)
SPS_Float32 = PartiallySeparableNLPModels.deduct_partially_separable_structure(comp_ext2, n, Float32)

@testset "Function's evaluation" begin
    obj_SPS_x = PartiallySeparableNLPModels.evaluate_SPS( SPS1, x)
    obj_SPS2_x = PartiallySeparableNLPModels.evaluate_SPS( SPS2, x)
    obj_SPS3_x = PartiallySeparableNLPModels.evaluate_SPS( SPS3, x)
    obj_SPS4_x = PartiallySeparableNLPModels.evaluate_SPS( SPS_Float32, x_Float32)
    obj_MOI_x = MathOptInterface.eval_objective( evaluator, x)

		@test obj_SPS2_x ≈ obj_MOI_x
		@test obj_SPS3_x ≈ obj_MOI_x
		@test obj_SPS4_x ≈ obj_MOI_x
    @test typeof(obj_SPS4_x) == Float32

    obj_SPS_y = PartiallySeparableNLPModels.evaluate_SPS(SPS1, y)
    obj_SPS2_y = PartiallySeparableNLPModels.evaluate_SPS(SPS2, y)
    obj_SPS3_y = PartiallySeparableNLPModels.evaluate_SPS(SPS3, y)
    obj_SPS4_y = PartiallySeparableNLPModels.evaluate_SPS(SPS_Float32, y_Float32)
    obj_MOI_y = MathOptInterface.eval_objective(evaluator, y)

		@test obj_SPS_y ≈ obj_MOI_y 
		@test obj_SPS2_y ≈ obj_MOI_y 
		@test obj_SPS3_y ≈ obj_MOI_y
		@test obj_SPS4_y ≈ obj_MOI_y

    @test typeof(obj_SPS4_y) == Float32

    obj_SPS_rdm = PartiallySeparableNLPModels.evaluate_SPS(SPS1, rdm)
    obj_SPS2_rdm = PartiallySeparableNLPModels.evaluate_SPS(SPS2, rdm)
    obj_SPS3_rdm = PartiallySeparableNLPModels.evaluate_SPS(SPS3, rdm)
    obj_SPS4_rdm = PartiallySeparableNLPModels.evaluate_SPS(SPS_Float32, rdm_Float32)

    obj_MOI_rdm = MathOptInterface.eval_objective(evaluator, rdm)
    
		@test obj_SPS_rdm ≈ obj_MOI_rdm
		@test obj_SPS2_rdm ≈ obj_MOI_rdm
		@test obj_SPS3_rdm ≈ obj_MOI_rdm
		@test obj_SPS4_rdm ≈ obj_MOI_rdm

    @test typeof(obj_SPS4_rdm) == Float32
end

@testset "Different gradient evaluation" begin
	#fonction pour allouer un grad_vector facilement à partir d'une structure partiellement séparable
	f = (y :: PartiallySeparableNLPModels.element_function -> PartiallySeparableNLPModels.element_gradient{typeof(x[1])}(Vector{typeof(x[1])}(zeros(typeof(x[1]), length(y.used_variable)) )) )
	#fonction pour comparer les norms des gradient elements
	nrm_grad_elem = (g_elem :: PartiallySeparableNLPModels.element_gradient{} -> norm(g_elem.g_i) )

	# Définition des structure de résultats nécessaires
	MOI_gradient = Vector{ typeof(x[1]) }(undef,n)
	p_grad = PartiallySeparableNLPModels.grad_vector{typeof(x[1])}( f.(SPS1.structure) )
	p_grad2 = PartiallySeparableNLPModels.grad_vector{typeof(x[1])}( f.(SPS2.structure) )
	p_grad3 = PartiallySeparableNLPModels.grad_vector{typeof(x[1])}( f.(SPS3.structure) )
	p_grad_build = Vector{Float64}(zeros(Float64,n))
	p_grad_build2 = Vector{Float64}(zeros(Float64,n))
	p_grad_build3 = Vector{Float64}(zeros(Float64,n))

	MathOptInterface.eval_objective_gradient(evaluator, MOI_gradient, x)
	PartiallySeparableNLPModels.evaluate_SPS_gradient!(SPS1, x, p_grad)
	PartiallySeparableNLPModels.evaluate_SPS_gradient!(SPS2, x, p_grad2)
	PartiallySeparableNLPModels.evaluate_SPS_gradient!(SPS3, x, p_grad3)

	grad = PartiallySeparableNLPModels.build_gradient(SPS1, p_grad)
	grad2 = PartiallySeparableNLPModels.build_gradient(SPS2, p_grad2)
	grad3 = PartiallySeparableNLPModels.build_gradient(SPS3, p_grad3)
	PartiallySeparableNLPModels.build_gradient!(SPS1, p_grad, p_grad_build)
	PartiallySeparableNLPModels.build_gradient!(SPS2, p_grad2, p_grad_build2)
	PartiallySeparableNLPModels.build_gradient!(SPS3, p_grad3, p_grad_build3)

	grad_Float32 = PartiallySeparableNLPModels.evaluate_SPS_gradient(SPS_Float32, x_Float32)

	@test norm(MOI_gradient - grad) ≈ 0
	@test norm(MOI_gradient - grad2) ≈ 0
	@test norm(MOI_gradient - grad3) ≈ 0
	@test norm(MOI_gradient - p_grad_build) ≈ 0
	@test norm(MOI_gradient - p_grad_build2) ≈ 0
	@test norm(MOI_gradient - p_grad_build3) ≈ 0
	@test norm(MOI_gradient - grad_Float32) ≈ 0

	@test typeof(grad_Float32) == Vector{Float32}

	@test sum(nrm_grad_elem.(p_grad.arr)) ≈ sum(nrm_grad_elem.(p_grad2.arr)) 
	@test sum(nrm_grad_elem.(p_grad.arr)) ≈ sum(nrm_grad_elem.(p_grad3.arr)) 

	MathOptInterface.eval_objective_gradient(evaluator, MOI_gradient, y)
	PartiallySeparableNLPModels.evaluate_SPS_gradient!(SPS1, y, p_grad)
	PartiallySeparableNLPModels.evaluate_SPS_gradient!(SPS2, y, p_grad2)
	PartiallySeparableNLPModels.evaluate_SPS_gradient!(SPS3, y, p_grad3)
	grad_Float32_2 = PartiallySeparableNLPModels.evaluate_SPS_gradient(SPS_Float32, y_Float32)

	grad = PartiallySeparableNLPModels.build_gradient(SPS1, p_grad)
	grad2 = PartiallySeparableNLPModels.build_gradient(SPS2, p_grad2)
	grad3 = PartiallySeparableNLPModels.build_gradient(SPS3, p_grad3)
	grad4 = PartiallySeparableNLPModels.evaluate_SPS_gradient(SPS3, y)
	PartiallySeparableNLPModels.build_gradient!(SPS1, p_grad, p_grad_build)
	PartiallySeparableNLPModels.build_gradient!(SPS2, p_grad2, p_grad_build2)
	PartiallySeparableNLPModels.build_gradient!(SPS3, p_grad3, p_grad_build3)

	@test norm(MOI_gradient - grad) ≈ 0
	@test norm(MOI_gradient - grad2) ≈ 0
	@test norm(MOI_gradient - grad3) ≈ 0
	@test norm(MOI_gradient - grad4) ≈ 0
	@test norm(MOI_gradient - p_grad_build) ≈ 0
	@test norm(MOI_gradient - p_grad_build2) ≈ 0
	@test norm(MOI_gradient - p_grad_build3) ≈ 0
	@test norm(MOI_gradient - grad_Float32_2) ≈ 0
	
	@test typeof(grad_Float32_2) == Vector{Float32}

	@test sum(nrm_grad_elem.(p_grad.arr)) ≈ sum(nrm_grad_elem.(p_grad2.arr))
	@test sum(nrm_grad_elem.(p_grad.arr)) ≈ sum(nrm_grad_elem.(p_grad3.arr))
end

@testset "Hessian's evaluation" begin
	MOI_pattern = MathOptInterface.hessian_lagrangian_structure(evaluator)
	column = [x[1] for x in MOI_pattern]
	row = [x[2]  for x in MOI_pattern]

	f = ( elm_fun :: PartiallySeparableNLPModels.element_function -> PartiallySeparableNLPModels.element_hessian{Float64}( Array{Float64,2}(undef, length(elm_fun.used_variable), length(elm_fun.used_variable) )) )
	t = f.(SPS1.structure) :: Vector{PartiallySeparableNLPModels.element_hessian{Float64}}
	H = PartiallySeparableNLPModels.Hess_matrix{Float64}(t)
	H2 = PartiallySeparableNLPModels.Hess_matrix{Float64}(t)
	H3 = PartiallySeparableNLPModels.Hess_matrix{Float64}(t)

	MOI_value_Hessian = Vector{ typeof(x[1]) }(undef,length(MOI_pattern))
	MathOptInterface.eval_hessian_lagrangian(evaluator, MOI_value_Hessian, x, 1.0, zeros(0))
	values = [x for x in MOI_value_Hessian]

	MOI_half_hessian_en_x = sparse(row,column,values,n,n)
	MOI_hessian_en_x = Symmetric(MOI_half_hessian_en_x)

	PartiallySeparableNLPModels.struct_hessian!(SPS1, x, H)
	sp_H = PartiallySeparableNLPModels.construct_Sparse_Hessian(SPS1, H)
	PartiallySeparableNLPModels.struct_hessian!(SPS2, x, H2)
	sp_H2 = PartiallySeparableNLPModels.construct_Sparse_Hessian(SPS2, H2)
	PartiallySeparableNLPModels.struct_hessian!(SPS3, x, H3)
	sp_H3 = PartiallySeparableNLPModels.construct_Sparse_Hessian(SPS3, H3)

	@testset "Hessian matrix" begin
		@test norm(MOI_hessian_en_x - sp_H, 2) ≈ 0
		@test norm(MOI_hessian_en_x - sp_H2, 2) ≈ 0
		@test norm(MOI_hessian_en_x - sp_H3, 2) ≈ 0
	end

	# # on récupère le Hessian structuré du format SPS.
	# #Ensuite on calcul le produit entre le structure de donnée SPS_Structured_Hessian_en_x et y
	@testset "test du produit" begin
		x_H_y = PartiallySeparableNLPModels.product_matrix_sps(SPS1, H, y)
		x_H_y2 = PartiallySeparableNLPModels.product_matrix_sps(SPS2, H2, y)
		x_H_y3 = PartiallySeparableNLPModels.product_matrix_sps(SPS3, H3, y)

		v_tmp = Vector{ Float64 }(undef, length(MOI_pattern))
		x_MOI_Hessian_y = Vector{ typeof(y[1]) }(undef,n)
		MathOptInterface.eval_hessian_lagrangian_product(evaluator, x_MOI_Hessian_y, x, y, 1.0, zeros(0))

		@test norm(x_MOI_Hessian_y - x_H_y, 2) ≈ 0
		@test norm(x_MOI_Hessian_y - x_H_y2, 2) ≈ 0
		@test norm(x_MOI_Hessian_y - x_H_y3, 2) ≈ 0
		@test norm(x_H_y - MOI_hessian_en_x*y, 2) ≈ 0
		@test norm(x_H_y2 - MOI_hessian_en_x*y, 2) ≈ 0
		@test norm(x_H_y3 - MOI_hessian_en_x*y, 2) ≈ 0
	end

	@testset "test du produit2" begin
		x_H_y = PartiallySeparableNLPModels.Hv(SPS1, x, y)
		x_H_y2 = PartiallySeparableNLPModels.Hv(SPS2, x, y)
		x_H_y3 = PartiallySeparableNLPModels.Hv(SPS3, x, y)
		x_H_y4 = PartiallySeparableNLPModels.Hv(SPS_Float32, x_Float32, y_Float32)

		v_tmp = Vector{ Float64 }(undef, length(MOI_pattern))
		x_MOI_Hessian_y = Vector{ typeof(y[1]) }(undef,n)
		MathOptInterface.eval_hessian_lagrangian_product(evaluator, x_MOI_Hessian_y, x, y, 1.0, zeros(0))

		@test norm(x_MOI_Hessian_y - x_H_y, 2) ≈ 0 
		@test norm(x_MOI_Hessian_y - x_H_y2, 2) ≈ 0 
		@test norm(x_MOI_Hessian_y - x_H_y3, 2) ≈ 0 
		@test norm(x_H_y - MOI_hessian_en_x*y, 2) ≈ 0 
		@test norm(x_H_y2 - MOI_hessian_en_x*y, 2) ≈ 0 
		@test norm(x_H_y3 - MOI_hessian_en_x*y, 2) ≈ 0 
		@test norm(x_H_y4 - MOI_hessian_en_x*y, 2) ≈ 0 

		@test typeof(x_H_y4) == Vector{Float32}
	end
end

@testset "test du status de convexité des fonctions éléments" begin
	f = ( x -> CalculusTreeTools.get_convexity_wrapper( PartiallySeparableNLPModels.get_convexity_status(x)) )
	res_cvx1 = f.(PartiallySeparableNLPModels.get_structure(SPS1))
	res_cvx2 = f.(PartiallySeparableNLPModels.get_structure(SPS2))
	res_cvx3 = f.(PartiallySeparableNLPModels.get_structure(SPS3))
	res = []
	for i in 1:length(PartiallySeparableNLPModels.get_structure(SPS3))
		if i % 2 == 0
			push!(res,CalculusTreeTools.convex_type())
		else
			push!(res,CalculusTreeTools.unknown_type())
		end
	end
	@test res == res_cvx3
end
