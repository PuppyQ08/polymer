SUBROUTINE SELF_CONSISTENT_FIELD(LOEP,LSLATER,LKLI,LAC)
! PERFORM HARTREE-FOCK OR KOHN-SHAM SELF-CONSISTENT-FIELD ITERATION.

   USE MPI
   USE CONTROL
   USE STRUCTURE
   USE GRADIENT
   USE INTEGRAL
   USE BASISSET
   USE DFT
   USE OEP
   
   IMPLICIT NONE
   LOGICAL :: LOEP,LSLATER,LKLI,LAC
   INTEGER :: ISCF,IDIIS
   DOUBLE PRECISION :: ICPUS,ICPUE
   DOUBLE PRECISION :: ASYMMETRY,DENSITYCHANGE,OLDENERGY
   DOUBLE PRECISION :: DUMMY(1)

   OLDENERGY=0.0D0
   IF (MYID == 0) WRITE(6,'(A)') 'SELF-CONSISTENT FIELD ITERATION'
   IF (IOPTN(9) <= 1) THEN
    IF (DOPTN(108) == 0.0D0) THEN
     IF (MYID == 0) WRITE(6,'(A)') '-------------------------------------------------------------------------------'
     IF (MYID == 0) WRITE(6,'(A)') 'ITR DIIS ASSYMETRY  DENSITY CHANGE      TOTAL ENERGY   ENERGY CHANGE  CPU / SEC'
    ELSE
     IF (MYID == 0) WRITE(6,'(A)') &
     '-----------------------------------------------------------------------------------------------'
     IF (MYID == 0) WRITE(6,'(A)') &
     'ITR DIIS ASSYMETRY  DENSITY CHANGE      TOTAL ENERGY   ENERGY CHANGE    FERMI ENERGY  CPU / SEC'
    ENDIF
   ENDIF
   ISCF=1
   DO
    CALL PCPU_TIME(ICPUS)
    IF ((LDFT.AND.(.NOT.LGC)).OR.LSLATER.OR.LKLI.OR.(LOEP.AND.(IOPTN(71) >= 3)).OR.(LDFT.AND.LAC)) CALL LOCAL_EXCHANGE_CORRELATION
    IF (LDFT.AND.LGC) CALL GC_EXCHANGE_CORRELATION
    IF (LOPTN(25)) THEN
     CALL ROTATE_DENSITYMATRIX
     CALL FOURINDEX_ERI
    ELSE
     CALL ROTATE_DENSITYMATRIX
     CALL RESTORE_FOURINDEX_ERI
    ENDIF
    IF (LDFT.AND.LAC) THEN
!    CALL ASYMPTOTIC_CORRECTION
     IF (.NOT.LGC) CALL LOCAL_EXCHANGE_CORRELATION
     IF (LGC) CALL GC_EXCHANGE_CORRELATION
    ENDIF
!   IF (LOEP) CALL OPTIMIZED_EFFECTIVE_POTENTIAL(ISCF,1,DUMMY)
    CALL FOCK_BUILD(ASYMMETRY,LOEP,LSLATER,LKLI)
    CALL STORE_DENSITYMATRIX(ISCF,DENSITYCHANGE)
!   IF ((ISCF /= 1).AND.(DENSITYCHANGE < 1.0D-8)) THEN
!    CALL RELAX_DENSITYMATRIX(1.0D0)
!    IDIIS=0
!   ELSE IF ((IOPTN(16) /= 0).AND.(ISCF >= IOPTN(16)).AND.(MOD(ISCF-IOPTN(16),2) == 0)) THEN
    IF ((IOPTN(16) /= 0).AND.(ISCF >= IOPTN(16)).AND.(MOD(ISCF-IOPTN(16),2) == 0)) THEN
     CALL DIIS(ISCF,MIN(8,ISCF))
     IDIIS=MIN(8,ISCF)
    ELSE
     CALL RELAX_DENSITYMATRIX(DOPTN(15))
     IDIIS=0
    ENDIF
    CALL DECONTRACT_DENSITYMATRIX
    IF (LDFT.OR.LSLATER.OR.LKLI) THEN
     CALL ELECTRON_DENSITY
     D1F1=0.0D0
     XCF=0.0D0
     IF (LGC) THEN
      CALL ELECTRON_DENSITY_GRADIENT
      D1F2=0.0D0
     ENDIF
     IF (DOPTN(20) /= 0.0D0) CALL SLATER_EXCHANGE(0)
     IF (DOPTN(21) /= 0.0D0) CALL VOSKO_WILK_NUSAIR_CORRELATION(0)
     IF (DOPTN(22) /= 0.0D0) CALL BECKE88_EXCHANGE(0)
     IF (DOPTN(23) /= 0.0D0) CALL LEE_YANG_PARR_CORRELATION(0)
