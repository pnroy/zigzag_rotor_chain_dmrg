module hf_potential

using AssociatedLegendrePolynomials
using WignerSymbols

export enHFC60

#############################################################################
function enHFC60(R,alpha,beta,theta,phi)

a0toangst=0.529177210903 #Bohr to angstrom
eHtokcalmol = 627.5094740631	#Eh to kcal/mol
n=12
p1=zeros(Int64,n)
p2=zeros(Int64,n)
p=zeros(Int64,n)
mp=zeros(Int64,n)
x=zeros(Float64,n)

R*=a0toangst

R2=R*R
R3=R2*R
R4=R2*R2
p1[1]=0   
p1[2]=0   
p1[3]=0   
p1[4]=0   
p1[5]=1   
p1[6]=1   
p1[7]=1   
p1[8]=1   
p1[9]=2   
p1[10]=2  
p1[11]=2  
p1[12]=2  

p2[1]=0   
p2[2]=6   
p2[3]=6   
p2[4]=6   
p2[5]=1   
p2[6]=5   
p2[7]=5   
p2[8]=5   
p2[9]=2   
p2[10]=4  
p2[11]=4  
p2[12]=4  

p[1]=0    
p[2]=6    
p[3]=6    
p[4]=6    
p[5]=0    
p[6]=6    
p[7]=6    
p[8]=6    
p[9]=0    
p[10]=6   
p[11]=6   
p[12]=6   

mp[1]=0   
mp[2]=0   
mp[3]=5   
mp[4]=-5  
mp[5]=0   
mp[6]=0   
mp[7]=5   
mp[8]=-5  
mp[9]=0   
mp[10]=0  
mp[11]=5  
mp[12]=-5 


x[1]=  5.825731*R4 + 3.505364*R2 - 6.8715990   
x[2]=  (2.927476e-3)*R4+(1.101096e-4)*R2 + 9.487742e-4 
x[3]=-sqrt(7.0/11.0)*x[2]
x[4]= sqrt(7.0/11.0)*x[2]


x[5]=  (3.229325e-1)*R3-(1.619958e-1)*R 
x[6]=  (-1.172073e-2)*R3-(2.621524e-3)*R
x[7]=-sqrt(7.0/11.0)*x[6]         
x[8]= sqrt(7.0/11.0)*x[6]         


x[9]= (8.895730e-2)*R4+(1.076448e-2)*R2 
x[10]= (-6.372600e-3)*R4+(5.922033e-3)*R2
x[11]=-sqrt(7.0/11.0)*x[10]        
x[12]= sqrt(7.0/11.0)*x[10]        

EHFC60 = 0.0
for i = 1:n
	L = p1[i]
	J = p2[i]
	LL =p[i]

	t=0.0
	r=mp[i]
	for r1=-L:L
	for r2=-J:J
	
	if abs(L-J) > LL || LL > (J+L) || (r1+r2-r) != 0  
	t+=0.0
	else
	t+=2.0*wigner3j(L,J,LL,r1,r2,-r)*normPlm(L,r1,cos(alpha))*normPlm(J,r2,cos(theta))*cos(r1*beta+r2*phi)*((-1)^(L-J+r))*sqrt((2.0*LL+1.0)*(2.0*L+1.0)*(2.0*J+1.0))
	end
	
	end
	end
        EHFC60+=x[i]*t

end


return EHFC60/eHtokcalmol#*kcal2cm
end

###########################################################################
function normPlm(l,m,u)

nrm = sqrt((2*l+1)*factorial(l-m)/(2.0*factorial(l+m)))
if m < 0
        Y = (-1.0)^(abs(m))*(factorial(l-abs(m))/factorial(l+abs(m)))*Plm(l,abs(m),u)
elseif m >= 0
        Y = Plm(l,m,u)
end

return Y*nrm
end
###########################################################################
end
