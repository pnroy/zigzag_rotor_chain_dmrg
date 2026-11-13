module trans_real_complex
__precompile__(false)   # local modules share names across run folders: never use the shared depot cache

using BlockDiagonals
using LinearAlgebra

export trans_realwigner,transform_realbasis,trans_realSPH,trans_even_odd
#########################################################################################################
function trans_realwigner(jmax,isomer)

if isomer == "para"
	U0=ones(ComplexF64,(1,1))

	Utrans=BlockDiagonal([U0])

	for j=1:jmax
		Uj=trans_j(j,isomer)
		Utrans=BlockDiagonal([Utrans,Uj])
	end
elseif isomer == "ortho"
	U0=trans_j(1,isomer)
	Utrans=BlockDiagonal([U0])

	for j=2:jmax
		Uj=trans_j(j,isomer)
		Utrans=BlockDiagonal([Utrans,Uj])
	end

end

Nlocal = size(Utrans,1)

Utrans_out=zeros(ComplexF64,(Nlocal,Nlocal))

for i=1:Nlocal
for j=1:Nlocal
	Utrans_out[i,j]=Utrans[i,j]
end
end

return Utrans_out
end
#########################################################################################################
function trans_realSPH(nmax,Nlocal)

Utrans = zeros(ComplexF64,(Nlocal,Nlocal))

i1=0
for n=0:nmax
for l=n:-2:0
	U = trans_l(l)
	for m1=-l:l 
		for m2=-l:l
			Utrans[i1+l+1+m1,i1+l+1+m2] = U[l+1+m1,l+1+m2]
		end
	end
	i1 += 2*l+1  
end
end	

return Utrans
end
#########################################################################################################
function trans_j(j,isomer)

Utrans=zeros(ComplexF64,((2*j+1)^2,(2*j+1)^2))

icomp=0
#Complex Basis
for m=-j:j
for k=-j:j
	icomp+=1
	#Real basis#
	#k_real=0 and m_real=0#
	if m ==0 && k ==0
		Utrans[icomp,1]=1.0
	end
	#k_real=0 and m_real=1,...,j#
	if k ==0 
		ireal=1
		for m_real=1:j
			ireal+=1
			if m == m_real
				#Cosine, even or odd#
				Utrans[icomp,ireal]=1.0/sqrt(2.0)
				ireal+=1
				#Sine, even or odd#
				Utrans[icomp,ireal]=1.0/(sqrt(2.0)im)
			elseif m == -m_real
				eo=mod(m_real,2)
				#Cosine, odd#
				Utrans[icomp,ireal]=((-1.0)^eo)/sqrt(2.0)
				ireal+=1
				#Sine, even#
				Utrans[icomp,ireal]=((-1.0)^(eo+1))/(sqrt(2.0)im)
			else
				ireal+=1
			end
	
		end
	else
		ireal=1+2*j
	end
	#k_real=1,...,j and m_real=-j,j#
	for k_real=1:j
	for m_real=-j:j
		ireal+=1
		if k == k_real && m == m_real
			Utrans[icomp,ireal]=1.0/sqrt(2.0)
			ireal+=1
			#Sine, even or odd#
			Utrans[icomp,ireal]=1.0/(sqrt(2.0)im)
		elseif k == -k_real && m == -m_real
			eo=mod(m_real-k_real,2)
			#Cosine#
			Utrans[icomp,ireal]=((-1.0)^eo)/sqrt(2.0)
			ireal+=1
			#Sine#
			Utrans[icomp,ireal]=((-1.0)^(eo+1))/(sqrt(2.0)im)
		else
			ireal+=1
		end
	end
	end
end
end

#Define left indices of respective spin isomer#
left_para = []
left_ortho = []
i=0
for m=-j:j
for k=-j:j
	i+=1
	if mod(k,2) == 0
		append!(left_para,i)		
	elseif mod(k,2) != 0
		append!(left_ortho,i)		
	end
end
end

#Define right indices of respective spin isomer#
right_para = []
right_ortho = []
append!(right_para,1)
i=1
for m=1:j
	i+=1
	append!(right_para,i)
	i+=1
	append!(right_para,i)
end

for k=1:j
for m=-j:j
	i+=1
	if mod(k,2) == 0
		append!(right_para,i)		
		i+=1
		append!(right_para,i)		
	elseif mod(k,2) != 0
		append!(right_ortho,i)		
		i+=1
		append!(right_ortho,i)		
	end
end
end

#Choose para or ortho and sort the indices back#
if isomer == "para"
	indices_left=sort(left_para)
	indices_right=sort(right_para)
elseif isomer == "ortho"
	indices_left=sort(left_ortho)
	indices_right=sort(right_ortho)
