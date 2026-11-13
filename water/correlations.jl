module correlations
__precompile__(false)   # local modules share names across run folders: never use the shared depot cache

using potential:transformation_forward_Wigner,transformation_backward_Wigner
using GaussQuadrature: legendre 
push!(LOAD_PATH, @__DIR__)
using trans_real_complex
using spin

export Relements 
##################################################################################################
function Relements(isomer,jmax,Nalpha,Nm,Nk,Utrans)

Nspec=0
for j=0:jmax
	Nspec+=(2*j+1)^2
end

mmax=jmax
kmax=jmax

Ngrid=Nalpha*Nm*Nk

ctheta, ct_weight = legendre(Nalpha)
chi=zeros(Nk)
for i=1:Nk
	chi[i]=(i-1)*2.0*pi/Nk
end
phi=zeros(Nm)
for i=1:Nm
	phi[i]=(i-1)*2.0*pi/Nm
end

ct_abs=zeros(Ngrid)

X_prefx = zeros(Ngrid)
X_prefy = zeros(Ngrid)
X_prefz = zeros(Ngrid)
Y_prefx = zeros(Ngrid)
Y_prefy = zeros(Ngrid)
Y_prefz = zeros(Ngrid)
Z_prefx = zeros(Ngrid)
Z_prefy = zeros(Ngrid)
Z_prefz = zeros(Ngrid)


i=0
for alpha=1:Nalpha
t=acos(ctheta[alpha])
for ip=1:Nm
for ic=1:Nk
	i+=1

	X_prefx[i] = cos(t)*cos(phi[ip])*cos(chi[ic])-sin(phi[ip])*sin(chi[ic])
	X_prefy[i] = -(cos(t)*cos(phi[ip])*sin(chi[ic])+sin(phi[ip])*cos(chi[ic]))	
	X_prefz[i] = sin(t)*cos(phi[ip])

	Y_prefx[i] = cos(t)*sin(phi[ip])*cos(chi[ic])+cos(phi[ip])*sin(chi[ic])
	Y_prefy[i] = -cos(t)*sin(phi[ip])*sin(chi[ic])+cos(phi[ip])*cos(chi[ic])	
	Y_prefz[i] = sin(t)*sin(phi[ip])
	
	Z_prefx[i]=-sin(t)*cos(chi[ic])
	Z_prefy[i]=sin(t)*sin(chi[ic])
	Z_prefz[i]=ctheta[alpha]
	ct_abs[i]=abs(ctheta[alpha])
end
end
end

coeff_start=zeros(ComplexF64,Nspec)
coeff_grid_stck=zeros(ComplexF64,Ngrid)
coeff_grid_stsk=zeros(ComplexF64,Ngrid)
coeff_grid_ct=zeros(ComplexF64,Ngrid)
coeff_grid_ctabs=zeros(ComplexF64,Ngrid)
coeff_end=zeros(ComplexF64,Nspec)

coeff_X_prefx=zeros(ComplexF64,Ngrid)
coeff_X_prefy=zeros(ComplexF64,Ngrid)
coeff_X_prefz=zeros(ComplexF64,Ngrid)

coeff_Y_prefx=zeros(ComplexF64,Ngrid)
coeff_Y_prefy=zeros(ComplexF64,Ngrid)
coeff_Y_prefz=zeros(ComplexF64,Ngrid)

coeff_Z_prefx=zeros(ComplexF64,Ngrid)
coeff_Z_prefy=zeros(ComplexF64,Ngrid)
coeff_Z_prefz=zeros(ComplexF64,Ngrid)


ctabs_op=zeros(ComplexF64,(Nspec,Nspec))

X_prefx_op = zeros(ComplexF64,(Nspec,Nspec))
X_prefy_op = zeros(ComplexF64,(Nspec,Nspec))
X_prefz_op = zeros(ComplexF64,(Nspec,Nspec))
Y_prefx_op = zeros(ComplexF64,(Nspec,Nspec))
Y_prefy_op = zeros(ComplexF64,(Nspec,Nspec))
Y_prefz_op = zeros(ComplexF64,(Nspec,Nspec))
Z_prefx_op = zeros(ComplexF64,(Nspec,Nspec))
Z_prefy_op = zeros(ComplexF64,(Nspec,Nspec))
Z_prefz_op = zeros(ComplexF64,(Nspec,Nspec))