!    IF (LSLATER) CALL SLATER51_EXCHANGE
!    IF (LKLI) CALL KLI_EXCHANGE
    ENDIF
    CALL ENERGY_CALC(.FALSE.,LOEP,LSLATER,LKLI)
    CALL PCPU_TIME(ICPUE)
    IF (IOPTN(9) > 1) THEN
     IF (DOPTN(108) == 0.0D0) THEN
      IF (MYID == 0) WRITE(6,'(A)') '-------------------------------------------------------------------------------'
      IF (MYID == 0) WRITE(6,'(A)') 'ITR DIIS ASSYMETRY  DENSITY CHANGE      TOTAL ENERGY   ENERGY CHANGE  CPU / SEC'
     ELSE
      IF (MYID == 0) WRITE(6,'(A)') &
      '-----------------------------------------------------------------------------------------------'
      IF (MYID == 0) WRITE(6,'(A)') &
      'ITR DIIS ASSYMETRY  DENSITY CHANGE      TOTAL ENERGY   ENERGY CHANGE    FERMI ENERGY  CPU / SEC'
     ENDIF
    ENDIF
    IF (ISCF > 1) THEN
     IF (DOPTN(108) == 0.0D0) THEN
      IF (MYID == 0) WRITE(6,'(I3,1X,I3,2X,E9.3,1X,F15.12,1X,F17.10,1X,F15.10,1X,F10.1)') &
      ISCF,IDIIS,ASYMMETRY,DENSITYCHANGE,EHFKS,EHFKS-OLDENERGY,ICPUE-ICPUS
     ELSE
      IF (MYID == 0) WRITE(6,'(I3,1X,I3,2X,E9.3,1X,F15.12,1X,F17.10,1X,F15.10,1X,F15.10,1X,F10.1)') &
      ISCF,IDIIS,ASYMMETRY,DENSITYCHANGE,EHFKS,EHFKS-OLDENERGY,FERMI,ICPUE-ICPUS
     ENDIF
    ELSE
     IF (DOPTN(108) == 0.0D0) THEN
      IF (MYID == 0) WRITE(6,'(I3,1X,I3,2X,E9.3,1X,F15.12,1X,F17.10,3X,A13,1X,F10.1)') &
      ISCF,IDIIS,ASYMMETRY,DENSITYCHANGE,EHFKS,'-------------',ICPUE-ICPUS
     ELSE
      IF (MYID == 0) WRITE(6,'(I3,1X,I3,2X,E9.3,1X,F15.12,1X,F17.10,3X,A13,1X,F15.10,1X,F10.1)') &
      ISCF,IDIIS,ASYMMETRY,DENSITYCHANGE,EHFKS,'-------------',FERMI,ICPUE-ICPUS
     ENDIF
    ENDIF
    IF (IOPTN(9) > 1) THEN
     IF (DOPTN(108) == 0.0D0) THEN
      IF (MYID == 0) WRITE(6,'(A)') '-------------------------------------------------------------------------------'
     ELSE
      IF (MYID == 0) WRITE(6,'(A)') &
      '-----------------------------------------------------------------------------------------------'
     ENDIF
    ENDIF
    CALL PFLUSH(6)
    IF (DENSITYCHANGE < DOPTN(14)) THEN
     EXIT
    ELSE IF (ISCF == IOPTN(13)) THEN
     CALL PABORT('SCF CONVERGENCE NOT MET')
    ELSE
     OLDENERGY=EHFKS
     ISCF=ISCF+1
     CYCLE
    ENDIF
   ENDDO
   
   IF (IOPTN(9) <= 1) THEN
    IF (DOPTN(108) == 0.0D0) THEN
     IF (MYID == 0) WRITE(6,'(A)') '-------------------------------------------------------------------------------'
    ELSE
     IF (MYID == 0) WRITE(6,'(A)') &
     '-----------------------------------------------------------------------------------------------'
    ENDIF
   ENDIF
   IF (MYID == 0) WRITE(6,'(A)') 'SCF CONVERGED'
   IF (LDFT.AND.(IOPTN(74) == 0).AND.(IOPTN(75) == 0)) CALL INTEGRATE_ELECTRON_DENSITY
   CALL ENERGY_CALC(.TRUE.,LOEP,LSLATER,LKLI)
   IF (LOEP.AND.(MYID == 0)) WRITE(6,'(A,F20.15)') 'SHIFT FOR THE OEP ONE-ELECTRON ENERGIES  = ',OEPSHIFT
   IF (IOPTN(9) == 3) CALL DUMP15(P_C,NCGS,CEL1X,CEL1Y,CEL1Z,78)
!  IF (((.NOT.LOPTN(46)).AND.(.NOT.LOPTN(72)).AND.(.NOT.LOPTN(73))).OR. &
!  (LOPTN(46).AND.LOEP).OR.(LOPTN(72).AND.LSLATER).OR.(LOPTN(73).AND.LKLI)) THEN
!   IF (IOPTN(74) /= 0) THEN
!    CALL ELECTRON_DENSITY
!    CALL ELECTRON_DENSITY_GRADIENT
!    CALL INTEGRATE_ELECTRON_DENSITY
!    CALL POTENTIAL_DUMP
!   ENDIF
!   IF ((IOPTN(75) /= 0).AND.((IOPTN(74) == 0).OR.(IOPTN(71) <= 2))) THEN
!    CALL ELECTRON_DENSITY
!    CALL ELECTRON_DENSITY_GRADIENT
!    CALL INTEGRATE_ELECTRON_DENSITY
!    CALL DENSITY_DUMP
!   ENDIF
!  ENDIF
   
   RETURN
END SUBROUTINE



