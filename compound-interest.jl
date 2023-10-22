### A Pluto.jl notebook ###
# v0.19.29

using Markdown
using InteractiveUtils

# ╔═╡ 6b392bb8-2d02-4708-b8be-6f21431384b6
using Optim, JuMP, HiGHS

# ╔═╡ 572c2ccc-6883-11ee-1e39-edcceae11cfe
md"# _Calculating Compound interest for Madie's student loans_

Hopefully this will be helpful to find the optimal way to pay back her loans
"

# ╔═╡ 69c80c94-de9c-4ada-a333-1a30fe495f5a
md" ## Step 0: Setting up the functions for compound interest"

# ╔═╡ 183bc85c-9fba-48be-bcec-6fd5825feec4
# Create a loan struct that stores the principal, interest rate, and compounds per timestep
struct Loan
	principal :: Float64
	accrual :: Float64
	interest :: Float64
	compounds :: Int
end


# ╔═╡ a22e8fc2-53d2-4f39-95f5-9329e57991c5
# Define an owed method for a loan
owed(loan::Loan) = loan.principal + loan.accrual

# ╔═╡ 0310879c-4de5-4d26-9090-7087476a5a1e
# Funciton that takes struct and calculates the amount owed each time step
# Time steps here are months, but interest rate is an annual number

function accrue!(loan::Loan)

	# Calculate how much accrued in the time step
	accrued = owed(loan) * (loan.interest / loan.compounds)	
	accrual = round(loan.accrual + accrued, digits = 2)


	# Create new loan struct with updated
	new_loan = Loan(
		loan.principal,
		accrual,
		loan.interest,
		loan.compounds
	)
	return new_loan

end


# ╔═╡ 99194fad-be56-41d8-be5e-1b3a111d16a7
# Function that subtracts the payment at the end of every time step

# TODO Figure out if payment should happen before accural or after

function pay!(loan::Loan, payment)
	
	# First apply the payment to the accrual then to the principal if any left over
	if payment <= loan.accrual
		accrual = loan.accrual - payment
		principal = loan.principal
	else
		difference = payment - loan.accrual
		accrual = 0
		principal = loan.principal - difference
	end

	# Don't let the loan principal go negative
	if principal < 0
		principal = 0
	end

	# Create a new loan struct to return
	payed_loan = Loan(
		principal,
		accrual,
		loan.interest,
		loan.compounds	
	)
	return payed_loan
end



# ╔═╡ 818070e1-1594-489c-bf21-fbe0d98e4319
# Function that steps time one month in advance

function step_time!(loan::Loan, payment)
	# Pay then accrue
	payed_loan = pay!(loan, payment)
	accrued_loan = accrue!(payed_loan)
	
	return accrued_loan
end


# ╔═╡ 5c1cd126-7bb8-47d0-91be-6cc28bae61c7
# Function to aggregate the amount owed for each time step of a loan period
function aggregate_owed(loan::Loan...)
	# Compute the owed amount on each loan and add them together
	total_owed = round(sum(owed.(loan)), digits = 2)
	return total_owed
end


# ╔═╡ 2d99efe9-e754-487d-8d74-82cba486a60a
# Create a function that simulates one payment of every loan and returns the total amount owed
# This will take input as an array of loans, and an array of payment amounts

function simulate!(loans::Loan...; payments::Vector)

	# make sure payments is the same length as loan
	if length(loans) != length(payments)
		error("Not the same number of payments as loans")
	end

	# Create array for new loans
	stepped_loans = Array{Loan, 1}(undef, length(loans))
	
	# time step for each loan
	for i in 1:length(loans)
		stepped_loans[i] = step_time!(loans[i], payments[i])
	end

	# add up all the loan values
	new_total_owed = aggregate_owed(stepped_loans...)
	return new_total_owed
end


# ╔═╡ ef8de14e-b982-4c99-b482-bb8214dee437
md" ## Step 1: How to optimize split of 20k"

# ╔═╡ 7663ffc0-8910-48b7-93ad-9af55a8c6bca
# Define madie's loans
begin
loan_aa = Loan(14159.06,
	835.92, 
	0.07,
	12)

loan_ab = Loan(7435.00,
	400.91,
	0.076,
	12)

loan_ac = Loan(250,
	12.83,
	0.076,
	12)

loan_ad = Loan(15246.58,
	97.67,
	0.06,
	12)

loan_ae = Loan(20654.47,
	145.55,
	0.066,
	12)
end

# ╔═╡ 0d3e7efb-d199-4d83-9351-0abb30c920f7
accrue!(loan_ae)

# ╔═╡ 1e40b3c1-f11e-4026-aff4-16949f2b6ed6
pay!(loan_ac, 1000)

# ╔═╡ 4c433db5-db2e-408a-a9d6-608a8d7a7b12
step_time!(loan_ae, 1000)

# ╔═╡ 8f06f76c-6627-489f-81b3-656c5e6ab28d
loan_aggregate = aggregate_owed(loan_aa, loan_ab, loan_ac, loan_ad, loan_ae)

# ╔═╡ 6cfd6698-33f3-44a2-82b5-5dd743d31747
begin 
	# amount of money madie wants to pay the first month
	total_payment = 20000
end

