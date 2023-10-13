### A Pluto.jl notebook ###
# v0.19.29

using Markdown
using InteractiveUtils

# ╔═╡ 572c2ccc-6883-11ee-1e39-edcceae11cfe
md"# _Calculating Compound interest for Madie's student loans_

Hopefully this will be helpful to find the optimal way to pay back her loans
"

# ╔═╡ 69c80c94-de9c-4ada-a333-1a30fe495f5a
md" ## Step 0: Setting up the functions for compound interest"

# ╔═╡ 183bc85c-9fba-48be-bcec-6fd5825feec4
# Create a loan struct that stores the principal, interest rate, and compounds per timestep
mutable struct Loan
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
	accrued = owed(loan) * (loan.interest / loan.compounds)
	loan.accrual = round(loan.accrual + accrued, digits = 2)
end


# ╔═╡ 99194fad-be56-41d8-be5e-1b3a111d16a7
# Function that subtracts the payment at the end of every time step

function pay!(loan::Loan, payment::Real)
	# First apply the payment to the accrual then to the principal if any left over
	if payment <= loan.accrual
		loan.accrual = loan.accrual - payment
	else
		difference = payment - loan.accrual
		loan.accrual = 0
		loan.principal = loan.principal - difference
	end

	# Don't let the loan principal go negative
	if loan.principal < 0
		loan.principal = 0
	end

	return loan
end



# ╔═╡ 818070e1-1594-489c-bf21-fbe0d98e4319
# Function that steps time one month in advance

function step_time!(loan::Loan, payment::Real)
	# Accrue the loan then pay off the loan
	accrue!(loan)
	pay!(loan, payment)
	return loan
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
	
	# Broadcast a time step for each loan
	for i in 1:length(loans)
		step_time!(loans[i], payments[i])
	end

	# add up all the loan values
	new_total_owed = aggregate_owed(loans...)
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

# ╔═╡ 8f06f76c-6627-489f-81b3-656c5e6ab28d
loan_aggregate = aggregate_owed(loan_aa, loan_ab, loan_ac, loan_ad, loan_ae)

# ╔═╡ 05353b82-edb3-46bc-a72e-bb70493cd6d8
# ╠═╡ disabled = true
#=╠═╡
simulate!(loan_aa, loan_ab, loan_ac, loan_ad, loan_ae; payments = [0,0,0,0,0])
  ╠═╡ =#

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


# ╔═╡ Cell order:
# ╠═572c2ccc-6883-11ee-1e39-edcceae11cfe
# ╠═69c80c94-de9c-4ada-a333-1a30fe495f5a
# ╠═183bc85c-9fba-48be-bcec-6fd5825feec4
# ╠═a22e8fc2-53d2-4f39-95f5-9329e57991c5
# ╠═0310879c-4de5-4d26-9090-7087476a5a1e
# ╠═99194fad-be56-41d8-be5e-1b3a111d16a7
# ╠═818070e1-1594-489c-bf21-fbe0d98e4319
# ╠═5c1cd126-7bb8-47d0-91be-6cc28bae61c7
# ╠═8f06f76c-6627-489f-81b3-656c5e6ab28d
# ╠═2d99efe9-e754-487d-8d74-82cba486a60a
# ╠═05353b82-edb3-46bc-a72e-bb70493cd6d8
# ╠═ef8de14e-b982-4c99-b482-bb8214dee437
# ╠═7663ffc0-8910-48b7-93ad-9af55a8c6bca
# ╠═6cfd6698-33f3-44a2-82b5-5dd743d31747
# ╠═c3aa6bd9-9373-4db0-b816-32ed2cd2a481
# ╠═85a7af19-a65d-41cf-a2e1-3c5dced1f9f2