!3SUBROUTINE RI_SELF_CONSISTENT_FIELD
!3! PERFORM HARTREE-FOCK OR KOHN-SHAM SELF-CONSISTENT-FIELD ITERATION
!3! EMPLOYING RESOLUTION OF THE INDENTITY INTEGRAL APPROXIMATION.

!3 USE CONTROL
!3 USE GRADIENT
!3 USE AUXILIARY
!3 USE INTEGRAL
!3 USE BASISSET
!3 USE DFT
!3 
!3 IMPLICIT NONE
!3 INTEGER,PARAMETER :: CASHESIZE = 1000 ! CASHE SIZE MUST BE EXACTLY THE SAME IN THE STORE & RESTORE SUBROUTINES
!3 INTEGER :: EOF
!3 INTEGER :: I,J,K,L,P,Q
!3 INTEGER :: Q1,Q2,Q3,Q4
!3 INTEGER :: ISCF,IDIIS
!3 INTEGER :: NAGS_LRG,BATCH
!3 INTEGER :: ICASHECOUNT,ICOUNT
!3 INTEGER,ALLOCATABLE :: INDX(:)
!3 INTEGER(4),ALLOCATABLE :: ICASHE1(:),ICASHE2(:)
!3 DOUBLE PRECISION :: ASYMMETRY,DENSITYCHANGE,OLDENERGY,D
!3 DOUBLE PRECISION,ALLOCATABLE :: DCASHE(:)
!3 DOUBLE PRECISION,ALLOCATABLE :: V(:,:),VLU(:,:),U(:,:),E(:),F(:)
!3 DOUBLE PRECISION,ALLOCATABLE :: DA(:),DANNK(:,:,:,:),TA(:)
!3 REAL :: ICPUS,ICPUE
!3 LOGICAL :: VCORE,DOK
!3
!3 IF (LOPTN(30)) WRITE(6,'(A)') 'RI-SCF CALCULATION WILL BE PERFORMED WITH V APPROXIMATION'
!3 IF (LOPTN(31)) WRITE(6,'(A)') 'RI-SCF CALCULATION WILL BE PERFORMED WITH S APPROXIMATION'
!3 IF (DOPTN(19) /= 0.0D0) THEN
!3  DOK=.TRUE.
!3 ELSE
!3  DOK=.FALSE.
!3 ENDIF
!3
!3 NAGS_LRG=NAGS*(2*CEL3+1)
!3 ALLOCATE(ICASHE1(CASHESIZE),ICASHE2(CASHESIZE),DCASHE(CASHESIZE))
!3 ALLOCATE(DA(NAGS_LRG))
!3 IF (DOK) ALLOCATE(DANNK(NAGS_LRG,NCGS,NCGS,-REDUCED_CEL1-CEL1:REDUCED_CEL1+CEL1),TA(NAGS_LRG))
!3
!3 ! LU DECOMPOSITION OF TWO-INDEX INTEGRAL MATRIX
!3 ALLOCATE(INDX(NAGS_LRG))
!3 IF (DFLOAT(NAGS_LRG*NAGS_LRG)*8.0D0 > DOPTN(28)*1000000.0D0) THEN
!3  VCORE=.FALSE.
!3  BATCH=NAGS
!3  WRITE(6,'(A)') 'LU DECOMPOSITION OF TWO-INDEX INTEGRAL MATRIX'
!3  WRITE(6,'(A,I12)') 'THE NUMBER OF I/O OPERATIONS IS APPROXIMATELY ',6*NAGS_LRG/BATCH
!3  CALL LUDECOMPOSITION_DISK(NAGS_LRG,BATCH,INDX)
!3  CALL PFLUSH(6)
!3 ELSE
!3  VCORE=.TRUE.
!3  WRITE(6,'(A)') 'LU DECOMPOSITION OF TWO-INDEX INTEGRAL MATRIX'
!3  IF (LOPTN(30)) WRITE(6,'(A)') 'V MATRIX WILL BE KEPT IN CORE'
!3  IF (LOPTN(31)) WRITE(6,'(A)') 'S MATRIX WILL BE KEPT IN CORE'
!3  ALLOCATE(V(NAGS,NAGS),VLU(NAGS_LRG,NAGS_LRG))
!3  CALL PCPU_TIME(ICPUS)
!3  DO Q3=-2*CEL3,2*CEL3
!3   IF (LOPTN(30)) CALL TWOINDEX_V(V,NAGS,Q3)
!3   IF (LOPTN(31)) CALL TWOINDEX_S(V,NAGS,Q3)
!3   IF (Q3 < 0) THEN
!3    DO I=0,2*CEL3+Q3
!3     J=I-Q3
!3     DO K=1,NAGS
!3      DO L=1,NAGS
!3       VLU(J*NAGS+L,I*NAGS+K)=V(L,K)
!3      ENDDO
!3     ENDDO
!3    ENDDO
!3   ELSE
!3    DO I=0,2*CEL3-Q3
!3     J=I+Q3
!3     DO K=1,NAGS
!3      DO L=1,NAGS
!3       VLU(I*NAGS+L,J*NAGS+K)=V(L,K)
!3      ENDDO
!3     ENDDO
!3    ENDDO
!3   ENDIF
!3  ENDDO
!3  IF (IOPTN(9) >= 2) CALL DUMP5(VLU,NAGS_LRG)
!3TO REPLACE SV DECOMP BY LU DECOMP, UNCOMMENT THE FOLLOWING LINE ...
!3  CALL LUDCMP(VLU,NAGS_LRG,NAGS_LRG,INDX,D)
!3AND COMMENT OUT FROM HERE ... 
!3  ALLOCATE(E(NAGS_LRG),F(NAGS_LRG))
!3  CALL TRED2(VLU,NAGS_LRG,NAGS_LRG,E,F)
!3  CALL TQLI(E,F,NAGS_LRG,NAGS_LRG,VLU)
!3  ALLOCATE(U(NAGS_LRG,NAGS_LRG))
!3  I=0
!3  U=0.0D0
!3  DO J=1,NAGS_LRG
!3   IF (E(J) > DOPTN(85)) THEN
!3    I=I+1
!3    DO K=1,NAGS_LRG
!3     DO L=1,NAGS_LRG
!3      U(K,L)=U(K,L)+VLU(K,J)*VLU(L,J)/E(J)
!3     ENDDO
!3    ENDDO
!3   ENDIF
!3  ENDDO
!3  VLU=U
!3  DEALLOCATE(U,E,F)
!3  IF (I < NAGS_LRG) WRITE(6,'(A,I3,A)') '***** WARNING :',NAGS_LRG-I,' REDUNDANT BASIS FUNCTIONS DISCARDED'
!3... TO HERE
!3  CALL PCPU_TIME(ICPUE)
!3  WRITE(6,'(A,F10.1)') 'CPU / SEC (INVERSION) = ',ICPUE-ICPUS
!3  CALL PFLUSH(6)
!3 ENDIF
!3
!3 OLDENERGY=0.0D0
!3 WRITE(6,'(A)') 'SELF-CONSISTENT FIELD ITERATION'
!3 IF (IOPTN(9) <= 1) THEN
!3  WRITE(6,'(A)') '-------------------------------------------------------------------------------'
!3  WRITE(6,'(A)') 'ITR DIIS ASSYMETRY  DENSITY CHANGE      TOTAL ENERGY   ENERGY CHANGE  CPU / SEC'
!3 ENDIF
!3 ISCF=1
!3 DO
!3  CALL PCPU_TIME(ICPUS)
!3  IF ((LDFT).AND.(.NOT.(LGC))) CALL LOCAL_EXCHANGE_CORRELATION
!3  IF ((LDFT).AND.(LGC)) CALL GC_EXCHANGE_CORRELATION
!3
!3  ! RESTORE THREE-INDEX TWO-ELECTRON INTEGRALS AND CONTRACT WITH DENSITY MATRIX TO FORM INTERMEDIATE ARRAYS
!3  DA=0.0D0
!3  DANNK=0.0D0
!3  ICOUNT=0
!3  IF (LOPTN(30)) REWIND(32) ! AO-BASED THREE-INDEX ELECTRON REPULSION INTEGRAL FILE
!3  IF (LOPTN(31)) REWIND(35) ! AO-BASED THREE-INDEX OVERLAP INTEGRAL FILE
!3  DO
!3   IF (LOPTN(30)) READ(32,IOSTAT=EOF) ICASHE1,ICASHE2,DCASHE
!3   IF (LOPTN(31)) READ(35,IOSTAT=EOF) ICASHE1,ICASHE2,DCASHE
!3   IF (EOF /= 0) EXIT
!3   DO ICASHECOUNT=1,CASHESIZE
!3    IF (ICASHE1(ICASHECOUNT) == -1) EXIT
!3    ICOUNT=ICOUNT+1
!3    P=0
!3    Q=0
!3    I=0
!3    J=0
!3    L=0
!3    CALL MVBITS(ICASHE1(ICASHECOUNT), 8, 8,P,0)
!3    CALL MVBITS(ICASHE1(ICASHECOUNT), 0, 8,Q,0)
!3    CALL MVBITS(ICASHE2(ICASHECOUNT),24, 8,I,0)
!3    CALL MVBITS(ICASHE2(ICASHECOUNT),16, 8,J,0)
!3    CALL MVBITS(ICASHE2(ICASHECOUNT), 0,16,L,0)
!3    Q1=P-CEL1
!3    Q2=Q-CEL2-CEL3
!3    IF ((Q1 < -REDUCED_CEL1).OR.(Q1 > REDUCED_CEL1).OR.(Q2 < -CEL2-CEL3).OR.(Q2 > CEL2+CEL3)) &
!3    CALL PABORT('INTEGRAL FILE HAS BEEN DEGRADED')
!3    IF ((Q2 >= -CEL3).AND.(Q2 <= CEL3)) THEN
!3     DA((Q2+CEL3)*NAGS+L)=DA((Q2+CEL3)*NAGS+L)+DCASHE(ICASHECOUNT)*P_C(I,J,Q1)
!3     IF (DOK) THEN
!3      DO Q4=-CEL1,CEL1
!3       DO K=1,NCGS
!3        DANNK((Q2+CEL3)*NAGS+L,I,K,Q1-Q4)=DANNK((Q2+CEL3)*NAGS+L,I,K,Q1-Q4)+DCASHE(ICASHECOUNT)*P_C(K,J,Q4)
!3       ENDDO
!3      ENDDO
!3     ENDIF
!3    ENDIF
!3   ENDDO
!3  ENDDO
!3  ! FORM THE PRODUCT OF THE INTERMEDIATE ARRAYS AND INVERSE V OR S
!3  IF (VCORE) THEN
!3   CALL LUBKSB(VLU,NAGS_LRG,NAGS_LRG,INDX,DA)
!3   CALL SVBKSB(VLU,NAGS_LRG,NAGS_LRG,DA)
!3   IF (DOK) THEN
!3    DO Q1=-CEL1-REDUCED_CEL1,CEL1+REDUCED_CEL1
!3     DO J=1,NCGS
!3      DO I=1,NCGS
!3       DO L=1,NAGS_LRG
!3        TA(L)=DANNK(L,I,J,Q1)
!3       ENDDO
!3       CALL LUBKSB(VLU,NAGS_LRG,NAGS_LRG,INDX,TA)
!3       CALL SVBKSB(VLU,NAGS_LRG,NAGS_LRG,TA)
!3       DO L=1,NAGS_LRG
!3        DANNK(L,I,J,Q1)=TA(L)
!3       ENDDO
!3      ENDDO
!3     ENDDO
!3    ENDDO
!3   ENDIF
!3  ELSE
!3   CALL LUBACKSUBSTITUTION_DISK(NAGS_LRG,BATCH,INDX,DA)
!3   IF (DOK) THEN
!3    DO Q1=-CEL1-REDUCED_CEL1,CEL1+REDUCED_CEL1
!3     DO J=1,NCGS
!3      DO I=1,NCGS
!3       DO L=1,NAGS_LRG
!3        TA(L)=DANNK(L,I,J,Q1)
!3       ENDDO
!3       CALL LUBACKSUBSTITUTION_DISK(NAGS_LRG,BATCH,INDX,TA)
!3       DO L=1,NAGS_LRG
!3        DANNK(L,I,J,Q1)=TA(L)
!3       ENDDO
!3      ENDDO
!3     ENDDO
!3    ENDDO
!3   ENDIF
!3  ENDIF
!3  IF (IOPTN(9) >= 2) WRITE(6,'(I9,A,F7.3,A)') ICOUNT, &
!3  ' ERIS (',DFLOAT(ICOUNT)/DFLOAT(CEL1*2+1)/DFLOAT(CEL2*2+1)/DFLOAT((NCGS**2)*NAGS)*100.0,'% OF TOTAL ERIS) HAVE BEEN RESTORED'
!3  ! RESTORE THREE-INDEX TWO-ELECTRON INTEGRALS AGAIN AND CONTRACT WITH INTERMEDIATE ARRAYS TO FORM COULOMB & EXCHANGE MATRICES
!3  C_C=0.0D0 ! INITIALIZE COULOMB MATRIX
!3  X_C=0.0D0 ! INITIALIZE HF-EXCHANGE MATRIX
!3  ICOUNT=0
!3  REWIND(32) ! AO-BASED THREE-INDEX ELECTRON REPULSION INTEGRAL FILE
!3  DO
!3   READ(32,IOSTAT=EOF) ICASHE1,ICASHE2,DCASHE
!3   IF (EOF /= 0) EXIT
!3   DO ICASHECOUNT=1,CASHESIZE
!3    IF (ICASHE1(ICASHECOUNT) == -1) EXIT
!3    ICOUNT=ICOUNT+1
!3    P=0
!3    Q=0
!3    I=0
!3    J=0
!3    L=0
!3    CALL MVBITS(ICASHE1(ICASHECOUNT), 8, 8,P,0)
!3    CALL MVBITS(ICASHE1(ICASHECOUNT), 0, 8,Q,0)
!3    CALL MVBITS(ICASHE2(ICASHECOUNT),24, 8,I,0)
!3    CALL MVBITS(ICASHE2(ICASHECOUNT),16, 8,J,0)
!3    CALL MVBITS(ICASHE2(ICASHECOUNT), 0,16,L,0)
!3    Q1=P-CEL1
!3    Q2=Q-CEL2-CEL3
!3    IF ((Q1 < -REDUCED_CEL1).OR.(Q1 > REDUCED_CEL1).OR.(Q2 < -CEL2-CEL3).OR.(Q2 > CEL2+CEL3))  &
!3    CALL PABORT('INTEGRAL FILE HAS BEEN DEGRADED')
!3    DO Q4=-CEL2,CEL2
!3     IF ((Q2-Q4 >= -CEL3).AND.(Q2-Q4 <= CEL3)) THEN
!3      C_C(I,J,Q1)=C_C(I,J,Q1)+DA((Q2-Q4+CEL3)*NAGS+L)*DCASHE(ICASHECOUNT)
!3     ENDIF
!3    ENDDO
!3    IF (DOK) THEN
!3     DO Q4=-CEL1,CEL1
!3      IF ((Q2-Q4 >= -CEL3).AND.(Q2-Q4 <= CEL3)) THEN
!3       DO K=1,NCGS
!3        X_C(I,K,Q4)=X_C(I,K,Q4)+DANNK((Q2-Q4+CEL3)*NAGS+L,K,J,Q1-Q4)*DCASHE(ICASHECOUNT)
!3       ENDDO
!3      ENDIF
!3     ENDDO
!3    ENDIF
!3   ENDDO
!3  ENDDO
!3  IF (IOPTN(9) >= 2) WRITE(6,'(I9,A,F7.3,A)') ICOUNT, &
!3  ' ERIS (',DFLOAT(ICOUNT)/DFLOAT(CEL1*2+1)/DFLOAT(CEL2*2+1)/DFLOAT((NCGS**2)*NAGS)*100.0,'% OF TOTAL ERIS) HAVE BEEN RESTORED'
!3  DUMP COULOMB & EXCHANGE MATRICES
!3  IF (IOPTN(9) >= 2) THEN
!3   WRITE(6,'(A)') 'COULOMB MATRIX FOR CONTRACTED GAUSSIANS'
!3   CALL DUMP1(C_C,NCGS,CEL1)
!3   IF (DOK) THEN
!3    WRITE(6,'(A)') 'EXCHANGE MATRIX FOR CONTRACTED GAUSSIANS'
!3    CALL DUMP1(X_C,NCGS,CEL1)
!3   ENDIF
!3  ENDIF
!3
!3  CALL FOCK_BUILD(ASYMMETRY,.FALSE.,.FALSE.,.FALSE.)
!3  CALL STORE_DENSITYMATRIX(ISCF,DENSITYCHANGE)
!3  IF ((ISCF /= 1).AND.(DENSITYCHANGE < 1.0D-8)) THEN
!3   CALL RELAX_DENSITYMATRIX(1.0D0)
!3   IDIIS=0
!3  ELSE IF ((IOPTN(16) /= 0).AND.(ISCF >= IOPTN(16)).AND.(MOD(ISCF-IOPTN(16),2) == 0)) THEN
!3  IF ((IOPTN(16) /= 0).AND.(ISCF >= IOPTN(16)).AND.(MOD(ISCF-IOPTN(16),2) == 0)) THEN
!3   CALL DIIS(ISCF,MIN(8,ISCF))
!3   IDIIS=MIN(8,ISCF)
!3  ELSE
!3   CALL RELAX_DENSITYMATRIX(DOPTN(15))
!3   IDIIS=0
!3  ENDIF
!3  CALL DECONTRACT_DENSITYMATRIX
!3  IF (LDFT) THEN
!3   CALL ELECTRON_DENSITY
!3   D1F1=0.0D0
!3   XCF=0.0D0
!3   IF (LGC) THEN
!3    CALL ELECTRON_DENSITY_GRADIENT
!3    D1F2=0.0D0
!3   ENDIF
!3   IF (DOPTN(20) /= 0.0D0) CALL SLATER_EXCHANGE(0)
!3   IF (DOPTN(21) /= 0.0D0) CALL VOSKO_WILK_NUSAIR_CORRELATION(0)
!3   IF (DOPTN(22) /= 0.0D0) CALL BECKE88_EXCHANGE(0)
!3   IF (DOPTN(23) /= 0.0D0) CALL LEE_YANG_PARR_CORRELATION(0)
!3  ENDIF
!3  CALL ENERGY_CALC(.FALSE.,.FALSE.,.FALSE.,.FALSE.)
!3  CALL PCPU_TIME(ICPUE)
!3  IF (IOPTN(9) > 1) THEN
!3   WRITE(6,'(A)') '-------------------------------------------------------------------------------'
!3   WRITE(6,'(A)') 'ITR DIIS ASSYMETRY  DENSITY CHANGE      TOTAL ENERGY   ENERGY CHANGE  CPU / SEC'
!3  ENDIF
!3  IF (ISCF > 1) THEN
!3   WRITE(6,'(I3,1X,I3,2X,E9.3,1X,F15.12,1X,F17.10,1X,F15.10,1X,F10.1)') &
!3   ISCF,IDIIS,ASYMMETRY,DENSITYCHANGE,EHFKS,EHFKS-OLDENERGY,ICPUE-ICPUS
!3  ELSE
!3   WRITE(6,'(I3,1X,I3,2X,E9.3,1X,F15.12,1X,F17.10,3X,A13,1X,F10.1)') &
!3   ISCF,IDIIS,ASYMMETRY,DENSITYCHANGE,EHFKS,'-------------',ICPUE-ICPUS
!3  ENDIF
!3  IF (IOPTN(9) > 1) WRITE(6,'(A)') '-------------------------------------------------------------------------------'
!3  CALL PFLUSH(6)
!3  IF (DENSITYCHANGE < DOPTN(14)) THEN
!3   EXIT
!3  ELSE IF (ISCF == IOPTN(13)) THEN
!3   CALL PABORT('SCF CONVERGENCE NOT MET')
!3  ELSE
!3   OLDENERGY=EHFKS
!3   ISCF=ISCF+1
!3   CYCLE
!3  ENDIF
!3 ENDDO
!3 
!3 IF (IOPTN(9) <= 1) WRITE(6,'(A)') '-------------------------------------------------------------------------------'
!3 WRITE(6,'(A)') 'SCF CONVERGED'
!3 CALL ENERGY_CALC(.TRUE.,.FALSE.,.FALSE.,.FALSE.)
!3 CALL ENERGY_LEVEL(EPSILON,NCGS,KVC,NCGS)
!3 IF (IOPTN(9) == 3) CALL DUMP_CRYSTALORBITALS
!3
!3 DEALLOCATE(DA)
!3 IF (DOK) DEALLOCATE(DANNK,TA)
!3 DEALLOCATE(ICASHE1,ICASHE2,DCASHE)
!3 DEALLOCATE(INDX)
!3 IF (VCORE) DEALLOCATE(V,VLU)
!3 
!3 RETURN
!3D SUBROUTINE

