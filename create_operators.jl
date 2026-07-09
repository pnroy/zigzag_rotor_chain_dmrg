module create_operators
##################################################################################
##This module creates an operator file containing terms of the product potential##
##as well as the kinetic energy operator					##
##################################################################################

export operators

###########################################################################################
function operators(Nspec,Nprod_up,Nprod_down,Nprod_nnn,Nrad,Nangle,Nangle_phi,interaction)

f=open("operators.jl","w")

#Define the Hilbert space#
println(f,"ITensors.space(::SiteType\"AsymTop\") = ", Nspec)
println(f)

#Define string building blocks#
string1="function ITensors.op!(Op::ITensor,::OpName"
string2=",::SiteType\"AsymTop\" ,s::Index)"
string3=""#complex!(Op)"
string4="for i=1:Nstates"
string5="for j=1:Nstates"
string6="	Op[s'=>j,s=>i] = V"
string7="	Op[s'=>j,s=>i] = W"
string8="end"
string9="#######################################################################"

#Write the kinetic energy operator#
println(f,string9)
println(f,string1,"\"T\"",string2)
println(f)
println(f,string3)
println(f,string4)
println(f,string5)
println(f,"	Op[s'=>j,s=>i] = T[j,i]")
println(f,string8)
println(f,string8)
println(f)
println(f,string8)
println(f,string9)
println(f)

#Write x operator#
println(f,string9)
println(f,string1,"\"MuX\"",string2)
println(f)
println(f,string3)
println(f,string4)
println(f,string5)
name_Cop=string("     Op[s'=>j,s=>i] = MuX[j,i]")
println(f,name_Cop)
println(f,string8)
println(f,string8)
println(f)
println(f,string8)
println(f,string9)
println(f)

#Write y operator#
println(f,string9)
println(f,string1,"\"MuY\"",string2)
println(f)
println(f,string3)
println(f,string4)
println(f,string5)
name_Cop=string("     Op[s'=>j,s=>i] = MuY[j,i]")
println(f,name_Cop)
println(f,string8)
println(f,string8)
println(f)
println(f,string8)
println(f,string9)
println(f)

#Write z operator#
println(f,string9)
println(f,string1,"\"MuZ\"",string2)
println(f)
println(f,string3)
println(f,string4)
println(f,string5)
name_Cop=string("     Op[s'=>j,s=>i] = MuZ[j,i]")
println(f,name_Cop)
println(f,string8)
println(f,string8)
println(f)
println(f,string8)
println(f,string9)
println(f)

#Write |z| operator#
println(f,string9)
println(f,string1,"\"MuZabs\"",string2)
println(f)
println(f,string3)
println(f,string4)
println(f,string5)
name_Cop=string("     Op[s'=>j,s=>i] = MuZabs[j,i]")
println(f,name_Cop)
println(f,string8)
println(f,string8)
println(f)
println(f,string8)
println(f,string9)
println(f)


#Center-of mass coordinates#
#Write x operator#
println(f,string9)
println(f,string1,"\"XCOM\"",string2)
println(f)
println(f,string3)
println(f,string4)
println(f,string5)
name_Cop=string("     Op[s'=>j,s=>i] = Xop[j,i]")
println(f,name_Cop)
println(f,string8)
println(f,string8)
println(f)
println(f,string8)
println(f,string9)
println(f)

#Write y operator#
println(f,string9)
println(f,string1,"\"YCOM\"",string2)
println(f)
println(f,string3)
println(f,string4)
println(f,string5)
name_Cop=string("     Op[s'=>j,s=>i] = Yop[j,i]")
println(f,name_Cop)
println(f,string8)
println(f,string8)
println(f)
println(f,string8)
println(f,string9)
println(f)

#Write z operator#
println(f,string9)
println(f,string1,"\"ZCOM\"",string2)
println(f)
println(f,string3)
println(f,string4)
println(f,string5)
name_Cop=string("     Op[s'=>j,s=>i] = Zop[j,i]")
println(f,name_Cop)
println(f,string8)
println(f,string8)
println(f)
println(f,string8)
println(f,string9)
println(f)

