* Inicializa el SP y el PC
**************************
        ORG     $0
        DC.L    $8000           * Pila
        DC.L    INICIO          * PC

        ORG     $400

* Definicion de equivalencias
*****************************************************************
DUART_BASE  EQU     $EFFC00     * Dirección base de la DUART

O_MRA       EQU     $01         * Offset MR1A y MR2A (Lectura/Escritura)
O_SRA       EQU     $03         * Offset SRA (Lect) y CSRA (Escr)
O_CRA       EQU     $05         * Offset CRA (Escr)
O_TBA       EQU     $07         * Offset RBA (Lect) y TBA (Escr)
O_ACR       EQU     $09         * Offset ACR (Escr)
O_IMR       EQU     $0B         * Offset ISR (Lect) y IMR (Escr)
O_MRB       EQU     $11         * Offset MR1B y MR2B (Lect/Escr)
O_SRB       EQU     $13         * Offset SRB (Lect) y CSRB (Escr)
O_CRB       EQU     $15         * Offset CRB (Escr)
O_TBB       EQU     $17         * Offset RBB (Lect) y TBB (Escr)
O_IVR       EQU     $19         * Offset IVR (Lect/Escr)

COPIAIMR    DS.B    1           * Copia del IMR
HUECO       DS.B    1

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

**************************** PRINT ********************************************
PRINT:  
        LINK    A6,#0
        
        * Extracción y validación del Descriptor
        MOVE.W  12(A6), D2      * D2 = Descriptor (0 para Línea A, 1 para Línea B)
        CMP.W   #1, D2
        BHI     ERROR_PRINT     * Si el descriptor es > 1, es un error

        * Preparación de variables
        MOVE.L  8(A6), A1       * A1 = Dirección del buffer de lectura en memoria
        MOVE.W  14(A6), D3      * D3 = Tamaño de caracteres a escribir
        CLR.L   D4              * D4 = Contador de caracteres aceptados/escritos

        * Calcular el parámetro de buffer para ESCCAR (Descriptor + 2)
        MOVE.L  D2, D5          * Copiamos el descriptor (0 o 1) a D5
        ADD.L   #2, D5          * D5 ahora vale 2 (TxA) o 3 (TxB). Lo usaremos en el bucle.

BUCLE_PRINT:
        * Condición de salida por tamaño
        CMP.W   #0, D3          * Quedan caracteres por procesar?
        BEQ     EVALUAR_INTERRUPCION
        
        * Escritura en el buffer interno
        MOVE.B  (A1)+, D1       * Extraemos el carácter del buffer de memoria a D1
        MOVE.L  D5, D0          * Cargamos en D0 el valor del buffer destino (2 o 3)
        BSR     ESCCAR          * Intentamos escribir en el buffer interno
        
        * Condición de salida por buffer interno lleno
        CMP.L   #-1, D0         * ¿Devolvió -1 indicando que no cabe?
        BEQ     EVALUAR_INTERRUPCION

        * Actualización
        ADD.L   #1, D4          * Incrementamos contador de caracteres guardados
        SUB.W   #1, D3          * Decrementamos caracteres restantes
        BRA     BUCLE_PRINT     * Siguiente carácter

EVALUAR_INTERRUPCION:
        * Comprobar si realmente escribimos algo para habilitar transmisión
        CMP.L   #0, D4
        BEQ     EXITO_PRINT     * Si D4 es 0, no hay que activar interrupciones

        * Sección crítica: Protección de variables compartidas (IMR)
        MOVE.W  SR, D6          * Guardamos el registro de estado actual en D6
        MOVE.W  #$2700, SR      * Inhibimos las interrupciones temporalmente

        * Decidir qué bit del IMR activar según el descriptor
        CMP.W   #0, D2
        BEQ     HABILITAR_A

HABILITAR_B:
        BSET    #4, COPIAIMR    * Bit 4 = Interrupción de transmisión Línea B
        BRA     APLICAR_IMR
        
HABILITAR_A:
        BSET    #0, COPIAIMR    * Bit 0 = Interrupción de transmisión Línea A

APLICAR_IMR:
        MOVE.B  COPIAIMR, $EFFC0B * Volcamos la copia al registro real IMR (o usar O_IMR si cambiaste las directivas EQU)
        MOVE.W  D6, SR          * Restauramos el registro de estado (fin de exclusión mutua)

EXITO_PRINT:
        MOVE.L  D4, D0          * Devolvemos el número de caracteres procesados en D0
        BRA     SALIR_PRINT

ERROR_PRINT:
        MOVE.L  #$FFFFFFFF, D0  * Error por descriptor inválido

SALIR_PRINT:
        UNLK    A6      
        RTS
**************************** FIN PRINT ****************************************

**************************** SCAN ************************************************************
**************************** SCAN ********************************************
SCAN:   
        LINK    A6,#0
        
        * Extracción y validación del Descriptor
        MOVE.W  12(A6),D2       * D2 = Descriptor (0 para línea A, 1 para línea B)
        CMP.W   #1,D2
        BHI     ERROR_SCAN      * Branch if Higher: Si es mayor estricto que 1, es un error

        * Preparación de parámetros para el bucle
        MOVE.L  8(A6),A1        * A1 = Dirección del buffer de destino en memoria
        MOVE.W  14(A6),D3       * D3 = Tamaño máximo a leer
        CLR.L   D4              * D4 = Contador de caracteres leídos (inicializado a 0)

BUCLE_SCAN:
        * Condicion de salida por tamaño
        CMP.W   #0,D3           * Hemos leído ya el número máximo de caracteres solicitados?
        BEQ     EXITO_SCAN      * Si es 0, terminamos

        * Lectura del caracter
        MOVE.L  D2,D0           * El descriptor (0 o 1) coincide exactamente con el parámetro para LEECAR
        BSR     LEECAR          * Extraemos un carácter del buffer interno correspondiente

        * Condicion de salida por buffer vacío
        CMP.L   #-1,D0          * Devolvió LEECAR un -1 indicando que el buffer está vacío?
        BEQ     EXITO_SCAN      * Si es así, no hay más caracteres y salimos del bucle

        * Almacenamiento y actualización
        MOVE.B  D0,(A1)+        * Guardamos el carácter extraído en el buffer del usuario y avanzamos puntero
        ADD.L   #1,D4           * Incrementamos el contador de caracteres leídos
        SUB.W   #1,D3           * Decrementamos los caracteres que nos faltan por leer
        BRA     BUCLE_SCAN      * Repetimos el ciclo

EXITO_SCAN:
        MOVE.L  D4,D0           * Devolvemos el número total de caracteres leídos en D0
        BRA     SALIR_SCAN

ERROR_SCAN:
        MOVE.L  #$FFFFFFFF,D0   * Devolvemos el código de error por descriptor inválido

FIN_SCAN:
        UNLK    A6      
        RTS
**************************** FIN SCAN ****************************************

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
	
	