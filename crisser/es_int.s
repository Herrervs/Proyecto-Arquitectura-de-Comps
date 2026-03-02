* Inicializa el SP y el PC
**************************
        ORG     $0
        DC.L    $8000           * Pila
        DC.L    INICIO          * PC

        ORG     $400

* Definicion de equivalencias
*********************************

MR1A    EQU     $effc01       * de modo A (escritura)
MR2A    EQU     $effc01       * de modo A (2 escritura)
SRA     EQU     $effc03       * de estado A (lectura)
CSRA    EQU     $effc03       * de seleccion de reloj A (escritura)
CRA     EQU     $effc05       * de control A (escritura)
TBA     EQU     $effc07       * buffer transmision A (escritura)
RBA     EQU     $effc07       * buffer recepcion A  (lectura)
ACR     EQU     $effc09       * de control auxiliar
IMR     EQU     $effc0B       * de mascara de interrupcion A (escritura)
ISR     EQU     $effc0B       * de estado de interrupcion A (lectura)
MR1B    EQU     $effc11       * de modo B (escritura)
MR2B    EQU     $effc11       * de modo B (2 escritura)
CRB     EQU     $effc15       * de control A (escritura)
TBB     EQU     $effc17       * buffer transmision B (escritura)
RBB     EQU     $effc17       * buffer recepcion B (lectura)
SRB     EQU     $effc13       * de estado B (lectura)
CSRB    EQU     $effc13       * de seleccion de reloj B (escritura)
IVR		EQU		$EFFC19		  * de vector de interrupción (lectura y escritura)

COPIAIMR	DS.B 	1		* Copia del IMR para poder acceder en lectura
HUECO		DS.B	1

**************************** INIT *************************************************************
INIT:
        MOVE.B          #%00010000,CRA      * Reinicia el puntero MR1A
        MOVE.B          #%00000011,MR1A     * 8 bits por caracter.
        MOVE.B          #%00000000,MR2A     * Eco desactivado.
        MOVE.B          #%11001100,CSRA     * Velocidad = 38400 bps.
		
		MOVE.B          #%00010000,CRB      * Reinicia el puntero MR1B
        MOVE.B          #%00000011,MR1B     * 8 bits por caracter.
        MOVE.B          #%00000000,MR2B     * Eco desactivado.
        MOVE.B          #%11001100,CSRB     * Velocidad = 38400 bps.
		
        MOVE.B          #%00000000,ACR      * Velocidad = 38400 bps.
        MOVE.B          #%00000101,CRA      * Transmision y recepcion activados.
		MOVE.B          #%00000101,CRB		* Transmision y recepcion activados.
		
		MOVE.B 			#$40,IVR			* Vector de interrupción
		
		MOVE.B 			#%00100010,COPIAIMR	* Habilitamos interrupciones de recepción, no de transmision
		MOVE.B 			COPIAIMR,IMR 		* MOVE.B 	#%00100010,IMR
		
		MOVE.L 			#RTI,$100			* Actualizmos dirección RTI en Tabla de Vectores
		
		BSR				INI_BUFS
		
        RTS
**************************** FIN INIT *********************************************************

**************************** PRINT ************************************************************
PRINT:	LINK 			A6,#0
		MOVE.L			8(A6),A1			* Guardamos dirección de buffer en A1, A1<-M(A6+8)
		CLR.L 			D2
		CLR.L 			D3
		CLR.L 			D4					* Contador.  También MOVE.L #0,D4	
		MOVE.W			12(A6),D2			* Descriptor
		MOVE.W			14(A6),D3			* Tamaño
		CMP.W			#0,D2
		BEQ				PRINTA
		CMP.W			#1,D2
		BEQ				PRINTB
		MOVE.L 			#$FFFFFFFF,D0
		BRA				FINPRINT
		
PRINTA:	MOVE.L 			#2,D0				* Ponemos D0=2 para la llamada a ESCCAR
		CMP.W			#0,D3				* Comprobamos si nos quedan caracteres por imprimir
		BEQ				FINPRINA
		MOVE.B 			(A1)+,D1			* D1<-M(A1); A1<-A1+1
		BSR				ESCCAR
		CMP.L 			#-1,D0				* Si devuelve -1, buffer lleno
		BEQ				FINPRINA
		ADD.L 			#1,D4				* Incrementamos contador de caractares escritos
		SUB.W 			#1,D3				* Decrementamos en 1 el tamaño a escribir
		BRA 			PRINTA
		
PRINTB:	MOVE.L 			#3,D0				* Ponemos D0=3 para la llamada a ESCCAR
		CMP.W			#0,D3				* Comprobamos si nos quedan caracteres por imprimir
		BEQ				FINPRINB
		MOVE.B 			(A1)+,D1			* D1<-M(A1); A1<-A1+1
		BSR				ESCCAR
		CMP.L 			#-1,D0				* Si devuelve -1, buffer lleno
		BEQ				FINPRINB
		ADD.L 			#1,D4				* Incrementamos contador de caractares escritos
		SUB.W 			#1,D3				* Decrementamos en 1 el tamaño a escribir
		BRA 			PRINTB		
		
FINPRINA:	CMP.L 		#0,D4				* Para ver si se ha escrito algún carácter
			BEQ			FINPRIN2			* Si no se han escrito, no se activa la interrupcion de transmision
			MOVE.W		SR,D5				* Protegemos SR para saber cómo están las interrupciones en este momento
			MOVE.W		#$2700,SR			* Inhibimos las interrupciones para activar las de transmisión
			BSET		#0,COPIAIMR			* OR.B	#1,COPIAIMR
			MOVE.B 		COPIAIMR,IMR		* No hacer BSET #0,IMR, que sale mal
			MOVE.W		D5,SR				* Recuperamos el SR anterior, termina la zona de exclusión mutua
			BRA			FINPRIN2
			
