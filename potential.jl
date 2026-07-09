module potential

using LinearAlgebra
using SpecialFunctions
using Jacobi
using AssociatedLegendrePolynomials
using ClassicalOrthogonalPolynomials: laguerrel
using GaussQuadrature: laguerre,legendre 
using FFTW
push!(LOAD_PATH,pwd())
using hf_potential
using lif_c60

export potential_matrix,decomposition,wigner_dmatrix,transformation_forward_HO,transformation_backward_HO,transformation_forward_SPH,transformation_backward_SPH

###############################################################################################################
function potential_matrix(nmax,NR,Ntheta,Nphi,jmax,Nalpha,Nm,omega,mass,Ntrans,Nrot,eq_struct,error)

nu=mass*omega*0.5

#Grids#

Ngrid1 = NR*Ntheta*Nphi
Ngrid2 = Nalpha*Nm
Ngrid = Ngrid1*Ngrid2

R,Rweight = laguerre(NR,0.5)
ctheta1, ct_weight1 = legendre(Ntheta)
ctheta2, ct_weight2 = legendre(Nalpha)
phi1=zeros(Nphi)
for i=1:Nphi
	phi1[i]=(i-1)*2.0*pi/Nphi
end
phi2=zeros(Nm)
for i=1:Nm
	phi2[i]=(i-1)*2.0*pi/Nm
end

#Write potential on grid#
Vpot = zeros(Ngrid1,Ngrid2)

i1=0
for ir=1:NR
for it1=1:Ntheta
for ip1=1:Nphi
	i1+=1
	i2=0
	for it2=1:Nalpha
	for ip2=1:Nm
		i2 += 1
		Vpot[i1,i2] = lif_cage_potential(sqrt(0.5*R[ir]/nu),acos(ctheta1[it1]),phi1[ip1],acos(ctheta2[it2]),phi2[ip2],eq_struct) 
		#Vpot[i1,i2] = enHFC60(sqrt(0.5*R[ir]/nu),acos(ctheta1[it1]),phi1[ip1],acos(ctheta2[it2]),phi2[ip2])
		#Vpot[i1,i2]=0.5*mass*(omega^2)*(0.5*R[ir]/nu)
	end
	end
end
end
end

######################################
#############SVD Approach#############
######################################

log_file=open("log","a")
println(log_file,"##Decompose cage potential on grid by SVD##")
close(log_file)
C,Vtrans,Vrot = decomposition(Vpot,error)
Nprod = length(C)


####################################################################################################
coeff_start1=zeros(ComplexF64,Ntrans)
coeff_start2=zeros(ComplexF64,Nrot)
coeff_grid1=zeros(ComplexF64,Ngrid1)
coeff_grid2=zeros(ComplexF64,Ngrid2)
coeff_out1=zeros(ComplexF64,Ngrid1)
coeff_out2=zeros(ComplexF64,Ngrid2)
coeff_end1=zeros(ComplexF64,(Ntrans))
coeff_end2=zeros(ComplexF64,(Nrot))
Vtrans_matrix=zeros(ComplexF64,(Ntrans,Ntrans,Nprod))
Vrot_matrix=zeros(ComplexF64,(Nrot,Nrot,Nprod))

#########################################################
##Calculation of potential matrices in iso. 3D-HO basis##
#########################################################

for ispec1=1:Ntrans
	coeff_start1.=0.0
	coeff_start1[ispec1]=1.0	

	###################################################
	##Transformation from NLM basis to spherical grid##
	###################################################

	coeff_grid1 = transformation_forward_HO(coeff_start1,nmax,NR,Ntheta,Nphi,nu,mass)

	#######################################
	##Act with potential operator on grid##
	#######################################
	for iprod=1:Nprod
		for i=1:Ngrid1
			coeff_out1[i]=coeff_grid1[i]*Vtrans[i,iprod]
		end
		###################################################
		##Transformation from spherical grid to NLM basis##
		###################################################
		coeff_end1 = transformation_backward_HO(coeff_out1,nmax,NR,Ntheta,Nphi,nu,mass,Ntrans)
		for ispec2=1:Ntrans
			Vtrans_matrix[ispec2,ispec1,iprod]=coeff_end1[ispec2]
		end
	end
end

