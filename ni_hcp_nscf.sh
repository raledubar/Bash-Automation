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
   calculation = 'nscf'
   title = 'nihcp'
   wf_collect = .true.
   outdir='/home/duarte/SCRATCH/nodo7/duarte_nodo7_14827/'
   prefix = 'nihcp_pw'
   pseudo_dir = '/home/duarte/pseudos-qe/GBRV1.2/'

/
&SYSTEM
    ibrav = 4
    a=
    c=
    nat =  2
    ntyp = 1
    nbnd= 27
    ecutwfc = 40
    ecutrho = 320
    occupations = 'tetrahedra'
    degauss = $dg
    smearing ='gauss'
    nspin=1
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
60 60 60 0  0  0

ATOMIC_SPECIES
Ni   58.69      Ni.pbe_v1.2.uspp.F.UPF

ATOMIC_POSITIONS crystal
Ni     0.333333333  0.666666667  0.25
Ni     0.666666667  0.333333333  0.75

END
}


for var in 1
do
        # Generando input file y enviandole estructural parameters:
        # SCF:
        input=$kp.nscf.in
        output=$kp.nscf.out

        create_input-scf $input

        # Corriendo calculos:
        $RUNPARA   pw.x -nimage 1 -npool $PRC < ${input} > ${output} &
        wait

done
####################################################################
# terminando mpich2 manualmente
/usr/local/bin/mpich2-intel/bin/mpdallexit