#################
##Distributions##
#################
#Radial distribution#
for ir=1:Nrad
	name_PR=string("\"PR_",ir,"\" ")
	println(f,string9)
	println(f,string1,name_PR,string2)
	println(f)
	println(f,string3)
	println(f,string4)
	println(f,string5)
	name_Cop=string("     Op[s'=>j,s=>i] = PR[j,i,",ir,"]")
	println(f,name_Cop)
	println(f,string8)
	println(f,string8)
	println(f)
	println(f,string8)
	println(f,string9)
	println(f)
end
#Cos(theta) distribution#
for it=1:Nangle
	name_PT=string("\"PT_",it,"\" ")
	println(f,string9)
	println(f,string1,name_PT,string2)
	println(f)
	println(f,string3)
	println(f,string4)
	println(f,string5)
	name_Cop=string("     Op[s'=>j,s=>i] = Ptheta[j,i,",it,"]")
	println(f,name_Cop)
	println(f,string8)
	println(f,string8)
	println(f)
	println(f,string8)
	println(f,string9)
	println(f)
end
#Phi distribution#
for it=1:Nangle_phi
        name_PP=string("\"PP_",it,"\" ")
        println(f,string9)
        println(f,string1,name_PP,string2)
        println(f)
        println(f,string3)
        println(f,string4)
        println(f,string5)
        name_Cop=string("     Op[s'=>j,s=>i] = Pphi[j,i,",it,"]")
        println(f,name_Cop)
        println(f,string8)
        println(f,string8)
        println(f)
        println(f,string8)
        println(f,string9)
        println(f)
end


#Write the potential operators#
for iterm=1:9
        #Upward operators#
	for lambda=1:Nprod_up[iterm]
		#Write operator on site 1#
		name_V=string("\"V",iterm,"_",lambda,"\" ")
		println(f,string1,name_V,string2)
		println(f)  
		println(f,string3)
		println(f,string4)
		println(f,string5)
		println(f,string6,iterm,"_up[j,i,",lambda,"]")
		println(f,string8)
		println(f,string8)
		println(f)
		println(f,string8)
		println(f,string9)
		println(f)
	
		#Write operator on site 2#
		name_V=string("\"W",iterm,"_",lambda,"\" ")
		println(f,string1,name_V,string2)
		println(f)  
		println(f,string3)
		println(f,string4)
		println(f,string5)
		println(f,string7,iterm,"_up[j,i,",lambda,"]")
		println(f,string8)
		println(f,string8)
		println(f)
		println(f,string8)
		println(f,string9)
		println(f)
	end
        #Downward operators#
        for lambda=1:Nprod_down[iterm]
                #Write operator on site 1#
                name_V=string("\"A",iterm,"_",lambda,"\" ")
                println(f,string1,name_V,string2)
                println(f)
                println(f,string3)
                println(f,string4)
                println(f,string5)
                println(f,string6,iterm,"_down[j,i,",lambda,"]")
                println(f,string8)
                println(f,string8)
                println(f)
                println(f,string8)
                println(f,string9)
                println(f)

                #Write operator on site 2#
                name_V=string("\"B",iterm,"_",lambda,"\" ")
                println(f,string1,name_V,string2)
                println(f)
                println(f,string3)
                println(f,string4)
                println(f,string5)
                println(f,string7,iterm,"_down[j,i,",lambda,"]")
                println(f,string8)
                println(f,string8)
                println(f)
                println(f,string8)
                println(f,string9)
                println(f)
        end
        if interaction == "next"
                #Next-nearest neighbour operators#
                for lambda=1:Nprod_nnn[iterm]
                        #Write operator on site 1#
                        name_V=string("\"C",iterm,"_",lambda,"\" ")
                        println(f,string1,name_V,string2)
                        println(f)
                        println(f,string3)
                        println(f,string4)
                        println(f,string5)
                        println(f,string6,iterm,"_nnn[j,i,",lambda,"]")
                        println(f,string8)
                        println(f,string8)
                        println(f)
                        println(f,string8)
                        println(f,string9)
                        println(f)

                        #Write operator on site 2#
                        name_V=string("\"D",iterm,"_",lambda,"\" ")
                        println(f,string1,name_V,string2)
                        println(f)
                        println(f,string3)
                        println(f,string4)
                        println(f,string5)
                        println(f,string7,iterm,"_nnn[j,i,",lambda,"]")
                        println(f,string8)
                        println(f,string8)
                        println(f)
                        println(f,string8)
                        println(f,string9)
                        println(f)
                end
        end
end
close(f)
end
######################################################################################
end