# ╔═╡ c3aa6bd9-9373-4db0-b816-32ed2cd2a481
# How do we optimize the splitting of 20k into 5 pots (one for each loan)
# So there are two objectives on this system:
# 1. Sum of payments vector must = 20 000
# 2. simulate! must be minimized over all possible combinations of payments



# ╔═╡ 85a7af19-a65d-41cf-a2e1-3c5dced1f9f2
begin
# Set up the initaial guess of payments vector
init_guess = fill(4000, 5)
end

# ╔═╡ 4e163ccb-2a45-4143-a7d9-753436bd69f1
 # What happens if you simulate with the init_guess?0
 simulate!(loan_aa, loan_ab, loan_ac, loan_ad, loan_ae; payments = [0, 0, 0, 0, 0])

# ╔═╡ f7161d5a-41f7-4a14-951f-25b2a67b9d7b
# How to define it as a JuMP problem. I think using JuMP will allow me to model the sum of 20000 constraint

# ╔═╡ 171ddff4-7a0c-4072-8449-40a0e0475b3d
md" ### Step 1a: Optimization using JuMP"

# ╔═╡ 7965c435-8759-4555-a4f1-c5f34d9eba5f
# Define the loss function
loss = ( guess ) -> simulate!(loan_aa, loan_ab, loan_ac, loan_ad, loan_ae; payments = guess)

# ╔═╡ a0ceb2e2-81e9-4252-8ffc-ce8abb718861
# Define the model
model = Model(HiGHS.Optimizer)

# ╔═╡ d0c8ded5-966b-4908-975f-aa985c089c01
# define the variable
@variable(model, x[1:5])

# ╔═╡ bcdd7def-639b-40a4-bdc5-fc07ae96fb27
# define the constraint
@constraint(model, c1, sum(x) == 20000)

# ╔═╡ a3b72252-d5c9-4a17-9484-c7e0ab71493f
@operator(model, op_loss, 5, (x...) -> loss(collect(x)))

# ╔═╡ c216005a-6851-47cb-826f-6058eaf41545
# Define the objective
@objective(model, Min, op_loss)

# ╔═╡ edfe5b5f-1663-4144-838a-256b8407ee7d


# ╔═╡ 71c68ccc-4839-4ef5-863d-21e4f49dce2b
md" ### Step 1b: Optimization using Optim.jl"

# ╔═╡ a1377441-0375-4cb5-ae45-6a7471f94e0c
md" This doesn't work yet"

# ╔═╡ 90266407-f41e-4e3c-b424-2aaadc15af27
loss(init_guess)

# ╔═╡ 40e7bede-971f-44fd-a784-4c1cebe7714b
result = Optim.optimize(loss, zeros(5))

# ╔═╡ d2898596-b404-4b7f-a464-1ade529cc98c
md" ### Step 1C - brute force it"

# ╔═╡ 2e229e16-5529-462d-a2db-aa7419f4ec74
begin
	# generate a vector of all combiniations of 5 integers that sum to 20000. This will be a whole lot of vectors...
	prior_balance = loss(zeros(5))
	best_choices = zeros(5)
		
	for i in range(1,100000000)
		# randomly pick 5 numbers from the vector of 1 to 20000
		choice_vec = range(1, 20000)
		choices = rand(choice_vec, 5)
		# Calculate sum and throw out if != 20000
		if sum(choices) == 20000
			# How do I store the choices and check if they have already been explored?

			
			
			new_balance = loss(choices)
			if new_balance < prior_balance
				prior_balance = new_balance
				best_choices = choices
			end
		else
			continue
		end
	end

	(prior_balance, best_choices)
	
end

# ╔═╡ 541a9e01-baa1-498b-ab3e-d1886a45489d
simulate!(loan_aa, loan_ab, loan_ac, loan_ad, loan_ae; payments = best_choices)

# ╔═╡ 1adff5af-f75a-4451-836e-217acd788a93
loss(fill(4000, 5))

# ╔═╡ 3cfc6bfe-5392-41a4-89ef-ee1c139a9d5c
begin
	[]
end

# ╔═╡ 3c2245c9-f4b7-4f0b-afe6-c0464fdaf720
begin
	struct Payments
	    p1::Int
	    p2::Int
		p3::Int
		p4::Int
		p5::Int
	end
	
	Base.iterate(p::Payments) = fill(1,p.p1), 
	fill(1,p.p2), 
	fill(1, p.p3),
	fill(1, p.p4),
	fill(1, p.p5) #start the iteration with 1's
	
	Base.IteratorSize(::Type{Payments}) = Base.SizeUnknown()
	
	function Base.iterate(p::Payments, state)
		if state ≠ fill(p.n,p.m) # end when each row has an n
			newstate = next(state,p.n)
			return newstate, newstate
	    end
	end
	
	
	function next(path,n)
	    k = length(path)
		# start from the end and find the first element that can be updated by adding 1
	    while  k≥2 && ( path[k]==n || path[k]+1 > path[k-1]+1 )
	        k -= 1
	    end   
	    path[k] +=1 #add the one then reset the following elements
	    for j = k+1 : length(path)
	        path[j] = max(path[j-1]-1,1)
	    end
	    return(path)
	end
	
	function allpaths(m,n)
		Vector{Int}[
			copy(p) for p in Paths(m,n)
		]
	end