##################################################
##Calculation of potential matrices in SPH basis##
##################################################
for ispec1=1:Nrot
	coeff_start2.=0.0
	coeff_start2[ispec1]=1.0	

	#################################################
	##Transformation from JKM basis to angular grid##
	#################################################

	coeff_grid2 = transformation_forward_SPH(coeff_start2,jmax,Nalpha,Nm)

	#######################################
	##Act with potential operator on grid##
	#######################################
	for iprod=1:Nprod
		for i=1:Ngrid2
			coeff_out2[i]=coeff_grid2[i]*Vrot[i,iprod]
		end
		#################################################
		##Transformation from angular grid to JMK basis##
		#################################################
		coeff_end2 .= transformation_backward_SPH(coeff_out2,jmax,Nalpha,Nm,Nrot)
		for ispec2=1:Nrot
			Vrot_matrix[ispec2,ispec1,iprod]=coeff_end2[ispec2]
		end
	end
end

return C,Vtrans_matrix,Vrot_matrix
end
####################################################################################################################
function transformation_forward_HO(coeff_in,nmax,NR,Ntheta,Nphi,nu,mass)
####################################################################################################################
##Function to perform a transformation from the NLM (isotropic 3D-HO eigenfunctions) basis to the R,theta,phi-grid##
####################################################################################################################

coeff_start = zeros(ComplexF64,(nmax+1,nmax+1,2*nmax+1))

ii=0
for n=0:nmax
for l=n:-2:0
for m=-l:l
	ii += 1
	coeff_start[n+1,l+1,nmax+1+m] = coeff_in[ii]
end
end
end


#Transform from the N basis to the R (Gauss-Laguerre) grid#
coeff_out = RN_transformation("forward",coeff_start,nmax+1,NR,nmax,nu,mass)

#Transform from the L basis to the theta (Gauss-Legendre) grid#
coeff_out2 = ThetaL_transformation("forward",coeff_out,nmax+1,Ntheta,nmax,NR)

#Transform from the M basis to the phi grid#
coeff=zeros(ComplexF64,Nphi)
coeff_grid=zeros(ComplexF64,(NR*Ntheta*Nphi))
tmp=zeros(ComplexF64,Nphi)

Pm=plan_ifft(tmp)
ig=1
for ir=1:NR
for it=1:Ntheta
        for m=1:2*nmax+1
		coeff[m]=coeff_out2[ir,it,m]
        end
	tmp=Pm*coeff
	for ip=1:Nphi
		coeff_grid[ig]=tmp[ip]
		ig+=1
	end
end
end

return coeff_grid 
end
###############################################################################################################
function transformation_backward_HO(coeff_grid,nmax,NR,Ntheta,Nphi,nu,mass,Nspec)
####################################################################################################################
##Function to perform a transformation from the R,theta,phi-grid to the NLM (isotropic 3D-HO eigenfunctions) basis##
####################################################################################################################

##Conversion from R,theta,phi indices to composite index##
coeff_start=zeros(ComplexF64,(NR,Ntheta,Nphi))

ii=0
for ir=1:NR
for it=1:Ntheta
for ip=1:Nphi
    ii+=1
    coeff_start[ir,it,ip]=coeff_grid[ii]
end
end
end

##Transform from phi grid to M basis##
coeff_tmp=zeros(ComplexF64,Nphi)
coeff_out=zeros(ComplexF64,(Ntheta,NR,2*nmax+1))
tmp=zeros(ComplexF64,Nphi)

Pm=plan_fft(coeff_tmp)
for ir=1:NR
for it=1:Ntheta
	for ip=1:Nphi
		tmp[ip]=coeff_start[ir,it,ip]
	end
        coeff_tmp=Pm*tmp
	for m=1:2*nmax+1
		coeff_out[it,ir,m]=coeff_tmp[m]
	end
end
end

#Transform from the theta (Gauss-Legendre) grid to the L basis#

coeff_out2 = ThetaL_transformation("backward",coeff_out,Ntheta,nmax+1,nmax,NR)

#Transform from the R (Gauss-Laguerre) grid to the N basis#
coeff_out3 = RN_transformation("backward",coeff_out2,NR,nmax+1,nmax,nu,mass)

coeff_out4 = zeros(ComplexF64,Nspec)
ii=0
for n=0:nmax
for l=n:-2:0
for m=-l:l
	ii += 1
	coeff_out4[ii] = coeff_out3[l+1,n+1,nmax+1+m]
end
end
end

return coeff_out4
end
###############################################################################################################
function transformation_forward_SPH(coeff_in,jmax,Ntheta,Nphi)
####################################################################################################################
##Function to perform a transformation from the JM (spherical harmonics) basis to the theta,phi-grid##
####################################################################################################################

coeff_start = zeros(ComplexF64,(jmax+1,2*jmax+1))

ii=0
for j=0:jmax
for m=-j:j
	ii += 1
	coeff_start[j+1,jmax+1+m] = coeff_in[ii]
end
end

#Transform from the J basis to the theta (Gauss-Legendre) grid#
Utrans = Utl(jmax,Ntheta)

