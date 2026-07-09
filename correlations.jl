module correlations

using potential:transformation_forward_SPH,transformation_backward_SPH
using GaussQuadrature: legendre 
push!(LOAD_PATH,pwd())
using trans_real_complex

export Rot_elements 
##################################################################################################
function Rot_elements(jmax,Nalpha,Nm,Ntrans)

Nspec=0
for j=0:jmax
	Nspec+=(2*j+1)
end

Ngrid=Nalpha*Nm

ctheta, ct_weight = legendre(Nalpha)
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
	i+=1

	X_prefx[i] = cos(t)*cos(phi[ip])
	X_prefy[i] = -sin(phi[ip])	
	X_prefz[i] = sin(t)*cos(phi[ip])

	Y_prefx[i] = cos(t)*sin(phi[ip])
	Y_prefy[i] = cos(phi[ip])	
	Y_prefz[i] = sin(t)*sin(phi[ip])
	
	Z_prefx[i]=-sin(t)
	Z_prefy[i]=0
	Z_prefz[i]=ctheta[alpha]
	ct_abs[i]=abs(ctheta[alpha])
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
	coeff_grid=transformation_forward_SPH(coeff_start,jmax,Nalpha,Nm)

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
	
	coeff_end=transformation_backward_SPH(coeff_X_prefx,jmax,Nalpha,Nm,Nspec)
	X_prefx_op[:,ispec].=coeff_end[:]
	
	coeff_end=transformation_backward_SPH(coeff_X_prefy,jmax,Nalpha,Nm,Nspec)
	X_prefy_op[:,ispec].=coeff_end[:]

	coeff_end=transformation_backward_SPH(coeff_X_prefz,jmax,Nalpha,Nm,Nspec)
	X_prefz_op[:,ispec].=coeff_end[:]

	coeff_end=transformation_backward_SPH(coeff_Y_prefx,jmax,Nalpha,Nm,Nspec)
	Y_prefx_op[:,ispec].=coeff_end[:]

	coeff_end=transformation_backward_SPH(coeff_Y_prefy,jmax,Nalpha,Nm,Nspec)
	Y_prefy_op[:,ispec].=coeff_end[:]

	coeff_end=transformation_backward_SPH(coeff_Y_prefz,jmax,Nalpha,Nm,Nspec)
	Y_prefz_op[:,ispec].=coeff_end[:]

	coeff_end=transformation_backward_SPH(coeff_Z_prefx,jmax,Nalpha,Nm,Nspec)
	Z_prefx_op[:,ispec].=coeff_end[:]
	
	coeff_end=transformation_backward_SPH(coeff_Z_prefy,jmax,Nalpha,Nm,Nspec)
	Z_prefy_op[:,ispec].=coeff_end[:]
	
	coeff_end=transformation_backward_SPH(coeff_Z_prefz,jmax,Nalpha,Nm,Nspec)
	Z_prefz_op[:,ispec].=coeff_end[:]
	
	coeff_end=transformation_backward_SPH(coeff_grid_ctabs,jmax,Nalpha,Nm,Nspec)
	ctabs_op[:,ispec].=coeff_end[:]

end

#Transformation matrices to real rotational and translational basis#
Utrans_rot = trans_realSPH(jmax,Nspec,"rotation")

Xxtrans = transform_realbasis(Utrans_rot,X_prefx_op)
Xytrans = transform_realbasis(Utrans_rot,X_prefy_op)
Xztrans = transform_realbasis(Utrans_rot,X_prefz_op)
Yxtrans = transform_realbasis(Utrans_rot,Y_prefx_op)
Yytrans = transform_realbasis(Utrans_rot,Y_prefy_op)
Yztrans = transform_realbasis(Utrans_rot,Y_prefz_op)
Zxtrans = transform_realbasis(Utrans_rot,Z_prefx_op)
Zytrans = transform_realbasis(Utrans_rot,Z_prefy_op)
Zztrans = transform_realbasis(Utrans_rot,Z_prefz_op)
Ctabstrans = transform_realbasis(Utrans_rot,ctabs_op)

#Xxout = zeros(ComplexF64,(Ntrans*Nspec,Ntrans*Nspec))
#Xyout = zeros(ComplexF64,(Ntrans*Nspec,Ntrans*Nspec))
#Xzout = zeros(ComplexF64,(Ntrans*Nspec,Ntrans*Nspec))
#Yxout = zeros(ComplexF64,(Ntrans*Nspec,Ntrans*Nspec))
#Yyout = zeros(ComplexF64,(Ntrans*Nspec,Ntrans*Nspec))
#Yzout = zeros(ComplexF64,(Ntrans*Nspec,Ntrans*Nspec))
#Zxout = zeros(ComplexF64,(Ntrans*Nspec,Ntrans*Nspec))
#Zyout = zeros(ComplexF64,(Ntrans*Nspec,Ntrans*Nspec))
#Zzout = zeros(ComplexF64,(Ntrans*Nspec,Ntrans*Nspec))
#Ctabs = zeros(ComplexF64,(Ntrans*Nspec,Ntrans*Nspec))
#
#i1=0
#for it1=1:Ntrans
#for ir1=1:Nspec
#	i1+=1	
#	i2=0
#	for it2=1:Ntrans
#	for ir2=1:Nspec
#		i2+=1
#		if it1 == it2
#			Xxout[i1,i2] = Xxtrans[ir1,ir2]
#			Xyout[i1,i2] = Xytrans[ir1,ir2]
#			Xzout[i1,i2] = Xztrans[ir1,ir2]
#			Yxout[i1,i2] = Yxtrans[ir1,ir2]
#			Yyout[i1,i2] = Yytrans[ir1,ir2]
#			Yzout[i1,i2] = Yztrans[ir1,ir2]
#			Zxout[i1,i2] = Zxtrans[ir1,ir2]
#			Zyout[i1,i2] = Zytrans[ir1,ir2]
#			Zzout[i1,i2] = Zztrans[ir1,ir2]
#			Ctabs[i1,i2] = Ctabstrans[ir1,ir2]
#		end
#	end
#	end
#end
#end

#return Xxout,Xyout,Xzout,Yxout,Yyout,Yzout,Zxout,Zyout,Zzout,Ctabs
return Xxtrans,Xytrans,Xztrans,Yxtrans,Yytrans,Yztrans,Zxtrans,Zytrans,Zztrans,Ctabstrans
end
##################################################################################################
end 