end

N=length(indices_left)
Uout = zeros(ComplexF64,(N,N))

i=0
for i1 in indices_left
    	i+=1
	j=0
	for j1 in indices_right
    		j+=1
		Uout[i,j]=Utrans[i1,j1]
    	end
end


return Uout
end
#######################################################################################################
function trans_l(l)

Utrans = zeros(ComplexF64,(2*l+1,2*l+1))

#Cpmplex basis
icomp=0
for m=-l:l
	icomp+=1	
	#ireal=0
	for m_real=-l:-1
		#ireal+=1
		if m == m_real
			Utrans[icomp,l+1+m_real] = 1.0im/sqrt(2.0)
		elseif m == -m_real
			Utrans[icomp,l+1+m_real] = -(1.0im/sqrt(2.0))*(-1)^m_real
		end
	end
	#ireal+=1
	if m == 0
		Utrans[icomp,l+1] = 1.0
	end
	for m_real=1:l
		#ireal+=1
		if m == -m_real
			Utrans[icomp,l+1+m_real] = 1.0/sqrt(2.0)
		elseif m == m_real
			Utrans[icomp,l+1+m_real] = ((-1.0)^m_real)/sqrt(2.0)
		end
	end

end

return Utrans
end
#######################################################################################################
function transform_realbasis(Utrans,matrix)

tmp=BLAS.gemm('C','N', Utrans,matrix)
matrix2=BLAS.gemm('N','N', tmp,Utrans)

N = size(matrix2,1)
matrix_out = zeros(N,N)
matrix_out .= real(matrix2)

return matrix_out
end
#######################################################################################################
function trans_even_odd(nmax,jmax,Ntrans,Nrot,isomer)

if isomer == "para"
	iso=0
elseif isomer == "ortho"
	iso=1
end

k_list = Array{Int,1}[]
k2_list = Array{Int,1}[]

for j=0:jmax
	list=Int[]
	for k=-j:j
		if mod(k,2) == iso
			push!(list,k)
		end
	end
	push!(k_list,list)

	list=Int[]
	for k=0:j
		if mod(k,2) == iso
			push!(list,k)
		end
	end
	push!(k2_list,list)



end

Ueven = zeros(ComplexF64,(Ntrans*Nrot,Ntrans*Nrot))
Uodd = zeros(ComplexF64,(Ntrans*Nrot,Ntrans*Nrot))

il = 0
ir_e = 0
ir_o = 0
ii_e = 0
ii_o = 0
ii_e2 = 0
ii_o2 = 0
for n=0:nmax
for l=n:-2:0
for ml=-l:l
	for j=0:jmax
	for m=-j:j
		ir_e+=ii_e#-ii_e2
		ir_o+=ii_o#-ii_o2
		ii_e2=0
		ii_o2=0
		#Determine if the k=0 function belongs to even or odd#
		if isomer == "para"
			if mod(j+l,2) == 0
				#ii_e2=1
				ii_o2=-1
			elseif mod(j+l+1,2) == 0
				#ii_o2=1
				ii_e2=-1
			end
		end
		for k1 in k_list[j+1] 
			il+=1
			ii_e=ii_e2
			ii_o=ii_o2
			for k2 in k2_list[j+1] 	
				ii_e+=1	
				ii_o+=1	
				if k1 == 0 && k2 == 0
					if mod(j+l,2) == 0
						Ueven[il,ir_e+1] = 1.0
					elseif mod(j+l+1,2) == 0
						Uodd[il,ir_o+1] = 1.0
					end
				end
				if k1 == -k2 && k1 != 0 && k2 !=0		
					expo = j+k2+l
					Ueven[il,ir_e+ii_e] =(1.0/sqrt(2.0))*(-1.0)^expo 
					Uodd[il,ir_o+ii_o] =(1.0/sqrt(2.0))*(-1.0)^(expo+1) 
				elseif k1 == k2 && k1 != 0 && k2 !=0 
					Ueven[il,ir_e+ii_e] =1.0/sqrt(2.0) 
					Uodd[il,ir_o+ii_o] =1.0/sqrt(2.0) 
				end
			end
		end
	end
	end
end
end
end
Neven = ir_e+ii_e 
Nodd = ir_o +ii_o

Ueven_out = zeros(ComplexF64,(Ntrans*Nrot,Neven))
Uodd_out = zeros(ComplexF64,(Ntrans*Nrot,Nodd))

for i=1:Neven
	Ueven_out[:,i] .= Ueven[:,i]
end
for i=1:Nodd
	Uodd_out[:,i] .= Uodd[:,i]
end

return Ueven_out,Uodd_out
end
#######################################################################################################
end