SUBROUTINE ENERGY_CALC(CONVERGE,LOEP,LSLATER,LKLI)
! RETURN TOTAL ELECTRONIC ENERGY PLUS NUCLEAR REPULSION ENERGY.

   USE MPI
   USE CONTROL
   USE CONSTANTS
   USE STRUCTURE
   USE BASISSET
   USE INTEGRAL
   USE GRADIENT
   USE MULTIPOLE
   USE DFT
   
   IMPLICIT NONE
   INTEGER :: QX,QY,QZ,I,J,K
   DOUBLE PRECISION :: A,B,E
   LOGICAL :: CONVERGE,LOEP,LSLATER,LKLI

   EHFKS=NUCLEAR_REPULSION
   IF (CONVERGE.AND.(MYID == 0)) WRITE(6,'(A,F25.14,A)') 'NUCLEAR REPULSION ENERGY    = ',EHFKS,' HARTREE'
   ! HF KINETIC
   B=0.0D0
   DO QX=-CEL1X,CEL1X
   DO QY=-CEL1Y,CEL1Y
   DO QZ=-CEL1Z,CEL1Z
    DO J=1,NCGS
     DO K=1,NCGS
      B=B+P_C(K,J,QX,QY,QZ)*T_C(K,J,QX,QY,QZ)
     ENDDO
    ENDDO
   ENDDO
   ENDDO
   ENDDO
   IF (CONVERGE.AND.(MYID == 0)) WRITE(6,'(A,F25.14,A)') 'KINETIC ENERGY              = ',B,' HARTREE'
   EHFKS=EHFKS+B
   ! HF NUCLEAR ATTRACTION
   B=0.0D0
   DO QX=-CEL1X,CEL1X
   DO QY=-CEL1Y,CEL1Y
   DO QZ=-CEL1Z,CEL1Z
    DO J=1,NCGS
     DO K=1,NCGS
      B=B+P_C(K,J,QX,QY,QZ)*N_C(K,J,QX,QY,QZ)
     ENDDO
    ENDDO
   ENDDO
   ENDDO
   ENDDO
   IF (CONVERGE.AND.(MYID == 0)) WRITE(6,'(A,F25.14,A)') 'NUCLEAR ATTRACTION ENERGY   = ',B,' HARTREE'
   EHFKS=EHFKS+B
   ! HF COULOMB
   B=0.0D0
   DO QX=-CEL1X,CEL1X
   DO QY=-CEL1Y,CEL1Y
   DO QZ=-CEL1Z,CEL1Z
    DO J=1,NCGS
     DO K=1,NCGS
      B=B+P_C(K,J,QX,QY,QZ)*0.5D0*C_C(K,J,QX,QY,QZ)
     ENDDO
    ENDDO
   ENDDO
   ENDDO
   ENDDO
   IF (CONVERGE.AND.(MYID == 0)) WRITE(6,'(A,F25.14,A)') 'COULOMB ENERGY              = ',B,' HARTREE'
   EHFKS=EHFKS+B
   ! HF EXCHANGE
   B=0.0D0
   DO QX=-CEL1X,CEL1X
   DO QY=-CEL1Y,CEL1Y
   DO QZ=-CEL1Z,CEL1Z
    DO J=1,NCGS
     DO K=1,NCGS
      B=B-P_C(K,J,QX,QY,QZ)*0.25D0*X_C(K,J,QX,QY,QZ)*DOPTN(19)
     ENDDO
    ENDDO
   ENDDO
   ENDDO
   ENDDO
   IF (MYID == 0) THEN
   IF (CONVERGE.AND.(.NOT.LOEP).AND.(.NOT.LSLATER).AND.(.NOT.LKLI)) WRITE(6,'(A,F25.14,A)') &
   'HF-EXCHANGE ENERGY          = ',B,' HARTREE'
   IF (CONVERGE.AND.LOEP) WRITE(6,'(A,F25.14,A)')    'OEP EXCHANGE ENERGY         = ',B,' HARTREE'
   IF (CONVERGE.AND.LSLATER) WRITE(6,'(A,F25.14,A)') 'SLATER51 EXCHANGE ENERGY    = ',B,' HARTREE'
   IF (CONVERGE.AND.LKLI) WRITE(6,'(A,F25.14,A)')    'KLI EXCHANGE ENERGY         = ',B,' HARTREE'
   ENDIF
   EHFKS=EHFKS+B
   ! DFT
   IF (LDFT) THEN
    B=0.0D0
    DO I=1,NATOM
     DO J=1,NGRID(I)
      B=B+GRIDW(J,I)*XCF(J,I)
     ENDDO
    ENDDO
    IF (CONVERGE.AND.(MYID == 0)) WRITE(6,'(A,F25.14,A)') 'EXCHANGE-CORRELATION ENERGY = ',B,' HARTREE'
    EHFKS=EHFKS+B
   ENDIF
   ! MULTIPOLE EXPANSION
   IF (IOPTN(18) == 1) THEN
    B=0.0D0
