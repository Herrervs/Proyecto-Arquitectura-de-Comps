
* V1.0 Feb. 2022
* V1.1 24/02/2022. Alineamiento esccar



SCAN_A	EQU	0
SCAN_B	EQU	1
PRNT_A	EQU	2
PRNT_B	EQU	3

TAMBUF	EQU	2001

* Buffer de Scan A
BSCAN_A		DC.L	BSC_A	* Puntero de extracción 
		DC.L	BSC_A	* Puntero de inserción
BSC_A		DS.B	TAMBUF	* BUFFER DE 2001 BYTES

* Buffer de Scan B
BSCAN_B		DC.L	BSC_B	* Puntero de extracción 
		DC.L	BSC_B	* Puntero de inserción
BSC_B		DS.B	TAMBUF	* BUFFER DE 2001 BYTES

* Buffer de Print A
BPRNT_A		DC.L	BPR_A	* Puntero de extracción 
		DC.L	BPR_A	* Puntero de inserción
BPR_A		DS.B	TAMBUF	* BUFFER DE 2001 BYTES

* Buffer de Print B
BPRNT_B		DC.L	BPR_B	* Puntero de extracción 
		DC.L	BPR_B	* Puntero de inserción
BPR_B		DS.B	TAMBUF	* BUFFER DE 2001 BYTES

		DC.W 1


*************************** ESCCAR *********************************************************

ESCCAR:
        MOVEM.L A0-A4/D2,-(A7)       * Guarda todos los registros en la pila

	CMP.L	#SCAN_A,D0
	BNE	ESCB
	MOVE.L	#BSCAN_A,A0
	BRA	CONTESC
ESCB:   CMP.L   #SCAN_B,D0
        BNE     EPRA
        MOVE.L  #BSCAN_B,A0
        BRA     CONTESC
EPRA:   CMP.L   #PRNT_A,D0
        BNE     EPRB
        MOVE.L  #BPRNT_A,A0
        BRA     CONTESC
EPRB: 	MOVE.L  #BPRNT_B,A0

CONTESC:			* A0 contiene la dirección del puntero de extracción
	MOVE.L	(A0),A1		* A1 contiene el puntero de extracción
	MOVE.L	4(A0),A2	* A2 contiene el puntero de inserción 
	MOVE.L	A0,A3
	ADD.L	#8,A3		* A3 contiene el comienzo del buffer 
	MOVE.L	A3,D2
	ADD.L	#TAMBUF,D2
	MOVE.L	D2,A4		* A4 contiene el final del buffer (1 más allá)

	MOVE.B	D1,(A2)+		* Inserta el caracter
	CMP.L	A2,A4		* Si son iguales  ha llegado al final del buffer
	BNE	ACPUNE
	MOVE.L	A3,A2		* Se pone el puntero de inserción al comienzo del buffer
ACPUNE: CMP.L	A1,A2		* Si son iguales se ha llenado el buffer
	BEQ	LLENO
	MOVE.L	A2,4(A0)	* Actualiza el puntero de inserción
	BRA	FINEB
LLENO:	MOVE.L	#-1,D0		* Se devuelve un -1 en D0 
FINEB:	MOVEM.L       (A7)+,A0-A4/D2 *Restauramos los registros
	RTS

*************************** FIN ESCCAR *****************************************************

*************************** LEECAR *********************************************************

LEECAR:
        MOVEM.L A0-A4/D2,-(A7)       * Guarda todos los registros en la pila

	CMP.L	#SCAN_A,D0
	BNE	LSCB
	MOVE.L	#BSCAN_A,A0
	BRA	CONTLEE
LSCB:   CMP.L   #SCAN_B,D0
        BNE     LPRA
        MOVE.L  #BSCAN_B,A0
        BRA     CONTLEE
LPRA:   CMP.L   #PRNT_A,D0
        BNE     LPRB
        MOVE.L  #BPRNT_A,A0
        BRA     CONTLEE
LPRB: 	MOVE.L  #BPRNT_B,A0

CONTLEE:				* A0 contiene la dirección del puntero de extracción
	MOVE.L	(A0),A1		* A1 contiene el puntero de extracción
	MOVE.L	4(A0),A2	* A2 contiene el puntero de inserción 
	MOVE.L	A0,A3
	ADD.L	#8,A3		* A3 contiene el comienzo del buffer 
        MOVE.L  A3,D2
        ADD.L   #TAMBUF,D2
        MOVE.L  D2,A4           * A4 contiene el final del buffer (1 más allá)

	CMP.L	A1,A2		* Si son iguales, el buffer está vacío
	BNE	NOVAC
	MOVE.L	#-1,D0
	BRA	SALLB

NOVAC:	MOVE.B	(A1)+,D0		* Extrae el caracter
	CMP.L	A1,A4		* Si son iguales  ha llegado al final del buffer
	BNE	ACPUNL
	MOVE.L	A3,A1		* Se pone el puntero de extracción al comienzo del buffer
ACPUNL:	MOVE.L	A1,(A0)		* Actualiza el puntero de extracción

SALLB:	MOVEM.L (A7)+,A0-A4/D2 *Restauramos los registros
	RTS

*************************** FIN LEECAR *****************************************************

*************************** INI_BUFS *********************************************************

INI_BUFS:
	MOVE.L	#BSC_A,BSCAN_A		* Inicia el puntero de extracción
	MOVE.L	#BSC_A,BSCAN_A+4	* Inicia el puntero de inserción
	MOVE.L	#BSC_B,BSCAN_B		* Inicia el puntero de extracción
	MOVE.L	#BSC_B,BSCAN_B+4	* Inicia el puntero de inserción
	MOVE.L	#BPR_A,BPRNT_A		* Inicia el puntero de extracción
	MOVE.L	#BPR_A,BPRNT_A+4	* Inicia el puntero de inserción
	MOVE.L	#BPR_B,BPRNT_B		* Inicia el puntero de extracción
	MOVE.L	#BPR_B,BPRNT_B+4	* Inicia el puntero de inserción
	
        RTS

*************************** FIN INI_BUFS *****************************************************