#Transform between L- and theta-grid#
coeff2 = zeros(ComplexF64,(Ntheta,2*jmax+1))

for m=1:2*jmax+1
	tmp_R=BLAS.gemv('N', 1.0, Utrans[:,:,m], real(coeff_start[:,m]))
	tmp_I=BLAS.gemv('N', 1.0, Utrans[:,:,m], imag(coeff_start[:,m]))
	coeff2[:,m] = tmp_R+im*tmp_I
end

#Transform from the M basis to the phi grid#
coeff3=zeros(ComplexF64,Nphi)
coeff_grid=zeros(ComplexF64,(Ntheta*Nphi))
tmp=zeros(ComplexF64,Nphi)

Pm=plan_ifft(tmp)
ig=1
for it=1:Ntheta
        for m=1:2*jmax+1
		coeff3[m]=coeff2[it,m]
        end
	tmp=Pm*coeff3
	for ip=1:Nphi
		coeff_grid[ig]=tmp[ip]
		ig+=1
	end
end

return coeff_grid 
end
###############################################################################################################
function transformation_backward_SPH(coeff_grid,jmax,Ntheta,Nphi,Nspec)
####################################################################################################################
##Function to perform a transformation from the theta,phi-grid to the JM (spherical harmonics) basis##
####################################################################################################################

##Conversion from theta,phi indices to composite index##
coeff_start=zeros(ComplexF64,(Ntheta,Nphi))

ii=0
for it=1:Ntheta
for ip=1:Nphi
    ii+=1
    coeff_start[it,ip]=coeff_grid[ii]
end
end

##Transform from phi grid to M basis##
coeff_tmp=zeros(ComplexF64,Nphi)
coeff2=zeros(ComplexF64,(Ntheta,2*jmax+1))
tmp=zeros(ComplexF64,Nphi)

Pm=plan_fft(coeff_tmp)
for it=1:Ntheta
	for ip=1:Nphi
		tmp[ip]=coeff_start[it,ip]
	end
        coeff_tmp=Pm*tmp
	for m=1:2*jmax+1
		coeff2[it,m]=coeff_tmp[m]
	end
end


#Transform between J- and theta-grid#
Utrans = Utl(jmax,Ntheta)
coeff3 = zeros(ComplexF64,(jmax+1,2*jmax+1))

for m=1:2*jmax+1
	tmp_R=BLAS.gemv('T', 1.0, Utrans[:,:,m], real(coeff2[:,m]))
	tmp_I=BLAS.gemv('T', 1.0, Utrans[:,:,m], imag(coeff2[:,m]))
	coeff3[:,m] = tmp_R+im*tmp_I
end

coeff_out = zeros(ComplexF64,Nspec)
ii=0
for j=0:jmax
for m=-j:j
	ii += 1
	coeff_out[ii] = coeff3[j+1,jmax+1+m]
end
end

return coeff_out
end
###############################################################################################################
function RN_transformation(direction,coeff,N1,N2,nmax,nu,mass)

if direction == "forward"
        trans='N'
	Utrans = Urn(nu,nmax,N2)
elseif direction == "backward"
        trans='T'
	Utrans = Urn(nu,nmax,N1)
end

#Transform between R- and n-grid#
coeff2_R = zeros((N2,nmax+1,2*nmax+1))
coeff2_I = zeros((N2,nmax+1,2*nmax+1))
for l=0:nmax
for m=-l:l
	coeff2_R[:,l+1,nmax+1+m].=BLAS.gemv(trans, 1.0, Utrans[:,:,l+1], real(coeff[:,l+1,nmax+1+m]))
	coeff2_I[:,l+1,nmax+1+m].=BLAS.gemv(trans, 1.0, Utrans[:,:,l+1], imag(coeff[:,l+1,nmax+1+m]))
end
end

coeff_out = zeros(ComplexF64,(nmax+1,N2,2*nmax+1))
for n=1:N2
for l=0:nmax
for m=-l:l
	coeff_out[l+1,n,nmax+1+m] = coeff2_R[n,l+1,nmax+1+m] + im*coeff2_I[n,l+1,nmax+1+m]
end
end
end

return coeff_out
end
###############################################################################################################
function ThetaL_transformation(direction,coeff,N1,N2,nmax,NR)

if direction == "forward"
        trans='N'
	Utrans = Utl(nmax,N2)
elseif direction == "backward"
        trans='T'
	Utrans = Utl(nmax,N1)
end

#Transform between L- and theta-grid#
coeff2_R = zeros((N2,NR,2*nmax+1))
coeff2_I = zeros((N2,NR,2*nmax+1))

