@testset "symbolic" begin

# @testset "Dolang.eq_expr" begin
#     ex1 = :(z[0] = x + y(1))
#     ex2 = :(z[0] == x + y(1))

#     for ex in (ex1, ex2)
#         @test Dolang.stringify(ex) == :(_x_ + _y__1_ - _z__0_)
#         @test Dolang.stringify(ex, targets=[:_z__0_]) == :(_z__0_ = _x_ + _y__1_)
#         @test Dolang.stringify(ex, targets=[(:z, 0)]) == :(_z__0_ = _x_ + _y__1_)
#     end

# end

@testset "Dolang.stringify" begin
    @testset "Dolang.stringify(::Union{Symbol,String}, Integer)" begin
        @test Dolang.stringify(:x, 0) == :x__0_
        @test Dolang.stringify(:x, 1) == :x__1_
        @test Dolang.stringify(:x, -1) == :x_m1_
        @test Dolang.stringify(:x, -100) == :x_m100_

        # @test Dolang.stringify("x", 0) == :x__0_
        # @test Dolang.stringify("x", 1) == :x__1_
        # @test Dolang.stringify("x", -1) == :x_m1_
        # @test Dolang.stringify("x", -100) == :x_m100_

        @test Dolang.stringify((:x, 0)) == :x__0_
        @test Dolang.stringify((:x, 1)) == :x__1_
        @test Dolang.stringify((:x, -1)) == :x_m1_
        @test Dolang.stringify((:x, -100)) == :x_m100_
    end

    @testset "numbers" begin
        for T in (Float16, Float32, Float64, Int8, Int16, Int32, Int64)
            x = rand(T)
            @test Dolang.stringify(x) == x
        end
    end

    @testset "symbols" begin
        for i=1:10
            s = gensym()
            want = Symbol(s, "_")
            @test Dolang.stringify(s) == want
        end
    end

    @testset "x_(shift_Integer)" begin
        # for i=1:10, T in (Int8, Int16, Int32, Int64)
        for i=1:10, T in (Int64,)
            @test Dolang.stringify(string("x[t+", T(i), "]")) == Symbol("x__$(i)_")
            @test Dolang.stringify(string("x[t", T(-i), "]")) == Symbol("x_m$(i)_")
        end
    end

    @testset "other function calls" begin
        @testset "one argument" begin
            @test Dolang.stringify("sin(x)") == :(sin(x_))
            @test Dolang.stringify("sin(x[t-1])") == :(sin(x_m1_))
            @test Dolang.stringify("foobar(x[t+2])") == :(foobar(x__2_))
        end

        @testset "two arguments" begin
            @test Dolang.stringify("dot(x, y[t+1])") == :(dot(x_, y__1_))
            @test Dolang.stringify("plot(x[t-1], y)") == :(plot(x_m1_, y_))
            @test Dolang.stringify("bingbong(x[t+2], y)") == :(bingbong(x__2_, y_))
        end

        @testset "more args" begin
            for i=3:10
                ex = Expr(:call, :my_func, [:(x[t+$j]) for j in 1:i]...)
                want = Expr(:call, :my_func, [Symbol("x__", j, "_") for j in 1:i]...)
                @test Dolang.stringify(ex) == want
            end
        end

        @testset "arithmetic" begin
            @test Dolang.stringify(:(a[t+1] + b + c[t+2] + d[t-1])) == :(a__1_ + b_ + c__2_ + d_m1_)
            @test Dolang.stringify(:(a[t+1] * b * c[t+2] * d[t-1])) == :(a__1_ * b_ * c__2_ * d_m1_)
            @test Dolang.stringify(:(a[t+1] - b - c[t+2] - d[t-1])) == :(((a__1_ - b_) - c__2_) - d_m1_)
            @test Dolang.stringify(:(a[t+ 1]^ b)) == :(a__1_ ^ b_)
        end

    end

    # @testset "Expr(:(=), ...)" begin
    #     @testset "without targets" begin
    #         @test Dolang.stringify(:(x = y)) == :(_y_ - _x_)
    #     end

    #     @testset "with targets" begin
    #         @test Dolang.stringify(:(x = log(y(-1))); targets=[:x]) == :(_x_ = log(_y_m1_))
    #         @test Dolang.stringify(:(x == log(y(-1))); targets=[:x]) == :(_x_ = log(_y_m1_))
    #         @test_throws Dolang.stringifyError Dolang.stringify(:(x = y); targets=[:y])
    #     end
    # end

    @testset "stringify(::Tuple{Symbol,Int})" begin
        @test Dolang.stringify((:x, 0)) == :x__0_
        @test Dolang.stringify((:x, 1)) == :x__1_
        @test Dolang.stringify((:x, -1)) == :x_m1_
        @test Dolang.stringify((:x, -100)) == :x_m100_
    end
    