end

# ╔═╡ 00000000-0000-0000-0000-000000000001
PLUTO_PROJECT_TOML_CONTENTS = """
[deps]
HiGHS = "87dc4568-4c63-4d18-b0c0-bb2238e4078b"
JuMP = "4076af6c-e467-56ae-b986-b466b2749572"
Optim = "429524aa-4258-5aef-a3af-852621145aeb"

[compat]
HiGHS = "~1.7.3"
JuMP = "~1.15.1"
Optim = "~1.7.8"
"""

# ╔═╡ 00000000-0000-0000-0000-000000000002
PLUTO_MANIFEST_TOML_CONTENTS = """
# This file is machine-generated - editing it directly is not advised

julia_version = "1.9.2"
manifest_format = "2.0"
project_hash = "ea68a51afb14c79d97a87846a08271aaf43e904c"

[[deps.Adapt]]
deps = ["LinearAlgebra", "Requires"]
git-tree-sha1 = "76289dc51920fdc6e0013c872ba9551d54961c24"
uuid = "79e6a3ab-5dfb-504d-930d-738a2a938a0e"
version = "3.6.2"

    [deps.Adapt.extensions]
    AdaptStaticArraysExt = "StaticArrays"

    [deps.Adapt.weakdeps]
    StaticArrays = "90137ffa-7385-5640-81b9-e52037218182"

[[deps.ArgTools]]
uuid = "0dad84c5-d112-42e6-8d28-ef12dabb789f"
version = "1.1.1"

[[deps.ArrayInterface]]
deps = ["Adapt", "LinearAlgebra", "Requires", "SparseArrays", "SuiteSparse"]
git-tree-sha1 = "f83ec24f76d4c8f525099b2ac475fc098138ec31"
uuid = "4fba245c-0d91-5ea0-9b3e-6abc04ee57a9"
version = "7.4.11"

    [deps.ArrayInterface.extensions]
    ArrayInterfaceBandedMatricesExt = "BandedMatrices"
    ArrayInterfaceBlockBandedMatricesExt = "BlockBandedMatrices"
    ArrayInterfaceCUDAExt = "CUDA"
    ArrayInterfaceGPUArraysCoreExt = "GPUArraysCore"
    ArrayInterfaceStaticArraysCoreExt = "StaticArraysCore"
    ArrayInterfaceTrackerExt = "Tracker"

    [deps.ArrayInterface.weakdeps]
    BandedMatrices = "aae01518-5342-5314-be14-df237901396f"
    BlockBandedMatrices = "ffab5731-97b5-5995-9138-79e8c1846df0"
    CUDA = "052768ef-5323-5732-b1bb-66c8b64840ba"
    GPUArraysCore = "46192b85-c4d5-4398-a991-12ede77f4527"
    StaticArraysCore = "1e83bf80-4336-4d27-bf5d-d5a4f845583c"
    Tracker = "9f7883ad-71c0-57eb-9f7f-b5c9e6d3789c"

[[deps.Artifacts]]
uuid = "56f22d72-fd6d-98f1-02f0-08ddc0907c33"

[[deps.Base64]]
uuid = "2a0f44e3-6c83-55bd-87e4-b1978d98bd5f"

[[deps.BenchmarkTools]]
deps = ["JSON", "Logging", "Printf", "Profile", "Statistics", "UUIDs"]
git-tree-sha1 = "d9a9701b899b30332bbcb3e1679c41cce81fb0e8"
uuid = "6e4b80f9-dd63-53aa-95a3-0cdb28fa8baf"
version = "1.3.2"

[[deps.Bzip2_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "19a35467a82e236ff51bc17a3a44b69ef35185a2"
uuid = "6e34b625-4abd-537c-b88f-471c36dfa7a0"
version = "1.0.8+0"

[[deps.CodecBzip2]]
deps = ["Bzip2_jll", "Libdl", "TranscodingStreams"]
git-tree-sha1 = "ad41de3795924f7a056243eb3e4161448f0523e6"
uuid = "523fee87-0ab8-5b00-afb7-3ecf72e48cfd"
version = "0.8.0"

[[deps.CodecZlib]]
deps = ["TranscodingStreams", "Zlib_jll"]
git-tree-sha1 = "02aa26a4cf76381be7f66e020a3eddeb27b0a092"
uuid = "944b1d66-785c-5afd-91f1-9de20f533193"
version = "0.7.2"

[[deps.CommonSubexpressions]]
deps = ["MacroTools", "Test"]
git-tree-sha1 = "7b8a93dba8af7e3b42fecabf646260105ac373f7"
uuid = "bbf7d656-a473-5ed7-a52c-81e309532950"
version = "0.3.0"

[[deps.Compat]]
deps = ["UUIDs"]
git-tree-sha1 = "8a62af3e248a8c4bad6b32cbbe663ae02275e32c"
uuid = "34da2185-b29b-5c13-b0c7-acf172513d20"
version = "4.10.0"
weakdeps = ["Dates", "LinearAlgebra"]

    [deps.Compat.extensions]
    CompatLinearAlgebraExt = "LinearAlgebra"

[[deps.CompilerSupportLibraries_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "e66e0078-7015-5450-92f7-15fbd957f2ae"
version = "1.0.5+0"

[[deps.ConstructionBase]]
deps = ["LinearAlgebra"]
git-tree-sha1 = "c53fc348ca4d40d7b371e71fd52251839080cbc9"
uuid = "187b0558-2788-49d3-abe0-74a17ed4e7c9"
version = "1.5.4"

    [deps.ConstructionBase.extensions]
    ConstructionBaseIntervalSetsExt = "IntervalSets"
    ConstructionBaseStaticArraysExt = "StaticArrays"

    [deps.ConstructionBase.weakdeps]
    IntervalSets = "8197267c-284f-5f27-9208-e0e47529a953"
    StaticArrays = "90137ffa-7385-5640-81b9-e52037218182"

[[deps.DataAPI]]
git-tree-sha1 = "8da84edb865b0b5b0100c0666a9bc9a0b71c553c"
uuid = "9a962f9c-6df0-11e9-0e5d-c546b8b5ee8a"
version = "1.15.0"

[[deps.DataStructures]]
deps = ["Compat", "InteractiveUtils", "OrderedCollections"]
git-tree-sha1 = "3dbd312d370723b6bb43ba9d02fc36abade4518d"
uuid = "864edb3b-99cc-5e75-8d2d-829cb0a9cfe8"
version = "0.18.15"

[[deps.Dates]]
deps = ["Printf"]
uuid = "ade2ca70-3891-5945-98fb-dc099432e06a"

[[deps.DiffResults]]
deps = ["StaticArraysCore"]
git-tree-sha1 = "782dd5f4561f5d267313f23853baaaa4c52ea621"
uuid = "163ba53b-c6d8-5494-b064-1a9d43ac40c5"
version = "1.1.0"

[[deps.DiffRules]]
deps = ["IrrationalConstants", "LogExpFunctions", "NaNMath", "Random", "SpecialFunctions"]
git-tree-sha1 = "23163d55f885173722d1e4cf0f6110cdbaf7e272"
uuid = "b552c78f-8df3-52c6-915a-8e097449b14b"
version = "1.15.1"

[[deps.Distributed]]
deps = ["Random", "Serialization", "Sockets"]
uuid = "8ba89e20-285c-5b6f-9357-94700520ee1b"

[[deps.DocStringExtensions]]
deps = ["LibGit2"]
git-tree-sha1 = "2fb1e02f2b635d0845df5d7c167fec4dd739b00d"
uuid = "ffbed154-4ef7-542d-bbb7-c09d3a79fcae"
version = "0.9.3"

[[deps.Downloads]]
deps = ["ArgTools", "FileWatching", "LibCURL", "NetworkOptions"]
uuid = "f43a241f-c20a-4ad4-852c-f6b1247861c6"
version = "1.6.0"

[[deps.FileWatching]]
uuid = "7b1f6079-737a-58dc-b8bc-7a2ca5c1b5ee"

[[deps.FillArrays]]
deps = ["LinearAlgebra", "Random"]
git-tree-sha1 = "a20eaa3ad64254c61eeb5f230d9306e937405434"
uuid = "1a297f60-69ca-5386-bcde-b61e274b549b"
version = "1.6.1"
weakdeps = ["SparseArrays", "Statistics"]

    [deps.FillArrays.extensions]
    FillArraysSparseArraysExt = "SparseArrays"
    FillArraysStatisticsExt = "Statistics"

[[deps.FiniteDiff]]
deps = ["ArrayInterface", "LinearAlgebra", "Requires", "Setfield", "SparseArrays"]
git-tree-sha1 = "c6e4a1fbe73b31a3dea94b1da449503b8830c306"
uuid = "6a86dc24-6348-571c-b903-95158fe2bd41"
version = "2.21.1"

    [deps.FiniteDiff.extensions]
    FiniteDiffBandedMatricesExt = "BandedMatrices"
    FiniteDiffBlockBandedMatricesExt = "BlockBandedMatrices"
    FiniteDiffStaticArraysExt = "StaticArrays"

    [deps.FiniteDiff.weakdeps]
    BandedMatrices = "aae01518-5342-5314-be14-df237901396f"
    BlockBandedMatrices = "ffab5731-97b5-5995-9138-79e8c1846df0"
    StaticArrays = "90137ffa-7385-5640-81b9-e52037218182"

[[deps.ForwardDiff]]
deps = ["CommonSubexpressions", "DiffResults", "DiffRules", "LinearAlgebra", "LogExpFunctions", "NaNMath", "Preferences", "Printf", "Random", "SpecialFunctions"]
git-tree-sha1 = "cf0fe81336da9fb90944683b8c41984b08793dad"
uuid = "f6369f11-7733-5829-9624-2563aa707210"
version = "0.10.36"

    [deps.ForwardDiff.extensions]
    ForwardDiffStaticArraysExt = "StaticArrays"

    [deps.ForwardDiff.weakdeps]
    StaticArrays = "90137ffa-7385-5640-81b9-e52037218182"

[[deps.Future]]
deps = ["Random"]
uuid = "9fa8497b-333b-5362-9e8d-4d0656e87820"

[[deps.HiGHS]]
deps = ["HiGHS_jll", "MathOptInterface", "PrecompileTools", "SparseArrays"]
git-tree-sha1 = "9d75ef949c17a2a150b91b8365a6e5bc43a2a0d3"
uuid = "87dc4568-4c63-4d18-b0c0-bb2238e4078b"
version = "1.7.3"

[[deps.HiGHS_jll]]
deps = ["Artifacts", "CompilerSupportLibraries_jll", "JLLWrappers", "Libdl"]
git-tree-sha1 = "10bf0ecdf70f643bfc1948a6af0a98be3950a3fc"
uuid = "8fd58aa0-07eb-5a78-9b36-339c94fd15ea"
version = "1.6.0+0"

[[deps.InteractiveUtils]]
deps = ["Markdown"]
uuid = "b77e0a4c-d291-57a0-90e8-8db25a27a240"

[[deps.IrrationalConstants]]
git-tree-sha1 = "630b497eafcc20001bba38a4651b327dcfc491d2"
uuid = "92d709cd-6900-40b7-9082-c6be49f344b6"
version = "0.2.2"

[[deps.JLLWrappers]]
deps = ["Artifacts", "Preferences"]
git-tree-sha1 = "7e5d6779a1e09a36db2a7b6cff50942a0a7d0fca"
uuid = "692b3bcd-3c85-4b1f-b108-f13ce0eb3210"
version = "1.5.0"

[[deps.JSON]]
deps = ["Dates", "Mmap", "Parsers", "Unicode"]
git-tree-sha1 = "31e996f0a15c7b280ba9f76636b3ff9e2ae58c9a"
uuid = "682c06a0-de6a-54ab-a142-c8b1cf79cde6"
version = "0.21.4"

[[deps.JuMP]]
deps = ["LinearAlgebra", "MacroTools", "MathOptInterface", "MutableArithmetics", "OrderedCollections", "Printf", "SnoopPrecompile", "SparseArrays"]
git-tree-sha1 = "3700a700bc80856fe673b355123ae4574f2d5dfe"
uuid = "4076af6c-e467-56ae-b986-b466b2749572"
version = "1.15.1"

    [deps.JuMP.extensions]
    JuMPDimensionalDataExt = "DimensionalData"

    [deps.JuMP.weakdeps]
    DimensionalData = "0703355e-b756-11e9-17c0-8b28908087d0"

[[deps.LibCURL]]
deps = ["LibCURL_jll", "MozillaCACerts_jll"]
uuid = "b27032c2-a3e7-50c8-80cd-2d36dbcbfd21"
version = "0.6.3"

[[deps.LibCURL_jll]]
deps = ["Artifacts", "LibSSH2_jll", "Libdl", "MbedTLS_jll", "Zlib_jll", "nghttp2_jll"]
uuid = "deac9b47-8bc7-5906-a0fe-35ac56dc84c0"
version = "7.84.0+0"

[[deps.LibGit2]]
deps = ["Base64", "NetworkOptions", "Printf", "SHA"]
uuid = "76f85450-5226-5b5a-8eaa-529ad045b433"

[[deps.LibSSH2_jll]]
deps = ["Artifacts", "Libdl", "MbedTLS_jll"]
uuid = "29816b5a-b9ab-546f-933c-edad1886dfa8"
version = "1.10.2+0"

[[deps.Libdl]]
uuid = "8f399da3-3557-5675-b5ff-fb832c97cbdb"

[[deps.LineSearches]]
deps = ["LinearAlgebra", "NLSolversBase", "NaNMath", "Parameters", "Printf"]
git-tree-sha1 = "7bbea35cec17305fc70a0e5b4641477dc0789d9d"
uuid = "d3d80556-e9d4-5f37-9878-2ab0fcc64255"
version = "7.2.0"

[[deps.LinearAlgebra]]
deps = ["Libdl", "OpenBLAS_jll", "libblastrampoline_jll"]
uuid = "37e2e46d-f89d-539d-b4ee-838fcccc9c8e"

[[deps.LogExpFunctions]]
deps = ["DocStringExtensions", "IrrationalConstants", "LinearAlgebra"]
git-tree-sha1 = "7d6dd4e9212aebaeed356de34ccf262a3cd415aa"
uuid = "2ab3a3ac-af41-5b50-aa03-7779005ae688"
version = "0.3.26"

    [deps.LogExpFunctions.extensions]
    LogExpFunctionsChainRulesCoreExt = "ChainRulesCore"
    LogExpFunctionsChangesOfVariablesExt = "ChangesOfVariables"
    LogExpFunctionsInverseFunctionsExt = "InverseFunctions"

    [deps.LogExpFunctions.weakdeps]
    ChainRulesCore = "d360d2e6-b24c-11e9-a2a3-2a2ae2dbcce4"
    ChangesOfVariables = "9e997f8a-9a97-42d5-a9f1-ce6bfc15e2c0"
    InverseFunctions = "3587e190-3f89-42d0-90ee-14403ec27112"

[[deps.Logging]]
uuid = "56ddb016-857b-54e1-b83d-db4d58db5568"

[[deps.MacroTools]]
deps = ["Markdown", "Random"]
git-tree-sha1 = "9ee1618cbf5240e6d4e0371d6f24065083f60c48"
uuid = "1914dd2f-81c6-5fcd-8719-6d5c9610ff09"
version = "0.5.11"

[[deps.Markdown]]
deps = ["Base64"]
uuid = "d6f4376e-aef5-505a-96c1-9c027394607a"

[[deps.MathOptInterface]]
deps = ["BenchmarkTools", "CodecBzip2", "CodecZlib", "DataStructures", "ForwardDiff", "JSON", "LinearAlgebra", "MutableArithmetics", "NaNMath", "OrderedCollections", "PrecompileTools", "Printf", "SparseArrays", "SpecialFunctions", "Test", "Unicode"]
git-tree-sha1 = "5c9f1e635e8d491297e596b56fec1c95eafb95a3"
uuid = "b8f27783-ece8-5eb3-8dc8-9495eed66fee"
version = "1.20.1"

[[deps.MbedTLS_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "c8ffd9c3-330d-5841-b78e-0817d7145fa1"
version = "2.28.2+0"

[[deps.Missings]]
deps = ["DataAPI"]
git-tree-sha1 = "f66bdc5de519e8f8ae43bdc598782d35a25b1272"
uuid = "e1d29d7a-bbdc-5cf2-9ac0-f12de2c33e28"
version = "1.1.0"

[[deps.Mmap]]
uuid = "a63ad114-7e13-5084-954f-fe012c677804"

[[deps.MozillaCACerts_jll]]
uuid = "14a3606d-f60d-562e-9121-12d972cd8159"
version = "2022.10.11"

[[deps.MutableArithmetics]]
deps = ["LinearAlgebra", "SparseArrays", "Test"]
git-tree-sha1 = "6985021d02ab8c509c841bb8b2becd3145a7b490"
uuid = "d8a4904e-b15c-11e9-3269-09a3773c0cb0"
version = "1.3.3"

[[deps.NLSolversBase]]
deps = ["DiffResults", "Distributed", "FiniteDiff", "ForwardDiff"]
git-tree-sha1 = "a0b464d183da839699f4c79e7606d9d186ec172c"
uuid = "d41bc354-129a-5804-8e4c-c37616107c6c"
version = "7.8.3"

[[deps.NaNMath]]
deps = ["OpenLibm_jll"]
git-tree-sha1 = "0877504529a3e5c3343c6f8b4c0381e57e4387e4"
uuid = "77ba4419-2d1f-58cd-9bb1-8ffee604a2e3"
version = "1.0.2"

[[deps.NetworkOptions]]
uuid = "ca575930-c2e3-43a9-ace4-1e988b2c1908"
version = "1.2.0"

[[deps.OpenBLAS_jll]]
deps = ["Artifacts", "CompilerSupportLibraries_jll", "Libdl"]
uuid = "4536629a-c528-5b80-bd46-f80d51c5b363"
version = "0.3.21+4"

[[deps.OpenLibm_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "05823500-19ac-5b8b-9628-191a04bc5112"
version = "0.8.1+0"

[[deps.OpenSpecFun_jll]]
deps = ["Artifacts", "CompilerSupportLibraries_jll", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "13652491f6856acfd2db29360e1bbcd4565d04f1"
uuid = "efe28fd5-8261-553b-a9e1-b2916fc3738e"
version = "0.5.5+0"

[[deps.Optim]]
deps = ["Compat", "FillArrays", "ForwardDiff", "LineSearches", "LinearAlgebra", "NLSolversBase", "NaNMath", "Parameters", "PositiveFactorizations", "Printf", "SparseArrays", "StatsBase"]
git-tree-sha1 = "01f85d9269b13fedc61e63cc72ee2213565f7a72"
uuid = "429524aa-4258-5aef-a3af-852621145aeb"
version = "1.7.8"

[[deps.OrderedCollections]]
git-tree-sha1 = "2e73fe17cac3c62ad1aebe70d44c963c3cfdc3e3"
uuid = "bac558e1-5e72-5ebc-8fee-abe8a469f55d"
version = "1.6.2"

[[deps.Parameters]]
deps = ["OrderedCollections", "UnPack"]
git-tree-sha1 = "34c0e9ad262e5f7fc75b10a9952ca7692cfc5fbe"
uuid = "d96e819e-fc66-5662-9728-84c9c7592b0a"
version = "0.12.3"

[[deps.Parsers]]
deps = ["Dates", "PrecompileTools", "UUIDs"]
git-tree-sha1 = "716e24b21538abc91f6205fd1d8363f39b442851"
uuid = "69de0a69-1ddd-5017-9359-2bf0b02dc9f0"
version = "2.7.2"

[[deps.Pkg]]
deps = ["Artifacts", "Dates", "Downloads", "FileWatching", "LibGit2", "Libdl", "Logging", "Markdown", "Printf", "REPL", "Random", "SHA", "Serialization", "TOML", "Tar", "UUIDs", "p7zip_jll"]
uuid = "44cfe95a-1eb2-52ea-b672-e2afdf69b78f"
version = "1.9.2"

[[deps.PositiveFactorizations]]
deps = ["LinearAlgebra"]
git-tree-sha1 = "17275485f373e6673f7e7f97051f703ed5b15b20"
uuid = "85a6dd25-e78a-55b7-8502-1745935b8125"
version = "0.2.4"

[[deps.PrecompileTools]]
deps = ["Preferences"]
git-tree-sha1 = "03b4c25b43cb84cee5c90aa9b5ea0a78fd848d2f"
uuid = "aea7be01-6a6a-4083-8856-8a6e6704d82a"
version = "1.2.0"

[[deps.Preferences]]
deps = ["TOML"]
git-tree-sha1 = "00805cd429dcb4870060ff49ef443486c262e38e"
uuid = "21216c6a-2e73-6563-6e65-726566657250"
version = "1.4.1"

[[deps.Printf]]
deps = ["Unicode"]
uuid = "de0858da-6303-5e67-8744-51eddeeeb8d7"

[[deps.Profile]]
deps = ["Printf"]
uuid = "9abbd945-dff8-562f-b5e8-e1ebf5ef1b79"

[[deps.REPL]]
deps = ["InteractiveUtils", "Markdown", "Sockets", "Unicode"]
uuid = "3fa0cd96-eef1-5676-8a61-b3b8758bbffb"

[[deps.Random]]
deps = ["SHA", "Serialization"]
uuid = "9a3f8284-a2c9-5f02-9a11-845980a1fd5c"

[[deps.Requires]]
deps = ["UUIDs"]
git-tree-sha1 = "838a3a4188e2ded87a4f9f184b4b0d78a1e91cb7"
uuid = "ae029012-a4dd-5104-9daa-d747884805df"
version = "1.3.0"

[[deps.SHA]]
uuid = "ea8e919c-243c-51af-8825-aaa63cd721ce"
version = "0.7.0"

[[deps.Serialization]]
uuid = "9e88b42a-f829-5b0c-bbe9-9e923198166b"

[[deps.Setfield]]
deps = ["ConstructionBase", "Future", "MacroTools", "StaticArraysCore"]
git-tree-sha1 = "e2cc6d8c88613c05e1defb55170bf5ff211fbeac"
uuid = "efcf1570-3423-57d1-acb7-fd33fddbac46"
version = "1.1.1"

[[deps.SnoopPrecompile]]
deps = ["Preferences"]
git-tree-sha1 = "e760a70afdcd461cf01a575947738d359234665c"
uuid = "66db9d55-30c0-4569-8b51-7e840670fc0c"
version = "1.0.3"

[[deps.Sockets]]
uuid = "6462fe0b-24de-5631-8697-dd941f90decc"

[[deps.SortingAlgorithms]]
deps = ["DataStructures"]
git-tree-sha1 = "c60ec5c62180f27efea3ba2908480f8055e17cee"
uuid = "a2af1166-a08f-5f64-846c-94a0d3cef48c"
version = "1.1.1"

[[deps.SparseArrays]]
deps = ["Libdl", "LinearAlgebra", "Random", "Serialization", "SuiteSparse_jll"]
uuid = "2f01184e-e22b-5df5-ae63-d93ebab69eaf"

[[deps.SpecialFunctions]]
deps = ["IrrationalConstants", "LogExpFunctions", "OpenLibm_jll", "OpenSpecFun_jll"]
git-tree-sha1 = "e2cfc4012a19088254b3950b85c3c1d8882d864d"
uuid = "276daf66-3868-5448-9aa4-cd146d93841b"
version = "2.3.1"

    [deps.SpecialFunctions.extensions]
    SpecialFunctionsChainRulesCoreExt = "ChainRulesCore"

    [deps.SpecialFunctions.weakdeps]
    ChainRulesCore = "d360d2e6-b24c-11e9-a2a3-2a2ae2dbcce4"

[[deps.StaticArraysCore]]
git-tree-sha1 = "36b3d696ce6366023a0ea192b4cd442268995a0d"
uuid = "1e83bf80-4336-4d27-bf5d-d5a4f845583c"
version = "1.4.2"

[[deps.Statistics]]
deps = ["LinearAlgebra", "SparseArrays"]
uuid = "10745b16-79ce-11e8-11f9-7d13ad32a3b2"
version = "1.9.0"

[[deps.StatsAPI]]
deps = ["LinearAlgebra"]
git-tree-sha1 = "1ff449ad350c9c4cbc756624d6f8a8c3ef56d3ed"
uuid = "82ae8749-77ed-4fe6-ae5f-f523153014b0"
version = "1.7.0"

[[deps.StatsBase]]
deps = ["DataAPI", "DataStructures", "LinearAlgebra", "LogExpFunctions", "Missings", "Printf", "Random", "SortingAlgorithms", "SparseArrays", "Statistics", "StatsAPI"]
git-tree-sha1 = "1d77abd07f617c4868c33d4f5b9e1dbb2643c9cf"
uuid = "2913bbd2-ae8a-5f71-8c99-4fb6c76f3a91"
version = "0.34.2"

[[deps.SuiteSparse]]
deps = ["Libdl", "LinearAlgebra", "Serialization", "SparseArrays"]
uuid = "4607b0f0-06f3-5cda-b6b1-a6196a1729e9"

[[deps.SuiteSparse_jll]]
deps = ["Artifacts", "Libdl", "Pkg", "libblastrampoline_jll"]
uuid = "bea87d4a-7f5b-5778-9afe-8cc45184846c"
version = "5.10.1+6"

[[deps.TOML]]
deps = ["Dates"]
uuid = "fa267f1f-6049-4f14-aa54-33bafae1ed76"
version = "1.0.3"

[[deps.Tar]]
deps = ["ArgTools", "SHA"]
uuid = "a4e569a6-e804-4fa4-b0f3-eef7a1d5b13e"
version = "1.10.0"

[[deps.Test]]
deps = ["InteractiveUtils", "Logging", "Random", "Serialization"]
uuid = "8dfed614-e22c-5e08-85e1-65c5234f0b40"

[[deps.TranscodingStreams]]
deps = ["Random", "Test"]
git-tree-sha1 = "9a6ae7ed916312b41236fcef7e0af564ef934769"
uuid = "3bb67fe8-82b1-5028-8e26-92a6c54297fa"
version = "0.9.13"

[[deps.UUIDs]]
deps = ["Random", "SHA"]
uuid = "cf7118a7-6976-5b1a-9a39-7adc72f591a4"

[[deps.UnPack]]
git-tree-sha1 = "387c1f73762231e86e0c9c5443ce3b4a0a9a0c2b"
uuid = "3a884ed6-31ef-47d7-9d2a-63182c4928ed"
version = "1.0.2"

[[deps.Unicode]]
uuid = "4ec0a83e-493e-50e2-b9ac-8f72acf5a8f5"

[[deps.Zlib_jll]]
deps = ["Libdl"]
uuid = "83775a58-1f1d-513f-b197-d71354ab007a"
version = "1.2.13+0"

[[deps.libblastrampoline_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "8e850b90-86db-534c-a0d3-1478176c7d93"
version = "5.8.0+0"

[[deps.nghttp2_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "8e850ede-7688-5339-a07c-302acd2aaf8d"
version = "1.48.0+0"

[[deps.p7zip_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "3f19e933-33d8-53b3-aaab-bd5110c3b7a0"
version = "17.4.0+0"
"""

