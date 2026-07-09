module dd_interaction

using LinearAlgebra
using WignerSymbols
using GaussQuadrature: laguerre,legendre 
push!(LOAD_PATH, @__DIR__)
using potential
using trans_real_complex

export Vdd 
###############################################################
function Vdd(jmax,nmax,NR,Ntheta,Nphi,R0,R1,R2,mu0,nu,mass,Ntrans,Nrot,Ustates,svd_err)

#Transformation matrcies to real rotational and translational basis#
Utrans_rot = trans_realSPH(jmax,Nrot,"rotation")
Utrans_trans = trans_realSPH(nmax,Ntrans,"translation")
##########################
#Define integration grids#
##########################

Ngrid_trans = NR*Ntheta*Nphi

R,Rweight = laguerre(NR,0.5)
ct1, cw1 = legendre(Ntheta)

theta_trans = acos.(ct1)

phi_trans=zeros(Nphi)
for i=1:Nphi
	phi_trans[i]=(i-1)*2.0*pi/Nphi
end

#################################
#Calculate dipole terms on grids#
#################################
xTxT = zeros(Ngrid_trans,Ngrid_trans)
xTyT = zeros(Ngrid_trans,Ngrid_trans)
xTzT = zeros(Ngrid_trans,Ngrid_trans)
yTyT = zeros(Ngrid_trans,Ngrid_trans)
yTzT = zeros(Ngrid_trans,Ngrid_trans)
zTzT = zeros(Ngrid_trans,Ngrid_trans)

i1=0
for ir1=1:NR
	RA = sqrt(0.5*R[ir1]/nu)
for it1=1:Ntheta
	thetaA=theta_trans[it1]
for ip1=1:Nphi
	phiA=phi_trans[ip1]
	i1+=1
	i2=0
	xA = RA*sin(thetaA)*cos(phiA)+R1[1]
	yA = RA*sin(thetaA)*sin(phiA)+R1[2]
	zA = RA*cos(thetaA)+R1[3]
	for ir2=1:NR
		RB = sqrt(0.5*R[ir2]/nu)
	for it2=1:Ntheta
		thetaB=theta_trans[it2]
	for ip2=1:Nphi
		phiB=phi_trans[ip2]
		i2+=1
		xB = RB*sin(thetaB)*cos(phiB)+R2[1]
		yB = RB*sin(thetaB)*sin(phiB)+R2[2]
		zB = RB*cos(thetaB)+R2[3]

		Rdimer = sqrt((xB-xA)^2+(yB-yA)^2+(zB-zA)^2)
		x=(xB-xA)/Rdimer
		y=(yB-yA)/Rdimer
		z=(zB-zA)/Rdimer
		xTxT[i1,i2] = (1.0-3*x*x)/(Rdimer^3)	
		xTyT[i1,i2] = x*y/(Rdimer^3)	
		xTzT[i1,i2] = x*z/(Rdimer^3)	
		yTyT[i1,i2] = (1.0-3*y*y)/(Rdimer^3)	
		yTzT[i1,i2] = y*z/(Rdimer^3)	
		zTzT[i1,i2] = (1.0-3*z*z)/(Rdimer^3)	
	end
	end
	end

end
end
end

########################################################
###Calculate matrix representation of rotational terms##
########################################################
Y01 = zeros(Float64,(Nrot,Nrot))
Y11 = zeros(Float64,(Nrot,Nrot))
Ym11 = zeros(Float64,(Nrot,Nrot))

i1=0
for j1=0:jmax
for m1=-j1:j1
	i2=0	
	i1+=1
	for j2=0:jmax
	for m2=-j2:j2
		i2+=1
		wk=wigner3j(BigFloat,j1,1,j2,0,0,0)
		N=sqrt((2*j1+1)*(2*j2+1)*3/(4*pi))*(-1)^m1
		Y01[i1,i2] = N*wk*wigner3j(BigFloat,j1,1,j2,-m1,0,m2)
		Y11[i1,i2] = N*wk*wigner3j(BigFloat,j1,1,j2,-m1,1,m2)
		Ym11[i1,i2] = N*wk*wigner3j(BigFloat,j1,1,j2,-m1,-1,m2)
	end
	end
end
end

Xmat = (Ym11-Y11)*sqrt(2.0*pi/3.0)
Ymat = (Ym11+Y11)*sqrt(2.0*pi/3.0)*im
Zmat = Y01*2*sqrt(pi/3)