for ir=1:NR
for m=1:2*nmax+1
	coeff2_R[:,ir,m].=BLAS.gemv(trans, 1.0, Utrans[:,:,m], real(coeff[:,ir,m]))
	coeff2_I[:,ir,m].=BLAS.gemv(trans, 1.0, Utrans[:,:,m], imag(coeff[:,ir,m]))
end
end

coeff_out = zeros(ComplexF64,(NR,N2,2*nmax+1))
for ir=1:NR
for it=1:N2
for m=1:2*nmax+1
	coeff_out[ir,it,m] = coeff2_R[it,ir,m] + im*coeff2_I[it,ir,m]
end
end
end

return coeff_out
end
###############################################################################################################
function Urn(nu,nmax,NR)

Rgrid,weight = laguerre(NR,0.5)
Utrans = zeros((NR,nmax+1,nmax+1))

for n=0:nmax
	for l=n:-2:0
	k=Int((n-l)/2)
	prefactor = laguerre_normalization(k,l,nu)/(2.0*sqrt(nu*(2.0*nu)^(l+0.5)))
	for ir=1:NR
		lag = laguerrel(k,l+0.5,Rgrid[ir])
		Utrans[ir,n+1,l+1] = prefactor*sqrt(weight[ir]*Rgrid[ir]^l)*lag
	end
	end
end


return Utrans
end
###############################################################################################################
function Utl(nmax,Ntheta)

Utrans = zeros((Ntheta,nmax+1,2*nmax+1))

ctheta, ct_weight = legendre(Ntheta)

for l=0:nmax
	for m=-l:-1
		norm = legendre_normalization(l,m)
		for it=1:Ntheta
			Utrans[it,l+1,nmax+1+m] = (-1.0)^(abs(m))*(factorial(l-abs(m))/factorial(l+abs(m)))*Plm(l,abs(m),ctheta[it])*sqrt(ct_weight[it])*norm
		end
	end
	for m=0:l
		norm = legendre_normalization(l,m)
		for it=1:Ntheta
			Utrans[it,l+1,nmax+1+m] = Plm(l,m,ctheta[it])*sqrt(ct_weight[it])*norm
		end
	end


end

return Utrans
end
###############################################################################################################
function laguerre_normalization(k,l,nu)

norm = sqrt(sqrt((2*nu^3)/pi)*(2^(k+2*l+3)*factorial(k)*nu^(l)/dfactorial(2*k+2*l+1)))

return norm
end
###############################################################################################################
function legendre_normalization(l,m)

norm = sqrt(0.5*(2*l+1)*factorial(l-m)/factorial(l+m))
#norm = norm*(-1)^m	#Condon-Shortley phase factor not required, in the definition of Plm

return norm
end
###############################################################################################################
function dfactorial(n)

if mod(n,2) == 0
	Nfac = Int(n/2)
elseif mod(n,2) == 1
	Nfac = Int((n+1)/2)
end

fac = 1.0
for ii=0:Nfac-1
	fac*=(n-2*ii)
end

return fac
end
###############################################################################################################
function decomposition(matrix,error)

Ngrid1 = size(matrix,1)
Ngrid2 = size(matrix,2)

#Decompose potential by SVD#
F=svd(matrix)

#Determine the number of important singular values#
values=F.S/sum(F.S)

e=0.0
Nprod=0
while e <1.0-error
	Nprod+=1
	e=e+values[Nprod]
end
log_file=open("log","a")
println(log_file,"Number of products: ",Nprod)
println(log_file,"Chosen SV error: ",error)
println(log_file,"Sum of first Nprod SV: ",e)

#Determine the Frobenius norm of the difference between truncated SVD and initial potential#
mprod=zeros(ComplexF64,(Ngrid1,Ngrid2))
for i=1:Ngrid1
for j=1:Ngrid2
	prod=0.0
	for ip=1:Nprod
		prod=prod+F.U[i,ip]*F.S[ip]*F.Vt[ip,j]
	end
	mprod[i,j]=prod
end
end

diff=norm(abs.(mprod.-matrix), 2)
println(log_file,"Frobenius norm = ",diff)
println(log_file,"Fnorm divided by matrix size= ",diff/(Ngrid1*Ngrid2))
println(log_file)
close(log_file)

M1=zeros((Ngrid1,Nprod))
M2=zeros((Ngrid2,Nprod))
C=zeros(Nprod)	

for i=1:Ngrid1
	M1[i,1:Nprod].=F.U[i,1:Nprod]
end
for i=1:Ngrid2
	M2[i,1:Nprod].=F.Vt[1:Nprod,i]
end
C[:].=F.S[1:Nprod]

return C,M1,M2
end
###############################################################################################################
end