FINPRINB:	CMP.L 		#0,D4				* Para ver si se ha escrito algún carácter
			BEQ			FINPRIN2			* Si no se han escrito, no se activa la interrupcion de transmision
			MOVE.W		SR,D5				* Protegemos SR para saber cómo están las interrupciones en este momento
			MOVE.W		#$2700,SR			* Inhibimos las interrupciones para activar las de transmisión
			BSET		#4,COPIAIMR			* OR.B	#16,COPIAIMR
			MOVE.B 		COPIAIMR,IMR		* No hacer BSET #0,IMR, que sale mal
			MOVE.W		D5,SR				* Recuperamos el SR anterior, termina la zona de exclusión mutua

FINPRIN2:	MOVE.L 		D4,D0				* Copiamos los caracteres escritos a D0

FINPRINT:	UNLK		A6		
		
        RTS
**************************** FIN PRINT ********************************************************

**************************** SCAN ************************************************************
SCAN:	LINK 			A6,#0
		MOVE.L			8(A6),A1			* Guardamos dirección de buffer en A1, A1<-M(A6+8)
		CLR.L 			D2
		CLR.L 			D3
		CLR.L 			D4					* Contador		
		MOVE.W			12(A6),D2			* Descriptor
		MOVE.W			14(A6),D3			* Tamaño
		CMP.W			#0,D2
		BEQ				SCANA
		CMP.W			#1,D2
		BEQ				SCANB
		MOVE.L 			#$FFFFFFFF,D0
		BRA				FINSCAN
		
SCANA:	CLR.L 			D0					* Ponemos D0=0 para la llamada a LEECAR
		BSR				LEECAR
		CMP.L 			#-1,D0				* Si D0=-1, buffer vacío y hemos terminado
		BEQ				FINSCAN1
		MOVE.B 			D0,(A1)+			* M(A1)<-D0; A1<-A1+1
		ADD.L 			#1,D4				* Incrementamos contador de caracteres
		SUB.W			#1,D3				* Decrementamos lo que nos queda por leer
		CMP.W			#0,D3
		BNE				SCANA
		BRA				FINSCAN1
		
SCANB:	MOVE.L 			#1,D0					* Ponemos D0=1 para la llamada a LEECAR
		BSR				LEECAR
		CMP.L 			#-1,D0				* Si D0=-1, buffer vacío y hemos terminado
		BEQ				FINSCAN1
		MOVE.B 			D0,(A1)+			* M(A1)<-D0; A1<-A1+1
		ADD.L 			#1,D4				* Incrementamos contador de caracteres
		SUB.W			#1,D3				* Decrementamos lo que nos queda por leer
		CMP.W			#0,D3
		BNE				SCANB
		
FINSCAN1:	MOVE.L 		D4,D0				* Copiamos caracteres leídos a D0
FINSCAN:	UNLK		A6		
		
        RTS

**************************** FIN SCAN ******************************************

**************************** RTI ******************************************

RTI:	MOVEM.L 		D0-D1,-(A7)
BUCLE1:	MOVE.B 			ISR,D1
		AND.B 			COPIAIMR,D1
		BTST			#1,D1				* Recepción línea A
		BNE				RXLA				* Si el bit no es 0 (entonces es 1) hay interrupción
		BTST			#5,D1				* Recepción línea B
		BNE 			RXLB
		BTST			#0,D1				* Transmisión línea A
		BNE 			TXLA
		BTST			#4,D1				* Transmisión línea BEQ
		BNE 			TXLB
		BRA				FINRTI
		
RXLA:	MOVE.B 			RBA,D1
		MOVE.L 			#0,D0
		BSR				ESCCAR
		CMP.L 			#-1,D0
		BEQ				FINRTI				* Si está lleno el buffer terminamos
		BRA				BUCLE1
		
RXLB:	MOVE.B 			RBB,D1
		MOVE.L 			#1,D0
		BSR				ESCCAR
		CMP.L 			#-1,D0
		BEQ				FINRTI				* Si está lleno el buffer terminamos
		BRA				BUCLE1

TXLA:	MOVE.L 			#2,D0
		BSR				LEECAR
		CMP.L 			#-1,D0
		BEQ				INHA
		MOVE.B 			D0,TBA
		BRA				BUCLE1
		
INHA:	BCLR			#0,COPIAIMR
		MOVE.B 			COPIAIMR,IMR
		BRA				BUCLE1
		
TXLB:	MOVE.L 			#3,D0
		BSR				LEECAR
		CMP.L 			#-1,D0
		BEQ				INHB
		MOVE.B 			D0,TBB
		BRA				BUCLE1
		
INHB:	BCLR			#4,COPIAIMR
		MOVE.B 			COPIAIMR,IMR
		BRA				BUCLE1

FINRTI:	MOVEM.L 		(A7)+,D0-D1
		RTE		

**************************** FIN RTI **********************************************

**************************** PROGRAMA PRINCIPAL **********************************************

TAMANO EQU 1

INICIO: BSR             INIT                * Inicia el controlador
* OTRO:   MOVE.W        #TAMANO,-(A7)
*       MOVE.L          #$5000,-(A7)        * Prepara la direccion del buffer
*         BSR             SCAN                * Recibe la linea
*         ADD.L           #6,A7               * Restaura la pila
*       MOVE.W          #TAMANO,-(A7)
*         MOVE.L          #$5000,-(A7)        * Prepara la direccion del buffer
*         BSR             PRINT               * Imprime linea
*         ADD.L           #6,A7               * Restaura la pila
*       BRA             OTRO

        BREAK
**************************** FIN PROGRAMA PRINCIPAL ******************************************

	INCLUDE bib_aux.s
	
	