for ispec=1:Nspec
	coeff_start.=0.0	
	coeff_start[ispec]=1.0

	#################################################
	##Transformation from JMK basis to angular grid##
	#################################################
	coeff_grid=transformation_forward_Wigner(coeff_start,jmax,mmax,kmax,Nalpha,Nm,Nk)

	##############################
	##Act with potential on grid##
	##############################

	for i=1:Ngrid
		coeff_grid_ctabs[i]=coeff_grid[i]*ct_abs[i]
	
		coeff_X_prefx[i] = coeff_grid[i]*X_prefx[i]		
		coeff_X_prefy[i] = coeff_grid[i]*X_prefy[i]		
		coeff_X_prefz[i] = coeff_grid[i]*X_prefz[i]		
		coeff_Y_prefx[i] = coeff_grid[i]*Y_prefx[i]		
		coeff_Y_prefy[i] = coeff_grid[i]*Y_prefy[i]		
		coeff_Y_prefz[i] = coeff_grid[i]*Y_prefz[i]		
		coeff_Z_prefx[i] = coeff_grid[i]*Z_prefx[i]		
		coeff_Z_prefy[i] = coeff_grid[i]*Z_prefy[i]		
		coeff_Z_prefz[i] = coeff_grid[i]*Z_prefz[i]		
	end
	
	#################################################
	##Transformation from angular grid to JMK basis##
	#################################################
	
	coeff_end=transformation_backward_Wigner(coeff_X_prefx,jmax,mmax,kmax,Nalpha,Nm,Nk,Nspec)
	X_prefx_op[:,ispec].=coeff_end[:]
	
	coeff_end=transformation_backward_Wigner(coeff_X_prefy,jmax,mmax,kmax,Nalpha,Nm,Nk,Nspec)
	X_prefy_op[:,ispec].=coeff_end[:]

	coeff_end=transformation_backward_Wigner(coeff_X_prefz,jmax,mmax,kmax,Nalpha,Nm,Nk,Nspec)
	X_prefz_op[:,ispec].=coeff_end[:]

	coeff_end=transformation_backward_Wigner(coeff_Y_prefx,jmax,mmax,kmax,Nalpha,Nm,Nk,Nspec)
	Y_prefx_op[:,ispec].=coeff_end[:]

	coeff_end=transformation_backward_Wigner(coeff_Y_prefy,jmax,mmax,kmax,Nalpha,Nm,Nk,Nspec)
	Y_prefy_op[:,ispec].=coeff_end[:]

	coeff_end=transformation_backward_Wigner(coeff_Y_prefz,jmax,mmax,kmax,Nalpha,Nm,Nk,Nspec)
	Y_prefz_op[:,ispec].=coeff_end[:]

	coeff_end=transformation_backward_Wigner(coeff_Z_prefx,jmax,mmax,kmax,Nalpha,Nm,Nk,Nspec)
	Z_prefx_op[:,ispec].=coeff_end[:]
	
	coeff_end=transformation_backward_Wigner(coeff_Z_prefy,jmax,mmax,kmax,Nalpha,Nm,Nk,Nspec)
	Z_prefy_op[:,ispec].=coeff_end[:]
	
	coeff_end=transformation_backward_Wigner(coeff_Z_prefz,jmax,mmax,kmax,Nalpha,Nm,Nk,Nspec)
	Z_prefz_op[:,ispec].=coeff_end[:]
	
	coeff_end=transformation_backward_Wigner(coeff_grid_ctabs,jmax,mmax,kmax,Nalpha,Nm,Nk,Nspec)
	ctabs_op[:,ispec].=coeff_end[:]

end

Xx = spin_isomer(isomer,jmax,X_prefx_op)
Xy = spin_isomer(isomer,jmax,X_prefy_op)
Xz = spin_isomer(isomer,jmax,X_prefz_op)
Yx = spin_isomer(isomer,jmax,Y_prefx_op)
Yy = spin_isomer(isomer,jmax,Y_prefy_op)
Yz = spin_isomer(isomer,jmax,Y_prefz_op)
Zx = spin_isomer(isomer,jmax,Z_prefx_op)
Zy = spin_isomer(isomer,jmax,Z_prefy_op)
Zz = spin_isomer(isomer,jmax,Z_prefz_op)
ctabs_op2 = spin_isomer(isomer,jmax,ctabs_op)

Xxtrans = transform_realbasis(Utrans,Xx)
Xytrans = transform_realbasis(Utrans,Xy)
Xztrans = transform_realbasis(Utrans,Xz)
Yxtrans = transform_realbasis(Utrans,Yx)
Yytrans = transform_realbasis(Utrans,Yy)
Yztrans = transform_realbasis(Utrans,Yz)
Zxtrans = transform_realbasis(Utrans,Zx)
Zytrans = transform_realbasis(Utrans,Zy)
Zztrans = transform_realbasis(Utrans,Zz)
Ctabstrans = transform_realbasis(Utrans,ctabs_op2)

return Xxtrans,Xytrans,Xztrans,Yxtrans,Yytrans,Yztrans,Zxtrans,Zytrans,Zztrans,Ctabstrans
end
##################################################################################################
end 