Xmatrix = transform_realbasis(Utrans_rot,Xmat.+0im)
Ymatrix = transform_realbasis(Utrans_rot,Ymat)
Zmatrix = transform_realbasis(Utrans_rot,Zmat.+0im)

#Change order of Utrans to monomer basis#
Nstates = size(Ustates,2)
U = zeros(Float64,(Nrot,Ntrans,Nstates))
for istates=1:Nstates
	i=0
	for it=1:Ntrans
	for ir=1:Nrot 
		i+=1
		U[ir,it,istates] =  Ustates[i,istates]
	end
	end
end

#U*R*U#
Mx = zeros(Float64,(Ntrans,Ntrans,Nstates,Nstates))
My = zeros(Float64,(Ntrans,Ntrans,Nstates,Nstates))
Mz = zeros(Float64,(Ntrans,Ntrans,Nstates,Nstates))

for ip1=1:Nstates
for ip2=1:Nstates
	tmp = BLAS.gemm('C','N',U[:,:,ip1],Xmatrix)
	Mx[:,:,ip1,ip2] .= BLAS.gemm('N','N',tmp,U[:,:,ip2])
	tmp = BLAS.gemm('C','N',U[:,:,ip1],Ymatrix)
	My[:,:,ip1,ip2] .= BLAS.gemm('N','N',tmp,U[:,:,ip2])
	tmp = BLAS.gemm('C','N',U[:,:,ip1],Zmatrix)
	Mz[:,:,ip1,ip2] .= BLAS.gemm('N','N',tmp,U[:,:,ip2])
end
end

coeff = []
VA = []
VB = []
coeff = []

f=open("log","a")
println(f,"#Decompose translational parts of dipole-dipole interaction#")
println(f)

#xAxB*(1-3xTxT)/R3#
println(f,"#(1-3xTxT)/R3#")
close(f)
C,T1,T2 = integrate_translation(xTxT,svd_err,Ntrans,nmax,NR,Ntheta,Nphi,nu,mass,Utrans_trans)
V1,V2 = helper(Mx,Mx,T1,T2,Nstates)
push!(coeff,C)
push!(VA,V1)
push!(VB,V2)

#yAyB*(1-3yTyT)/R3#
f=open("log","a")
println(f,"#(1-3yTyT)/R3#")
close(f)
C,T1,T2 = integrate_translation(yTyT,svd_err,Ntrans,nmax,NR,Ntheta,Nphi,nu,mass,Utrans_trans)
V1,V2 = helper(My,My,T1,T2,Nstates)
push!(coeff,C)
push!(VA,V1)
push!(VB,V2)

#zAzB*(1-3zTzT)/R3#
f=open("log","a")
println(f,"#(1-3zTzT)/R3#")
close(f)
C,T1,T2 = integrate_translation(zTzT,svd_err,Ntrans,nmax,NR,Ntheta,Nphi,nu,mass,Utrans_trans)
V1,V2 = helper(Mz,Mz,T1,T2,Nstates)
push!(coeff,C)
push!(VA,V1)
push!(VB,V2)

##xAyB*xTyT/R3 and yAxB*xTyT/R3#
f=open("log","a")
println(f,"#xTyT/R3#")
close(f)
C,T1,T2 = integrate_translation(xTyT,svd_err,Ntrans,nmax,NR,Ntheta,Nphi,nu,mass,Utrans_trans)
V1,V2 = helper(Mx,My,T1,T2,Nstates)
push!(coeff,C)
push!(VA,V1)
push!(VB,V2)
V1,V2 = helper(My,Mx,T1,T2,Nstates)
push!(coeff,C)
push!(VA,V1)
push!(VB,V2)

##xAzB*xTzT/R3 and zAxB*xTzT/R3#
f=open("log","a")
println(f,"#xTzT/R3#")
close(f)
C,T1,T2 = integrate_translation(xTzT,svd_err,Ntrans,nmax,NR,Ntheta,Nphi,nu,mass,Utrans_trans)
V1,V2 = helper(Mx,Mz,T1,T2,Nstates)
push!(coeff,C)
push!(VA,V1)
push!(VB,V2)
V1,V2 = helper(Mz,Mx,T1,T2,Nstates)
push!(coeff,C)
push!(VA,V1)
push!(VB,V2)