end

@testset "Dolang.time_shift" begin
    defs = Dict(:a=>:(b[t-1]/c))
    defs_sanitized = Dict(:a=>:(b[t-1]/c[t]))
    funcs = [:foobar]
    for shift in [-1, 0, 1]
        have = Dolang.time_shift(:(a+b[t+1] + c), shift)
        @test have == :(a + $(Dolang.create_variable(:b,shift+1)) + c)

        have = Dolang.time_shift(:(a+b[t+1] + c[t]), shift)
        @test have == :(a + $(Dolang.create_variable(:b,shift+1)) + $(Dolang.create_variable(:c,shift)) )
    end
end

@testset "Dolang.steady_state" begin
    @test Dolang.steady_state(:(a+b[t+1] + c)) == :(a+b[t]+c)
end

@testset "Dolang.list_symbols" begin
    ex = :(a+b[t+1]+c)
    out = Dolang.list_symbols(ex)
    @test out.variables == [(:b, 1)]
    @test out.parameters == [:a, :c]
    @test out.variables == @inferred Dolang.list_variables(ex)
    @test out.parameters == @inferred Dolang.list_parameters(ex)

    ex = :(a+b[t+1]+c[t+0])
    out = Dolang.list_symbols(ex)
    @test out.variables == [(:b, 1), (:c, 0)]
    @test out.parameters == [:a]
    @test out.variables == @inferred Dolang.list_variables(ex)
    @test out.parameters == @inferred Dolang.list_parameters(ex)


end

@testset "arg_name, arg_time, arg_name_time, arg_names" begin
    for i in 1:5
        s = gensym()
        s_vec = [gensym() for xxxxxx in 1:3]
        s_dict = OrderedDict(:m => s_vec, :M => [s])
        @test Dolang.arg_name(s) == s
        @test Dolang.arg_time(s) == 0
        @test Dolang.arg_name_time(s) == (s, 0)
        @test Dolang.arg_names(s_vec) == s_vec
        @test Dolang.arg_names(s_dict) == vcat(s_vec, s)
        for t in 1:10
            @test Dolang.arg_name((s, t)) == s
            @test Dolang.arg_time((s, t)) == t
            @test Dolang.arg_name_time((s, t)) == (s, t)
            @test Dolang.arg_name(Expr(:call, s, t)) == s
            @test Dolang.arg_time(Expr(:call, s, t)) == t
            @test Dolang.arg_name_time(Expr(:call, s, t)) == (s, t)
        end
    end

    for f in (Dolang.arg_name, Dolang.arg_time, Dolang.arg_name_time, Dolang.arg_names)
        @test_throws MethodError f(1)        # Number
        @test_throws MethodError f([1])      # Array of number
    end

    @test Dolang.arg_name_time(:_x__1_) == (:x, 1)
    @test Dolang.arg_name_time(:_x_m100_) == (:x, -100)
    @test Dolang.arg_name_time(:_this_is_x_m100_) == (:this_is_x, -100)
end

end  # @testset "symbolic"
