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

* Defincion de constantes simbolicas (config. DUART)
*****************************************************************

* Comandos de control (CRA / CRB)
CMD_RST_MR  EQU     %00010000   * Reinicia el puntero interno de MR1/MR2
CMD_EN_RXTX EQU     %00000101   * Habilita Transmisión (bit 0) y Recepción (bit 2)

* Config de modo (MR1 / MR2)
CONF_8BITS  EQU     %00000011   * MR1: 8 bits por caracter, sin paridad
CONF_NOECO  EQU     %00000000   * MR2: Modo normal de operación, sin eco

* Config. de reloj y velocidad (ACR / CSR)
CONF_ACR    EQU     %00000000   * ACR: Baud Rate Set 1
VEL_38400   EQU     %11001100   * CSR: Tx y Rx a 38400bps

* Interrupciones (IVR / IMR)
VEC_INT     EQU     $40         * Vector de interrupción 64 (0x40)
INT_RX_AB   EQU     %00100010   * IMR: Habilita interrupciones de RxA (bit 1) y RxB (bit 5)

* Bits del registro de estado de interrupciones (ISR / IMR)
BIT_RXA EQU     1               * Recepción en Línea A
BIT_RXB EQU     5               * Recepción en Línea B
BIT_TXA EQU     0               * Transmisión en Línea A
BIT_TXB EQU     4               * Transmisión en Línea B

**************************** INIT *************************************************************
INIT:
        * Cargar dirección base del periférico
        LEA     $EFFC00, A0             * A0 apunta a la dirección base de la DUART

        * Configuración de la Línea A
        MOVE.B  #CMD_RST_MR, O_CRA(A0)  * Reinicia puntero MR1A
        MOVE.B  #CONF_8BITS, O_MRA(A0)  * MR1A: 8 bits por carácter
        MOVE.B  #CONF_NOECO, O_MRA(A0)  * MR2A: Modo normal (el puntero avanzó automáticamente)
        MOVE.B  #VEL_38400, O_SRA(A0)   * CSRA: Velocidad 38400 bps

        * Configuración de la Línea B
        MOVE.B  #CMD_RST_MR, O_CRB(A0)  * Reinicia puntero MR1B
        MOVE.B  #CONF_8BITS, O_MRB(A0)  * MR1B: 8 bits por carácter
        MOVE.B  #CONF_NOECO, O_MRB(A0)  * MR2B: Modo normal
        MOVE.B  #VEL_38400, O_SRB(A0)   * CSRB: Velocidad 38400 bps

        * Activación Global (ACR y habilitación de Rx/Tx)
        MOVE.B  #CONF_ACR, O_ACR(A0)    * Selecciona el conjunto de velocidades 1
        MOVE.B  #CMD_EN_RXTX, O_CRA(A0) * Enciende Tx y Rx en Línea A
        MOVE.B  #CMD_EN_RXTX, O_CRB(A0) * Enciende Tx y Rx en Línea B

        * Configuración del Vector de Interrupción en la DUART
        MOVE.B  #VEC_INT, O_IVR(A0)     * Establece el vector de interrupción (0x40)
        
        * Configuración de la Máscara de Interrupciones (IMR)
        MOVE.B  #INT_RX_AB, COPIAIMR    * Guardamos el estado inicial en nuestra variable global
        MOVE.B  COPIAIMR, O_IMR(A0)     * Volcamos la máscara al registro físico IMR

        * Enlace en la Tabla de Vectores de Excepción del 68000
        * (el vector $40 se multiplica por 4 bytes para obtener la dirección $100)
        MOVE.L  #RTI, $100              * Colocamos la dirección de nuestra rutina RTI en $100

        * Inicialización de estructuras de datos auxiliares
        BSR     INI_BUFS

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
        MOVE.B  COPIAIMR, DUART_BASE+O_IMR * Volcamos la copia al registro real IMR (o usar O_IMR si cambiaste las directivas EQU)
        MOVE.W  D6, SR          * Restauramos el registro de estado (fin de exclusión mutua)

EXITO_PRINT:
        MOVE.L  D4, D0          * Devolvemos el número de caracteres procesados en D0
        BRA     FIN_PRINT

ERROR_PRINT:
        MOVE.L  #$FFFFFFFF, D0  * Error por descriptor inválido

FIN_PRINT:
        UNLK    A6      
        RTS
**************************** FIN PRINT ****************************************

**************************** SCAN ************************************************************
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
        BRA     FIN_SCAN

ERROR_SCAN:
        MOVE.L  #$FFFFFFFF,D0   * Devolvemos el código de error por descriptor inválido

FIN_SCAN:
        UNLK    A6      
        RTS
**************************** FIN SCAN ****************************************

**************************** RTI ******************************************
RTI:    
        * Salvar registros
        MOVEM.L D0-D1/A0, -(A7)
        LEA     DUART_BASE, A0      * Cargamos la base de la DUART en A0

