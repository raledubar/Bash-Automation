#!/bin/bash
########################################################
# iniciando mpich2 manualmente

/usr/local/bin/mpich2-intel/bin/mpdboot
PRC=4
RUNPARA=$(echo "/usr/local/bin/mpich2-intel/bin/mpiexec -n $PRC ")

#########################################################
# funcion para crear el archivo de entrada

function create_input-scf
{
cat > $1 << END
&CONTROL
   calculation = 'scf'
   title = 'nihcp'
   wf_collect = .false.
   outdir='/home/duarte/SCRATCH/nodo7/duarte_nodo7_14827/'
   prefix = 'nihcp_pw'
   pseudo_dir = '/home/duarte/pseudos-qe/GBRV1.2/'

/
&SYSTEM
    ibrav = 4
    a=2.4118
    c=3.9556
    nat =  2
    ntyp = 1
    nbnd= 27
    ecutwfc = 40
    ecutrho = 320
    occupations = 'smearing'
    degauss = 0.015
    smearing ='gauss'
    nspin=2
    tot_magnetization=$var
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


for var in 0.00 0.10 0.20 0.30 0.40 0.50 0.60 0.70 0.80 0.90 1.00 1.10 1.20 1.30 1.40 1.50 1.60 1.70 1.80 1.90 2.00 2.10 2.20 2.30 2.40 2.50 2.60 2.70 2.80 2.90 3.00
do
        # Generando input file y enviandole estructural parameters:
        # SCF:
        input=${var}.in
        output=${var}.out

        create_input-scf $input

        # Corriendo calculos:
        $RUNPARA   pw.x -nimage 1 -npool $PRC < ${input} > ${output} &
        wait

done
####################################################################
# terminando mpich2 manualmente
/usr/local/bin/mpich2-intel/bin/mpdallexit