! OLD MPE CODE
!!  E=0.0D0
!!  DO J=1,NATOM
!!   E=E-DFLOAT(IATOM(J))
!!  ENDDO
!!  ! NO ROTATION CONSIDERED
!!  A=RIEMANN_ZETA3
!!  DO QX=1,CEL2X
!!   A=A-1.0D0/DFLOAT(QX**3)
!!  ENDDO
!!  A=A/(PERIODX**3)
!!  DO QX=-CEL1X,CEL1X
!!  DO QY=-CEL1Y,CEL1Y
!!  DO QZ=-CEL1Z,CEL1Z
!!   DO J=1,NCGS
!!    DO K=1,NCGS
!!     B=B+0.5D0*P_C(K,J,QX,QY,QZ)*A*(2.0D0*M_C(K,J,QX,QY,QZ,2)*DIPOLEY+2.0D0*M_C(K,J,QX,QY,QZ,3)*DIPOLEZ &
!!     -4.0D0*M_C(K,J,QX,QY,QZ,1)*DIPOLEX+S_C(K,J,QX,QY,QZ)*(2.0D0*QPOLEXX-QPOLEYY-QPOLEZZ))
!!    ENDDO
!!   ENDDO
!!  ENDDO
!!  ENDDO
!!  ENDDO
!!  B=B+0.5D0*A*(2.0D0*NDIPOLEY*DIPOLEY+2.0D0*NDIPOLEZ*DIPOLEZ &
!!  -4.0D0*NDIPOLEX*DIPOLEX+E*(2.0D0*QPOLEXX-QPOLEYY-QPOLEZZ))
! OLD MPE CODE END
    DO QX=CEL2X+1,HUGECELL
     A=1.0D0/((DFLOAT(QX)*PERIODX)**3)
     E=DCOS(DFLOAT(QX)*HELIX)
     B=B+A*(-2.0D0*DIPOLEX**2+E*DIPOLEY**2+E*DIPOLEZ**2)
    ENDDO
    IF (CONVERGE.AND.(MYID == 0)) WRITE(6,'(A,F25.14,A)') 'MULTIPOLE EXPANSION ENERGY  = ',B,' HARTREE'
    EHFKS=EHFKS+B
   ENDIF
   IF (CONVERGE.AND.(MYID == 0)) WRITE(6,'(A,F25.14,A)') 'TOTAL SCF ENERGY            = ',EHFKS,' HARTREE'

   RETURN
