#!/bin/bash
#------------------------------------------------   CLUSTER   ------------------------------------------------
########################################################
# Variables sobre el compilador y paralelizacion
#
# Nodos esclavos 
#@S  nodo7:4  nodo4:4  
#
# To copy a scratch
#@CF 
#
# A Master
#@MCF 
#
# To run on pwd (1) o en ~/SCRATCH/nodo...
#@EXL= 1
# 
# Nombre de la carpeta \$LOCALSCRATCH (default: user_nodo_id)
#@LSC 
#
# Nodo del cual traer la carpets scrtach
# Default: primera en la lista @S
# @ B K S nodo4
#
# Archivos a traer desde la carpeta LSC en BKS
# @ F 2 B 
#
rundir=${LOCALSCRATCH}
# Corriendo el qe
#function run_pw.x
#function run_pw.x
#{
function run_pw.x
{
$RUNPARA   pw.x -nimage 1 -npool $PRC -ntg 1 < ${input} > ${output} &
wait
}

#------------------------------------------------   CLUSTER    ------------------------------------------------
#------------------------------------------------   INPUTS    ------------------------------------------------
########################################################
#
# Parametros para la optimizacion. Definicion de variable dependiente e independiente
# en la funcion que crea los inputs.

a=2.48 # poner aqui el a optimo de mis calculos
coa=1.64
#vol=20.00

# Definiendo el pivote para la variable independiente
#vol=$(echo "$coa $a"|awk '{printf "%.9f", sqrt(3)*0.5*$2*$2*$2*$1 }')
#pivote=$( echo "${vol}" | awk '{printf "%.2f", $1}' )
pivote=$( echo "$a" | awk '{printf "%.2f", $1}' )

# Rango a variar eps para la variable independiente: ind=pivote*eps
#epsrange=( 0.92 0.94 0.96 ...  )
epsrange=( $(seq 0.95 0.01 1.05 )  )

# Parametros para la optimizacion con pasos descendentes:
# Valor inicial de la variable a optimizar (dependiente): (2 DECIMALES !!!!!!!!!!!!)
varini=$(echo "$coa" |awk '{printf "%.2f", $1 }')

unset a coa c vol #liberar variables

# Rango para las deltas de la variable a optimizar: var=varini+delta
delta=( 0.10 0.04 0.02 )

# Despues de obtener un minimos estimado con pasos descendientes, se hace un barrido al
# rededor de dicho minimo: barrido=minimos*eps2fit   (2 DECIMALES !!!!!!!!!!!!)
#eps2fit=( $( seq 0.95 0.01 1.05 ) )
delta2fit=( $( seq -0.10 0.02 0.10 ))


# Archivos con datos calculados
fitvar=fitvar.dat
allvar=allvar.dat
logfile=${PWD}/var-opt.log

# Variable de seguridad por si no se alcanza un minimo
reachmax=13

######################################################## 
# Funcion para crear el archivo de entrada

function create_input-scf
{
#ind: variable independiente
#var: variable dependiente

a=$ind
#vol=$ind
coa=$var

#a=$(echo "${vol}   ${coa}"|awk '{printf "%.9f", (2*$1/(sqrt(3)*$2))^(1/3) }' )
c=$(echo "$coa  $a"|awk '{printf "%.9f", $1*$2}')
#vol=$(echo "$coa $a"|awk '{printf "%.9f", sqrt(3)*0.5*$2*$2*$2*$1 }')

echo "     a=$a   c=$c   c/a=$coa " >> $logfile

label=nihcp

cat > $1 << END
&CONTROL
   calculation = 'scf'
   title = '${label}'
   wf_collect = .false.
   outdir='${rundir}'
   prefix = '${label}_pw'
   pseudo_dir = '${HOME}/pseudos-qe/GBRV1.2/'

/
&SYSTEM
    ibrav = 4
    a=$a
    c=$c
    nbnd=27
    nat =  2
    ntyp = 1
    ecutwfc = 40
    ecutrho = 320
    occupations = 'smearing'
    degauss = 0.015
    smearing ='gauss'
    nspin=2
    starting_magnetization(1)=0.50
/
&ELECTRONS
   electron_maxstep = 100
   conv_thr = 1.0D-10
   mixing_mode = 'TF'
   mixing_beta = 0.60D0
   diagonalization = 'david'
   diago_david_ndim = 4
   startingpot = 'atomic'
   startingwfc = 'atomic+random'
/

K_POINTS automatic
30 30 12 0  0  0

ATOMIC_SPECIES
Ni   58.69      Ni.pbe_v1.2.uspp.F.UPF

ATOMIC_POSITIONS crystal
Ni     0.333333333  0.666666667  0.25
Ni     0.666666667  0.333333333  0.75


END
}

#------------------------------------------------   INPUTS    ------------------------------------------------

#------------------------------------------------- FUNCIONES  -------------------------------------------------

#   #   #   #   #   #   #   #   #   #   #   #   #   #   #   #   #   #   #   #   #   #   #   #   #
#               Funciones para la optimizacion con pasos descendentes                           #
#   #   #   #   #   #   #   #   #   #   #   #   #   #   #   #   #   #   #   #   #   #   #   #   #