# ╔═╡ Cell order:
# ╠═572c2ccc-6883-11ee-1e39-edcceae11cfe
# ╠═6b392bb8-2d02-4708-b8be-6f21431384b6
# ╠═69c80c94-de9c-4ada-a333-1a30fe495f5a
# ╠═183bc85c-9fba-48be-bcec-6fd5825feec4
# ╠═a22e8fc2-53d2-4f39-95f5-9329e57991c5
# ╠═0310879c-4de5-4d26-9090-7087476a5a1e
# ╠═0d3e7efb-d199-4d83-9351-0abb30c920f7
# ╠═99194fad-be56-41d8-be5e-1b3a111d16a7
# ╠═1e40b3c1-f11e-4026-aff4-16949f2b6ed6
# ╠═818070e1-1594-489c-bf21-fbe0d98e4319
# ╠═4c433db5-db2e-408a-a9d6-608a8d7a7b12
# ╠═5c1cd126-7bb8-47d0-91be-6cc28bae61c7
# ╠═2d99efe9-e754-487d-8d74-82cba486a60a
# ╠═ef8de14e-b982-4c99-b482-bb8214dee437
# ╠═7663ffc0-8910-48b7-93ad-9af55a8c6bca
# ╠═8f06f76c-6627-489f-81b3-656c5e6ab28d
# ╠═6cfd6698-33f3-44a2-82b5-5dd743d31747
# ╠═c3aa6bd9-9373-4db0-b816-32ed2cd2a481
# ╠═85a7af19-a65d-41cf-a2e1-3c5dced1f9f2
# ╠═4e163ccb-2a45-4143-a7d9-753436bd69f1
# ╠═f7161d5a-41f7-4a14-951f-25b2a67b9d7b
# ╠═171ddff4-7a0c-4072-8449-40a0e0475b3d
# ╠═7965c435-8759-4555-a4f1-c5f34d9eba5f
# ╠═a0ceb2e2-81e9-4252-8ffc-ce8abb718861
# ╠═d0c8ded5-966b-4908-975f-aa985c089c01
# ╠═bcdd7def-639b-40a4-bdc5-fc07ae96fb27
# ╠═a3b72252-d5c9-4a17-9484-c7e0ab71493f
# ╠═c216005a-6851-47cb-826f-6058eaf41545
# ╠═edfe5b5f-1663-4144-838a-256b8407ee7d
# ╟─71c68ccc-4839-4ef5-863d-21e4f49dce2b
# ╟─a1377441-0375-4cb5-ae45-6a7471f94e0c
# ╠═90266407-f41e-4e3c-b424-2aaadc15af27
# ╠═40e7bede-971f-44fd-a784-4c1cebe7714b
# ╠═d2898596-b404-4b7f-a464-1ade529cc98c
# ╠═2e229e16-5529-462d-a2db-aa7419f4ec74
# ╠═541a9e01-baa1-498b-ab3e-d1886a45489d
# ╠═1adff5af-f75a-4451-836e-217acd788a93
# ╠═3cfc6bfe-5392-41a4-89ef-ee1c139a9d5c
# ╠═3c2245c9-f4b7-4f0b-afe6-c0464fdaf720
# ╟─00000000-0000-0000-0000-000000000001
# ╟─00000000-0000-0000-0000-000000000002
