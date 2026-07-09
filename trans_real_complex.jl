module trans_real_complex

using BlockDiagonals
using LinearAlgebra

export transform_realbasis,trans_realSPH
#########################################################################################################
function trans_realSPH(nmax,Nlocal,bas_type)

Utrans = zeros(ComplexF64,(Nlocal,Nlocal))

if bas_type == "translation"
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
elseif bas_type == "rotation"
	i1=0
	for j=0:nmax
		U = trans_l(j)
		for m1=-j:j 
			for m2=-j:j
				Utrans[i1+j+1+m1,i1+j+1+m2] = U[j+1+m1,j+1+m2]
			end
		end
		i1 += 2*j+1  
	end
end

return Utrans
end
#######################################################################################################
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
end



