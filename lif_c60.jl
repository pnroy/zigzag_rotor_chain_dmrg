module lif_c60

using LinearAlgebra

export lif_cage_potential

###########################################################################################
function lif_cage_potential(R,theta1,phi1,theta2,phi2,eq_struct)

#Conversion factor#
Ehtokcalmol=627.509474	#Hartree to kcal/mol
Ehtocm1=219474.631363	#Eh to cm-1
a0toangst=0.529177210903
#Lennard-Jones parameter#
DF=0.3289013752035508	#kcalmol-1
aF=1.1612049349771316	#1/A
reF=3.6626357486264682	#A
DLi=0.0024846628063929974
aLi=1.8493512340769664
reLi=4.0	
#Convert R from bohr to A#
R=R*a0toangst

#Read coordinates of cage atoms#
f = open("c60.txt") 
lines = readlines(f)
close(f)
lsplit = split(lines[1])
Ncage = parse(Int64, lsplit[1])

Catoms = zeros((Ncage,3))
for i=1:Ncage
	lsplit = split(lines[i+2])
 	Catoms[i,1] = parse(Float64,lsplit[2])
 	Catoms[i,2] = parse(Float64,lsplit[3])
 	Catoms[i,3] = parse(Float64,lsplit[4])
end
Catoms = Catoms

rF,rLi = get_cart_coord(R,theta1,phi1,theta2,phi2,eq_struct)

#f=open("bla.xyz","w")
#println(f,62)
#println(f)
#println(f,"Li  ",rLi[1]," ",rLi[2]," ",rLi[3])
#println(f,"F  ",rF[1]," ",rF[2]," ",rF[3])
#for ii=1:60
#	println(f,"C  ",Catoms[ii,1]," ",Catoms[ii,2]," ",Catoms[ii,3])
#end
#close(f)

V=0.0
for i=1:Ncage
	dist = sqrt((rF[1]-Catoms[i,1])^2+(rF[2]-Catoms[i,2])^2+(rF[3]-Catoms[i,3])^2)
	V += morse(dist,DF,aF,reF)
	dist = sqrt((rLi[1]-Catoms[i,1])^2+(rLi[2]-Catoms[i,2])^2+(rLi[3]-Catoms[i,3])^2)
	V += morse(dist,DLi,aLi,reLi)
end
V = V/Ehtokcalmol

return V
end
###########################################################################################
function get_cart_coord(R,theta1,phi1,theta2,phi2,eq_struct)

#Convert R distance to angstrom#
a0toangst=0.529177210903
rLiF=eq_struct[1]*a0toangst

mLi = 7.0160034366
mF = 18.99840316273

F_init=zeros(3)
Li_init=zeros(3)

F_init[3]=-(mLi/(mLi+mF))*rLiF
Li_init[3]=(mF/(mLi+mF))*rLiF


#Shift center-of mass to coordinate center#
COM=zeros(3)
for i=1:3
	COM[i]=(mF*F_init[i]+mLi*Li_init[i])/(mF+mLi)
	F_init[i]=F_init[i]-COM[i]
	Li_init[i]=Li_init[i]-COM[i]
end

rF=zeros(3)
rLi=zeros(3)

#Rotate molecule by Euler angles around COM#
Rot=rotation_matrix(theta2,phi2)

rF=BLAS.gemv('N' , 1.0, Rot, F_init)
rLi=BLAS.gemv('N' , 1.0, Rot, Li_init)

#Shift center of mass#
shift = zeros(3)
shift[1] = R*sin(theta1)*cos(phi1)
shift[2] = R*sin(theta1)*sin(phi1)
shift[3] = R*cos(theta1)

for i=1:3
	rF[i] = rF[i] + shift[i]
	rLi[i] = rLi[i] + shift[i]
end

return rF,rLi
end
###########################################################################################
function lennard_jones(R,epsilon,sigma)

q=sigma/R
V = 4*epsilon*(q^12-q^6)

return V
end
###########################################################################################
function morse(R,De,alpha,re)

return De*(1.0-exp(-alpha*(R-re)))^2-De
end
###########################################################################################
function rotation_matrix(theta,phi)

cp=cos(phi)
sp=sin(phi)
ct=cos(theta)
st=sin(theta)

rotmat=zeros(Float64,(3,3))

rotmat[1,1]=ct*cp
rotmat[1,2]=-sp
rotmat[1,3]=st*cp
rotmat[2,1]=ct*sp
rotmat[2,2]=cp
rotmat[2,3]=st*sp
rotmat[3,1]=-st
rotmat[3,2]=0
rotmat[3,3]=ct

return rotmat
end
###########################################################################################
end