BUCLE_RTI:
        * Leer estado de interrupciones y aplicar máscara
        MOVE.B  O_IMR(A0), D1       * Leer ISR
        AND.B   COPIAIMR, D1        * Nos quedamos solo con las interrupciones permitidas

        * Evaluar quien ha interrumpido
        BTST    #BIT_RXA, D1
        BNE     RUTINA_RXA
        BTST    #BIT_RXB, D1
        BNE     RUTINA_RXB
        BTST    #BIT_TXA, D1
        BNE     RUTINA_TXA
        BTST    #BIT_TXB, D1
        BNE     RUTINA_TXB

        * Si llegamos aqui, hemos atendido todo lo pendiente
        BRA     FIN_RTI

RUTINA_RXA:
        MOVE.B  O_TBA(A0), D1       * Leer carácter del RBA (Offset $07)
        MOVE.L  #0, D0              * Parámetro: Buffer circular RxA (0)
        BSR     ESCCAR              * Guardar en buffer de memoria
        CMP.L   #-1, D0
        BEQ     FIN_RTI             * Si el buffer de memoria está lleno, perdemos el dato y salimos
        BRA     BUCLE_RTI           * Volver a comprobar interrupciones

RUTINA_RXB:
        MOVE.B  O_TBB(A0), D1       * Leer carácter del RBB (Offset $17)
        MOVE.L  #1, D0              * Parámetro: Buffer circular RxB (1)
        BSR     ESCCAR
        CMP.L   #-1, D0
        BEQ     FIN_RTI
        BRA     BUCLE_RTI

RUTINA_TXA:
        MOVE.L  #2, D0              * Parámetro: Buffer circular TxA (2)
        BSR     LEECAR              * Sacar carácter de la memoria
        CMP.L   #-1, D0
        BEQ     INHIBIR_TXA         * Si el buffer está vacío, apagar interrupción
        MOVE.B  D0, O_TBA(A0)       * Escribir carácter en hardware TBA (Offset $07)
        BRA     BUCLE_RTI

INHIBIR_TXA:
        BCLR    #BIT_TXA, COPIAIMR  * Borrar bit en nuestra copia en RAM
        MOVE.B  COPIAIMR, O_IMR(A0) * Volcar nueva máscara al hardware
        BRA     BUCLE_RTI

RUTINA_TXB:
        MOVE.L  #3, D0              * Parámetro: Buffer circular TxB (3)
        BSR     LEECAR
        CMP.L   #-1, D0
        BEQ     INHIBIR_TXB
        MOVE.B  D0, O_TBB(A0)       * Escribir carácter en hardware TBB (Offset $17)
        BRA     BUCLE_RTI

INHIBIR_TXB:
        BCLR    #BIT_TXB, COPIAIMR
        MOVE.B  COPIAIMR, O_IMR(A0)
        BRA     BUCLE_RTI

FIN_RTI:
        MOVEM.L (A7)+, D0-D1/A0     * Restaurar todos los registros modificados
        RTE                         * Return from Exception
**************************** FIN RTI **********************************************

**************************** PROGRAMA PRINCIPAL **********************************************
TAMANO  EQU     80          * Tamaño del bloque = 80
DIR_BUF EQU     $5000       * Dirección de memoria libre para el buffer temporal

INICIO: 
        BSR     INIT        * Inicia el controlador DUART y sus interrupciones

BUCLE_ECO:
        * --- FASE DE LECTURA (SCAN) ---
        * Apilamos los 3 parámetros de derecha a izquierda: tamaño, descriptor y direccion
        MOVE.W  #TAMANO, -(A7)  * Apila el tamaño máximo a leer
        MOVE.W  #0, -(A7)       * Apila el descriptor: 0 = Línea A
        MOVE.L  #DIR_BUF, -(A7) * Apila la dirección de inicio del buffer
        BSR     SCAN            * Llama a la subrutina de lectura
        ADD.L   #8, A7          * Limpiamos la pila

        * En este punto, D0 contiene el numero real de caracteres leídos
        * Si no se ha leido nada (D0 = 0) o hubo error, volvemos al inicio
        CMP.L   #0, D0
        BLE     BUCLE_ECO       * Si D0 <= 0, repite el bucle

        * --- FASE DE ESCRITURA (PRINT) ---
        * Reutilizamos el tamaño exacto que devolvió D0 para imprimir solo lo leído
        MOVE.W  D0, -(A7)       * Apila el tamaño a imprimir (2 bytes, desde D0)
        MOVE.W  #0, -(A7)       * Apila el descriptor: 0 = Línea A
        MOVE.L  #DIR_BUF, -(A7) * Apila la dirección del buffer
        BSR     PRINT           * Llama a la subrutina de escritura
        ADD.L   #8, A7          * Limpiamos la pila

        BRA     BUCLE_ECO       * Bucle infinito para probar el eco continuamente
        
        BREAK                   * Instrucción de parada (inalcanzable por BRA)
**************************** FIN PROGRAMA PRINCIPAL ******************************************

	INCLUDE bib_aux.s
	
	