##yAzB*yTzT/R3 and zAyB*yTzT/R3#
f=open("log","a")
println(f,"#yTzT/R3#")
close(f)
C,T1,T2 = integrate_translation(yTzT,svd_err,Ntrans,nmax,NR,Ntheta,Nphi,nu,mass,Utrans_trans)
V1,V2 = helper(My,Mz,T1,T2,Nstates)
push!(coeff,C)
push!(VA,V1)
push!(VB,V2)
V1,V2 = helper(Mz,My,T1,T2,Nstates)
push!(coeff,C)
push!(VA,V1)
push!(VB,V2)

return coeff,VA,VB
end
###############################################################
function integrate_translation(Mtrans,svd_err,Ntrans,nmax,NR,Ntheta,Nphi,nu,mass,Utrans)

Ngrid = size(Mtrans,1)

##########################################################
##Decompose translationl terms in A-and B-dependent part##
##########################################################
C,T1,T2 = decomposition(Mtrans,svd_err)
Nprod = length(C)

#########################################################
##Calculation of potential matrices in iso. 3D-HO basis##
#########################################################
coeff_start = zeros(ComplexF64,Ntrans)
coeff_grid = zeros(ComplexF64,Ngrid)
coeff_out1 = zeros(ComplexF64,Ngrid)
coeff_out2 = zeros(ComplexF64,Ngrid)
Tm1 = zeros(ComplexF64,(Ntrans,Ntrans,Nprod))
Tm2 = zeros(ComplexF64,(Ntrans,Ntrans,Nprod))

for ispec1=1:Ntrans
	coeff_start.=0.0
	coeff_start[ispec1]=1.0	

	###################################################
	##Transformation from NLM basis to spherical grid##
	###################################################

	coeff_grid = transformation_forward_HO(coeff_start,nmax,NR,Ntheta,Nphi,nu,mass)

	#######################################
	##Act with potential operator on grid##
	#######################################
	for iprod=1:Nprod
		for i=1:Ngrid
			coeff_out1[i]=coeff_grid[i]*T1[i,iprod]
			coeff_out2[i]=coeff_grid[i]*T2[i,iprod]
		end
		###################################################
		##Transformation from spherical grid to NLM basis##
		###################################################
		coeff_end1 = transformation_backward_HO(coeff_out1,nmax,NR,Ntheta,Nphi,nu,mass,Ntrans)
		coeff_end2 = transformation_backward_HO(coeff_out2,nmax,NR,Ntheta,Nphi,nu,mass,Ntrans)
		for ispec2=1:Ntrans
			Tm1[ispec2,ispec1,iprod]=coeff_end1[ispec2]
			Tm2[ispec2,ispec1,iprod]=coeff_end2[ispec2]
		end
	end
end

#Transformation to real basis#
T1 = zeros(Float64,(Ntrans,Ntrans,Nprod))
T2 = zeros(Float64,(Ntrans,Ntrans,Nprod))
for ip=1:Nprod	
	T1[:,:,ip] .= transform_realbasis(Utrans,Tm1[:,:,ip])
	T2[:,:,ip] .= transform_realbasis(Utrans,Tm2[:,:,ip])
end

return C,T1,T2#Tm1,Tm2
end
###############################################################
function helper(MAA,MBB,Tm1,Tm2,Nstates)

Nprod = size(Tm1,3)
Ntrans = size(Tm1,1)

#VA = zeros(ComplexF64,(Nstates,Nstates,Nprod))
#VB = zeros(ComplexF64,(Nstates,Nstates,Nprod))
VA = zeros(Float64,(Nstates,Nstates,Nprod))
VB = zeros(Float64,(Nstates,Nstates,Nprod))

for ip2=1:Nstates
for ip1=1:Nstates
	for iprod=1:Nprod
		#VA[ip1,ip2,iprod]= dot(MAA[:,:,ip1,ip2],Tm1[:,:,iprod])
		#VB[ip1,ip2,iprod]= dot(MBB[:,:,ip1,ip2],Tm2[:,:,iprod])
		dumA=0.0
		dumB=0.0
		for it2=1:Ntrans
		for it1=1:Ntrans
			dumA+=MAA[it1,it2,ip1,ip2]*Tm1[it1,it2,iprod]
			dumB+=MBB[it1,it2,ip1,ip2]*Tm2[it1,it2,iprod]
		end
		end
		VA[ip1,ip2,iprod] = dumA
		VB[ip1,ip2,iprod] = dumB
	end
end
end

return VA,VB
end
###############################################################
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


###############################################################
end