#-->-->-->-->-->-->-->-->-->-->-->-->-->-->-->-->-->-->-->-->-->-->-->-->-->
# Llamado a calcular energia con qe

function compute-f
{
# Valor a calcular: $1

# Archivo donde buscar si ya se ha calculado el x dado
file2check=$2

# Archivo donde enviar lo calculado
file2send=$3

# Revisando si este var ya se calculo
if(( $(cat $file2check |awk '{print $1}'|grep "${1}" -c) == 0 ))
then 
        echo "    No calculado"   >> $logfile
        echo "    Calculando . . ."  >> $logfile

        #/////////////////////////////////  DFT-CODE \\\\\\\\\\\
        input=${name}.scf.in
        output=$(echo $input |sed s/".in"/".out"/ )

        create_input-scf  ${input}
        run_pw.x  ${input}  &
        wait

        #Borrando rundir/*
        rm -rf ${rundir}/*

        eng=$(grep "\!" ${output} | awk '{printf "%.8f", $(NF-1)*1.00}')

        #/////////////////////////////////  DFT-CODE \\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\

        # Si eng!=0, si hay valor para $eng, se almacena en $varfile,
        # de otra forma, no se envia nada a $varfile y se brinca
        # al siguiente eps
        if (( eng == 0 ))
        then
                # No se encontro valor para $eng
                echo "|/-|/-|/-|/-|/-|/-|/-|/-|   CALCULO NO CONVERGIDO   |/-|/-|/-|/-|/-|/-|/-|/-|"   >> $logfile
                else
                        # Si se encontro valor para $eng
                        echo "   $1  $eng " >> $file2send
                fi

        else 
                nlinevar=$(cat $file2check |awk '{print $1}'|grep "${1}" -n | awk -F: '{print $1}')
                eng=$(sed -n ${nlinevar}p $file2check |awk '{print $2}')

                echo "    $1 ya calculado  : $nlinevar" >> $logfile

                 if [ "${file2check}" != "${file2send}" ];
                then
                        echo "   $1  $eng " >> $file2send
                fi


                unset nlinevar
        fi

}

#--<--<--<--<--<--<--<--<--<--<--<--<--<--<--<--<--<--<--<--<--<--<--<--<--<

#--_--_--_--_--_--_--_--_--_--_--_--_--_--_--_--_--_--_--_--_--_--_--_--_--_

#Funcion que calcula el signo de la pendiente
#
# m=(y2-y1)/(x2-x1)
#
# Uso:
# m-sign x2 y2  x1 y1 = 1 o -1

function m-sign
{
        echo "scale=15; m=( $2 -1*$4 )/( $1 -1*$3 ); if (m < 0 ) aa=-1; if(m > 0) aa=1 ; aa "|bc -l
}

#__-__-__-__-__-__-__-__-__-__-__-__-__-__-__-__-__-__-__-__-__-__-__-__-__-

#-->-->-->-->-->-->-->-->-->-->-->-->-->-->-->-->-->-->-->-->-->-->-->-->-->
# Funcion principal de pasos descendentes

function step-desc
{
 #Iniciando contador del numero de deltas usadas
 ndelta=0
 
 #Contado de seguridad
 reach=0 

 ############################################################
 # Calculos necesarios para iniciar el ciclo

        echo "Iniciando optmizacion por pasos descendentes . . ." >> $logfile
        echo "**** delta = ${delta[0]}" >> $logfile

        ###################################################
        # 1er calculo
        echo "**** Primer calculo . . ." >> $logfile

        # Buscando archivo ../min-estimado.dat
        if [ -s ../min-estimado.dat ]
        then
                # ../min-estimado.dat existe y no esta vacio"
                # Leyendo $varini del ultimo dato del archivo ../min-estimado.dat
                # si este existe
                var=$( sed -n \$p ../min-estimado.dat | awk '{print $2 }')
                echo "**** Usando el minimo estimado anterior para  \$var ..." >> $logfile
        else
                var=$varini
        fi

        echo "**** variable = $var "     >> $logfile

        name=var_$var
        compute-f $var $allvar $allvar


        ###################################################
        # 2o calculo

        echo "**** Segundo calculo  . . ." >> $logfile

        #Guardadando calculos de paso previo:
        prevar=$var
        preeng=$eng

        # 1: avanzo en c/a ;  -1: retrocedo
        test=1

        # Actualizando valor de var:
        var=$(echo "${prevar}+${test}*${delta[0]}"|bc -l|awk '{printf "%.2f", $1}')

        echo "**** variable = $var "     >> $logfile

        name=var_$var
        compute-f $var $allvar $allvar

        # Calculando signo de la pendiente

        x2=$var
        y2=$eng

        x1=$prevar
        y1=$preeng

        sign2=$( m-sign $x2 $y2 $x1 $y1 )

        echo "    (x1,y1)=(${x1},${y1})   (x2,y2)=(${x2},${y2})   signo de la pendiente:$sign2  "  >> $logfile

        # NOTA:
        # Si el sign2 > 0, entonces nos moveriamos en direccion opuesta!!

 ############################################################


 # Ciclo:
 while (( ndelta <  ${#delta[@]} ))
 do

  echo "**** delta = ${delta[ndelta]}" >> $logfile


   #Guardadando calculos de paso previo:
   prevar=$var
   preeng=$eng
   sign1=$sign2

   # Actualizando valor de var:
   var=$(echo "${var}-1*${sign1}*${delta[ndelta]}"|bc -l|awk '{printf "%.2f", $1}')

   echo "**** variable = $var "     >> $logfile

   name=var_$var
   compute-f $var $allvar $allvar

   # Calculando signo de la pendiente

   x2=$var
   y2=$eng

   x1=$prevar
   y1=$preeng

   sign2=$( m-sign $x2 $y2 $x1 $y1 )

   echo "    (x1,y1)=(${x1},${y1})   (x2,y2)=(${x2},${y2})   signo de la pendiente:$sign2  "  >> $logfile

   # Revisando cambio  de signo
   if (( sign1 != sign2 ))
   then
        echo "    Cambio en signo de pendiente encontrado . . ."  >> $logfile

        # Actualizando contador del numero de deltas
        let ndelta=ndelta+1

        # Reiniciando numero de veces con el mismo signo de pendiente
        let reach=0
   else
        echo "    Mismo signo en la pendiente . . ."  >> $logfile

        # Checando el numero de veces con el mismo signo de pendiente
        let reach=reach+1

        if (( reach == reachmax ))
        then
                ndelta=${#delta[@]}+10
                echo "    Maximo numero de iteraciones con el mismo signo de la pendiente alcanzado !!!! " >> $logfile
        fi

   fi

 done

}

#--<--<--<--<--<--<--<--<--<--<--<--<--<--<--<--<--<--<--<--<--<--<--<--<--<

#   #   #   #   #   #   #   #   #   #   #   #   #   #   #   #   #   #   #   #   #   #   #   #   #
#               Funciones para la optimizacion con pasos descendentes                           #
#   #   #   #   #   #   #   #   #   #   #   #   #   #   #   #   #   #   #   #   #   #   #   #   #

#------------------------------------------------- FUNCIONES  -------------------------------------------------

#------------------------------------------------    RUTINA    ------------------------------------------------

#####################################################################################
#

echo -e "\n
* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *  \n
                Optimizacion por pasos descendentes en $asymbol " >> $logfile

for eps in ${epsrange[*]} 
do

 ################################################################################################
 # Valor de variable independiente:
 ind=$(echo "${eps}*${pivote}"|bc -l| awk '{printf "%f", $0}')

 echo "*      *      *      Ciclo para eps=${eps}       *      *      *"  >> $logfile

 ################################################################################################
 # Buscando o creando directorio eps_$eps
 if [ -d eps_$eps ]
 then
        echo "Directorio eps_$eps existe."
        echo "Entrando al directorio eps_$eps"
        cd eps_$eps
 else
        echo "Creando carpeta eps_$eps . . ."
        mkdir eps_$eps
        echo "Entrando al directorio eps_$eps"
        cd eps_$eps
 fi   >> $logfile

 # Revisando o creando archivo $allvar
 if [ -a $allvar ]
 then
        echo "Archivo $allvar existe. Filtrando . . ."
        cat $allvar | awk 'NF==2{print}{}'|sort -n |uniq > filtrado.prov
        mv $allvar previo-$allvar
        mv filtrado.prov $allvar
        echo "Archivo ${allvar}, listo."
        echo "Eliminados los casos eps=( $(cat previo-${allvar}| awk 'NF==1{print}{}'|paste -s) )"
 else
        echo "Creando archivo ${allvar}."
        touch $allvar
 fi  >> $logfile

 #  * # * # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
 # Corriendo la optimizacion por pasos descendentes. . . 
 
 step-desc
 
 # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # 
 
 # Buscando el minimo
 varmin=$( sort -k 2 -n $allvar |sed -n 1p | awk '{print $1 }')
 echo "**** Minimo estimado: $varmin "  >> $logfile
 echo "$eps  $varmin" >> ../min-estimado.dat

 rm -rf $fitvar

 # Ultimo barrido alrededor del minimo estimado
 #for lasteps in ${eps2fit[*]}
 for lasteps in ${delta2fit[*]}
 do
        # Calculando var: 2 DECIMALES !!!
        var=$(echo "${varmin}  ${lasteps}"|awk '{printf "%.2f", $1+$2}')

        echo "---> var=$var "   >> $logfile

        name=var_$var
        compute-f $var $allvar $fitvar

 done

 # Enviando fitvar a allvar
 cat $fitvar >> $allvar

 # Ajustando un polinomio y minimizando:
 echo "  " >> $logfile
 echo "Estimando el minimo con un ajuste polinomial . . . " >> $logfile
 fitpol-a.sh $fitvar 5 >> $logfile

 echo "$eps  $ind  $(sed -n \$p pol5.out )"  >>  ../evol-ind.dat

 echo "X      X      X      Ciclo para eps=${eps}      X      X      X"  >> $logfile
 cd ..

done

################################################################################

#------------------------------------------------    RUTINA    ------------------------------------------------

