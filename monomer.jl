module monomer

using LinearAlgebra
using LinearMaps
using Arpack
push!(LOAD_PATH,pwd())
using kinetic
using potential
using trans_real_complex

export monomer_basis

####################################################################################################################
function Hv!(y::AbstractVector,x::AbstractVector)
#######################
#Matrix-vector product#
#######################
	k=0
	for it=1:Ntrans
	for ir=1:Nrot
		k+=1
		wf[ir,it]=x[k]
	end
	end

	#Kinetic energy#
	one=1.0
	for i=1:Nrot
		Mv1[i,:] = BLAS.symv('U',one, Ttrans_real,wf[i,:])
	end
	for i=1:Ntrans
		Mv2[:,i]= BLAS.symv('U',one, Trot_spin,wf[:,i])
	end

	#Rotation-Translation potential#
	Mv3 .= 0.0
	for ip=1:Nprod
		for i=1:Nrot
			Vv[i,:]= BLAS.symv('U',one, Vtrans[:,:,ip],wf[i,:])
		end
		for i=1:Ntrans
			 tmp = BLAS.symv('U',Cpot[ip], Vrot[:,:,ip],Vv[:,i])
			 Mv3[:,i] .+= tmp
		end
	end

	k=0
	for it=1:Ntrans
	for ir=1:Nrot
		k+=1
		y[k]=Mv1[ir,it] + Mv2[ir,it] + Mv3[ir,it] 
	end
	end

	return y
end

####################################################################################################################
function monomer_basis(Nstates,jmax,Nalpha,Nm,B0,nmax,NR,Ntheta,Nphi,omega,mass,eq_struct,svd_err)

#Conversion factors#
a0toangst=0.529177210903 #Bohr to angstrom
eHtocm1=219474.631363	#Eh to cm-1
utome=1.0/(5.48579909065*1e-4)

#Check if Nm and Nk are odd#
if mod(Nm,2) == 0
	println("Even number of phi points (Euler angle)")
	exit()
elseif mod(Nphi,2) == 0
	println("Even number of phi points (3D-HO)")
	exit()
end

#Check if Nm/Nk is at least 2*mmax+1/2*kmax+1#
if Nm < 2*jmax+1
	println("Nphi must be at least 2*mmax+1 (Euler angles)")
	exit()
end

#Check if phi-grid is equal or larger than the spectral m-basis#
if Nphi < 2*nmax+1
	println("Increase Nphi, too small for chosen basis (3D-HO)")
	println("Try Nphi >= ", 2*nmax+1)
	exit()
end

#Basis size of the 3D-HO eigenbasis#
global Ntrans=0
for n=0:nmax
	global Ntrans += Int(((n+1)*(n+2))/2)
end
#Basis size of the Wigner basis#
global Nrot=0
for j=0:jmax
	global Nrot=Nrot+(2*j+1)
end

#Calculate kinetic matrices for translational and rotational DOF#
Ttrans = kinetic_translation(nmax,omega,mass)
Trot = kinetic_rotation(jmax,B0)


##Transform kinetic matrix to real basis##
#Rotations#
Utrans_rot = trans_realSPH(jmax,Nrot,"rotation")
global Trot_spin = transform_realbasis(Utrans_rot,Trot)

#Translations#
Utrans_trans = trans_realSPH(nmax,Ntrans,"translation")
global Ttrans_real = transform_realbasis(Utrans_trans,Ttrans)

f=open("log","a")
println(f,"#######################################")
println(f,"###########Basis information###########")
println(f,"#######################################")
println(f,"#Rotation#")
println(f,"jmax= ",jmax)
println(f,"Ntheta= ",Nalpha,", Nphi= ",Nm)
println(f,"Dimension of local Hilbert space: ",Nrot)
println(f,"#Translation#")
println(f,"nmax= ",nmax,", lmax= ",nmax,", mmax= ",nmax)
println(f,"NR= ",NR,", Ntheta= ",Ntheta,", Nphi= ",Nphi)
println(f,"mass= ",mass/utome," omega= ",omega)
println(f,"Dimension of local Hilbert space: ",Ntrans)
println(f,"#######################################")
println(f,"#####Rotational constant in cm^-1#####")
println(f,"#######################################")
println(f,"B0= ",B0*eHtocm1)
println(f,"#######################################")
println(f)
println(f,"Calculate cage potential matrix")
close(f)

#Calculate cage potential in product basis#
C,Vtrans_matrix,Vrot_matrix = potential_matrix(nmax,NR,Ntheta,Nphi,jmax,Nalpha,Nm,omega,mass,Ntrans,Nrot,eq_struct,svd_err)
#C,Vtrans_matrix,Vrot_matrix = hf_c60_matrix(nmax,jmax,omega,mass,Ntrans,Nrot)

global Cpot = C

global Nprod=size(Vtrans_matrix,3)
f=open("log","a")
println(f,"Cage potential matrix done")
close(f)

#Transform cage potential to real 3D-HO basis#
global Vtrans = zeros((Ntrans,Ntrans,Nprod))
global Vrot = zeros((Nrot,Nrot,Nprod))

for ip=1:Nprod
	#Transform 3D-HO to real basis#
	global Vtrans[:,:,ip] .= transform_realbasis(Utrans_trans,Vtrans_matrix[:,:,ip])

	#Transform complex Wigner basis to real rotational eigenbasis#
	global Vrot[:,:,ip] .= transform_realbasis(Utrans_rot,Vrot_matrix[:,:,ip])
end

f=open("energies_mono.txt","w")
println(f,"nmax= ",nmax," NR= ",NR," Ntheta= ",Ntheta," Nphi= ",Nphi)
println(f,"jmax= ",jmax," Nalpha= ",Nalpha," Nphi= ",Nm)
println(f,"Ntrans= ",Ntrans)
println(f,"Nrot= ",Nrot)
println(f)
close(f)

global wf = zeros(Float64,(Nrot,Ntrans))
global Mv1 = zeros(Float64,(Nrot,Ntrans))
global Mv2 = zeros(Float64,(Nrot,Ntrans))
global Mv3 = zeros(Float64,(Nrot,Ntrans))
global Vv = zeros(Float64,(Nrot,Ntrans))

f=open("log","a")
println(f,"Start diagonalization")

D = LinearMap{Float64}(Hv!,Ntrans*Nrot,issymmetric=true,ismutating=true)
values,evecs = Arpack.eigs(D,nev=Nstates,which=:SR)

println(f,"Write eigenvalues")
close(f)

f2=open("energies_mono.txt","a")
for istates=1:Nstates
	println(f2,round(real(values[istates])*eHtocm1,digits=5)," ",round(real(values[istates]-values[1])*eHtocm1,digits=5))
end
close(f2)

f=open("log","a")
println(f,"Monomer states calculated.")
close(f)

return values,evecs,Ntrans,Nrot
end
###########################################################################################################################################################
end