END SUBROUTINE



SUBROUTINE NUCLEAR_REPULSION_CALC
! CALCULATE NUCLEAR REPULSION ENERGY PER UNIT CELL.
! DUMP BOND DISTANCES IF IOPTN(9) IS GREATER THAN 1.

   USE MPI
   USE CONTROL
   USE INTEGRAL
   USE STRUCTURE
   USE GRADIENT
   USE CONSTANTS

   IMPLICIT NONE
   INTEGER :: I,J,KX,KY,KZ
   DOUBLE PRECISION :: E1,E2,X0,Y0,Z0,X1,Y1,Z1,X2,Y2,Z2,R
   DOUBLE PRECISION :: ANGLE,CS,SN

   NUCLEAR_REPULSION=0.0D0
   DO I=1,NATOM
    E1=DFLOAT(IATOM(I))
    X0=ATOMX(I)
    Y0=ATOMY(I)
    Z0=ATOMZ(I)
    DO J=1,NATOM
     E2=DFLOAT(IATOM(J))
     X1=ATOMX(J)
     Y1=ATOMY(J)
     Z1=ATOMZ(J)
     DO KX=-CEL2X,CEL2X
     DO KY=-CEL2Y,CEL2Y
     DO KZ=-CEL2Z,CEL2Z
      ANGLE=DFLOAT(KX)*HELIX
      CS=DCOS(ANGLE)
      SN=DSIN(ANGLE)
      X2=X1+DFLOAT(KX)*PERIODX
      Y2=Y1*CS-Z1*SN+DFLOAT(KY)*PERIODY
      Z2=Y1*SN+Z1*CS+DFLOAT(KZ)*PERIODZ
      IF ((KX**2+KY**2+KZ**2 /= 0).OR.(I /= J)) THEN
       R=DSQRT((X2-X0)**2+(Y2-Y0)**2+(Z2-Z0)**2)
       NUCLEAR_REPULSION=NUCLEAR_REPULSION+0.5D0*E1*E2/R
       IF ((IOPTN(9) >= 2).AND.(R < 10.0D0).AND.(MYID == 0)) THEN
        WRITE(6,'(I3,A2,A,I3,A2,A,3I0,A,F15.10,A)') I,CATOM(IATOM(I)),'(000) -',J,CATOM(IATOM(J)),'(',KX,KY,KZ,') = ',R,' BOHR'
       ENDIF
      ENDIF
     ENDDO
     ENDDO
     ENDDO
    ENDDO
   ENDDO

   IF (MYID == 0) WRITE(6,'(A,F25.15,A)') 'NUCLEAR REPULSION ENERGY = ',NUCLEAR_REPULSION,' HARTREE'
   RETURN
END SUBROUTINE
