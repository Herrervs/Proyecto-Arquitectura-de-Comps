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
CMD_EN_RXTX EQU     %00000101   * Habilita Transmision (bit 0) y Recepcion (bit 2)

* Config de modo (MR1 / MR2)
CONF_8BITS  EQU     %00000011   * MR1: 8 bits por caracter, sin paridad
CONF_NOECO  EQU     %00000000   * MR2: Modo normal de operacion, sin eco

* Config. de reloj y velocidad (ACR / CSR)
CONF_ACR    EQU     %00000000   * ACR: Baud Rate Set 1
VEL_38400   EQU     %11001100   * CSR: Tx y Rx a 38400bps

* Interrupciones (IVR / IMR)
VEC_INT     EQU     $40         * Vector de interrupcion 64 (0x40)
INT_RX_AB   EQU     %00100010   * IMR: Habilita interrupciones de RxA (bit 1) y RxB (bit 5)

* Bits del registro de estado de interrupciones (ISR / IMR)
BIT_RXA EQU     1               * Recepcion en Linea A
BIT_RXB EQU     5               * Recepcion en Linea B
BIT_TXA EQU     0               * Transmision en Linea A
BIT_TXB EQU     4               * Transmision en Linea B

**************************** INIT *************************************************************
INIT:
        * Cargar direccion base del periferico
        LEA     DUART_BASE,A0           * A0 apunta a la direccion base de la DUART

        * Configuracion de la Linea A
        MOVE.B  #CMD_RST_MR,O_CRA(A0)  * Reinicia puntero MR1A
        MOVE.B  #CONF_8BITS,O_MRA(A0)  * MR1A: 8 bits por caracter
        MOVE.B  #CONF_NOECO,O_MRA(A0)  * MR2A: Modo normal (el puntero avanzo automaticamente)
        MOVE.B  #VEL_38400,O_SRA(A0)   * CSRA: Velocidad 38400 bps

        * Configuracion de la Linea B
        MOVE.B  #CMD_RST_MR,O_CRB(A0)  * Reinicia puntero MR1B
        MOVE.B  #CONF_8BITS,O_MRB(A0)  * MR1B: 8 bits por caracter
        MOVE.B  #CONF_NOECO,O_MRB(A0)  * MR2B: Modo normal
        MOVE.B  #VEL_38400,O_SRB(A0)   * CSRB: Velocidad 38400 bps

        * Activacion Global (ACR y habilitacion de Rx/Tx)
        MOVE.B  #CONF_ACR,O_ACR(A0)    * Selecciona el conjunto de velocidades 1
        MOVE.B  #CMD_EN_RXTX,O_CRA(A0) * Enciende Tx y Rx en Linea A
        MOVE.B  #CMD_EN_RXTX,O_CRB(A0) * Enciende Tx y Rx en Linea B

        * Configuracion del Vector de Interrupcion en la DUART
        MOVE.B  #VEC_INT,O_IVR(A0)     * Establece el vector de interrupcion (0x40)
        
        * Configuracion de la Mascara de Interrupciones (IMR)
        MOVE.B  #INT_RX_AB,COPIAIMR    * Guardamos el estado inicial en nuestra variable global
        MOVE.B  COPIAIMR,O_IMR(A0)     * Volcamos la mascara al registro fisico IMR

        * Enlace en la Tabla de Vectores de Excepcion del 68000
        * (el vector $40 se multiplica por 4 bytes para obtener la direccion $100)
        MOVE.L  #RTI,$100              * Colocamos la direccion de nuestra rutina RTI en $100

        * Inicializacion de estructuras de datos auxiliares
        BSR     INI_BUFS

        RTS
**************************** FIN INIT *********************************************************

**************************** PRINT ********************************************
PRINT:  
        LINK    A6,#0
        
        * Extraccion y validacion del Descriptor
        MOVE.W  12(A6),D2       * D2 = Descriptor (0 para Linea A, 1 para Linea B)
        CMP.W   #1,D2
        BHI     ERROR_PRINT     * Si el descriptor es > 1, es un error

        * Preparacion de variables
        MOVE.L  8(A6),A1        * A1 = Direccion del buffer de lectura en memoria
        MOVE.W  14(A6),D3       * D3 = Tamano de caracteres a escribir
        CLR.L   D4              * D4 = Contador de caracteres aceptados/escritos

        * Calcular el parametro de buffer para ESCCAR (Descriptor + 2)
        MOVE.L  D2,D5           * Copiamos el descriptor (0 o 1) a D5
        ADD.L   #2,D5           * D5 ahora vale 2 (TxA) o 3 (TxB). Lo usaremos en el bucle.

BUCLE_PRINT:
        * Condicion de salida por tamano
        CMP.W   #0,D3           * Quedan caracteres por procesar?
        BEQ     EVALUAR_INTERRUPCION
        
        * Escritura en el buffer interno
        MOVE.B  (A1)+,D1        * Extraemos el caracter del buffer de memoria a D1
        MOVE.L  D5,D0           * Cargamos en D0 el valor del buffer destino (2 o 3)
        BSR     ESCCAR          * Intentamos escribir en el buffer interno
        
        * Condicion de salida por buffer interno lleno
        CMP.L   #-1,D0          * Devolvio -1 indicando que no cabe?
        BEQ     EVALUAR_INTERRUPCION

        * Actualizacion
        ADD.L   #1,D4           * Incrementamos contador de caracteres guardados
        SUB.W   #1,D3           * Decrementamos caracteres restantes
        BRA     BUCLE_PRINT     * Siguiente caracter

EVALUAR_INTERRUPCION:
        * Comprobar si realmente escribimos algo para habilitar transmision
        CMP.L   #0,D4
        BEQ     EXITO_PRINT     * Si D4 es 0, no hay que activar interrupciones

        * Seccion critica: Proteccion de variables compartidas (IMR)
        MOVE.W  SR,D6           * Guardamos el registro de estado actual en D6
        MOVE.W  #$2700,SR       * Inhibimos las interrupciones temporalmente

        * Decidir que bit del IMR activar segun el descriptor
        CMP.W   #0,D2
        BEQ     HAB_A

HAB_B:
        BSET    #4,COPIAIMR     * Bit 4 = Interrupcion de transmision Linea B
        BRA     APLICAR_IMR
        
HAB_A:
        BSET    #0,COPIAIMR     * Bit 0 = Interrupcion de transmision Linea A

APLICAR_IMR:
        MOVE.B  COPIAIMR,DUART_BASE+O_IMR * Volcamos la copia al registro real IMR
        MOVE.W  D6,SR           * Restauramos el registro de estado (fin de exclusion mutua)

EXITO_PRINT:
        MOVE.L  D4,D0           * Devolvemos el numero de caracteres procesados en D0
        BRA     FIN_PRINT

ERROR_PRINT:
        MOVE.L  #$FFFFFFFF,D0   * Error por descriptor invalido

FIN_PRINT:
        UNLK    A6      
        RTS
**************************** FIN PRINT ****************************************

**************************** SCAN ************************************************************
SCAN:   
        LINK    A6,#0
        
        * Extraccion y validacion del Descriptor
        MOVE.W  12(A6),D2       * D2 = Descriptor (0 para linea A, 1 para linea B)
        CMP.W   #1,D2
        BHI     ERROR_SCAN      * Branch if Higher: Si es mayor estricto que 1, es un error

        * Preparacion de parametros para el bucle
        MOVE.L  8(A6),A1        * A1 = Direccion del buffer de destino en memoria
        MOVE.W  14(A6),D3       * D3 = Tamano maximo a leer
        CLR.L   D4              * D4 = Contador de caracteres leidos (inicializado a 0)

BUCLE_SCAN:
        * Condicion de salida por tamano
        CMP.W   #0,D3           * Hemos leido ya el numero maximo de caracteres solicitados?
        BEQ     EXITO_SCAN      * Si es 0, terminamos

        * Lectura del caracter
        MOVE.L  D2,D0           * El descriptor (0 o 1) coincide exactamente con el parametro para LEECAR
        BSR     LEECAR          * Extraemos un caracter del buffer interno correspondiente

        * Condicion de salida por buffer vacio
        CMP.L   #-1,D0          * Devolvio LEECAR un -1 indicando que el buffer esta vacio?
        BEQ     EXITO_SCAN      * Si es asi, no hay mas caracteres y salimos del bucle

        * Almacenamiento y actualizacion
        MOVE.B  D0,(A1)+        * Guardamos el caracter extraido en el buffer del usuario y avanzamos puntero
        ADD.L   #1,D4           * Incrementamos el contador de caracteres leidos
        SUB.W   #1,D3           * Decrementamos los caracteres que nos faltan por leer
        BRA     BUCLE_SCAN      * Repetimos el ciclo

EXITO_SCAN:
        MOVE.L  D4,D0           * Devolvemos el numero total de caracteres leidos en D0
        BRA     FIN_SCAN

ERROR_SCAN:
        MOVE.L  #$FFFFFFFF,D0   * Devolvemos el codigo de error por descriptor invalido

FIN_SCAN:
        UNLK    A6      
        RTS
**************************** FIN SCAN ****************************************

**************************** RTI ******************************************
RTI:    
        * Salvar registros
        MOVEM.L D0-D1/A0,-(A7)
        LEA     DUART_BASE,A0       * Cargamos la base de la DUART en A0

BUCLE_RTI:
        * Leer estado de interrupciones y aplicar mascara
        MOVE.B  O_IMR(A0),D1        * Leer ISR
        AND.B   COPIAIMR,D1         * Nos quedamos solo con las interrupciones permitidas

        * Evaluar quien ha interrumpido
        BTST    #BIT_RXA,D1
        BNE     RUT_RXA
        BTST    #BIT_RXB,D1
        BNE     RUT_RXB
        BTST    #BIT_TXA,D1
        BNE     RUT_TXA
        BTST    #BIT_TXB,D1
        BNE     RUT_TXB

        * Si llegamos aqui, hemos atendido todo lo pendiente
        BRA     FIN_RTI

RUT_RXA:
        MOVE.B  O_TBA(A0),D1        * Leer caracter del RBA (Offset $07)
        MOVE.L  #0,D0               * Parametro: Buffer circular RxA (0)
        BSR     ESCCAR              * Guardar en buffer de memoria
        CMP.L   #-1,D0
        BEQ     FIN_RTI             * Si el buffer de memoria esta lleno, perdemos el dato y salimos
        BRA     BUCLE_RTI           * Volver a comprobar interrupciones

RUT_RXB:
        MOVE.B  O_TBB(A0),D1        * Leer caracter del RBB (Offset $17)
        MOVE.L  #1,D0               * Parametro: Buffer circular RxB (1)
        BSR     ESCCAR
        CMP.L   #-1,D0
        BEQ     FIN_RTI
        BRA     BUCLE_RTI

RUT_TXA:
        MOVE.L  #2,D0               * Parametro: Buffer circular TxA (2)
        BSR     LEECAR              * Sacar caracter de la memoria
        CMP.L   #-1,D0
        BEQ     INH_TXA         * Si el buffer esta vacio, apagar interrupcion
        MOVE.B  D0,O_TBA(A0)        * Escribir caracter en hardware TBA (Offset $07)
        BRA     BUCLE_RTI

INH_TXA:
        BCLR    #BIT_TXA,COPIAIMR   * Borrar bit en nuestra copia en RAM
        MOVE.B  COPIAIMR,O_IMR(A0)  * Volcar nueva mascara al hardware
        BRA     BUCLE_RTI

RUT_TXB:
        MOVE.L  #3,D0               * Parametro: Buffer circular TxB (3)
        BSR     LEECAR
        CMP.L   #-1,D0
        BEQ     INH_TXB
        MOVE.B  D0,O_TBB(A0)        * Escribir caracter en hardware TBB (Offset $17)
        BRA     BUCLE_RTI

INH_TXB:
        BCLR    #BIT_TXB,COPIAIMR
        MOVE.B  COPIAIMR,O_IMR(A0)
        BRA     BUCLE_RTI

FIN_RTI:
        MOVEM.L (A7)+,D0-D1/A0      * Restaurar todos los registros modificados
        RTE                         * Return from Exception
**************************** FIN RTI **********************************************

**************************** PROGRAMA PRINCIPAL **********************************************
* =============================================================================
* CASOS DE PRUEBA
* =============================================================================
* Para activar un caso, descomentar su bloque y comentar los demas.
* Solo un caso de prueba debe estar activo a la vez.
* =============================================================================

TAMANO  EQU     80              * Tamano del bloque = 80
DIR_BUF EQU     $5000           * Direccion de memoria libre para buffer temporal A
DIR_BF2 EQU     $5100           * Direccion de memoria libre para buffer temporal B

INICIO: 
        BSR     INIT            * Inicia el controlador DUART y sus interrupciones

        * Desbloqueo de interrupciones de la CPU
        MOVE.W  #$2000,SR       * $2000 = %0010 0000 0000 0000 -> Supervisor=1, Mascara=000

* =============================================================================
* TEST 1: Eco en Linea A (caso original)
* Lee caracteres de la Linea A y los escribe de vuelta por la Linea A.
* Valida: SCAN(desc=0), PRINT(desc=0), RTI(RxA,TxA)
* =============================================================================
BUCLE_ECO_A:
        MOVE.W  #TAMANO,-(A7)   * Tamano maximo a leer
        MOVE.W  #0,-(A7)        * Descriptor: 0 = Linea A
        MOVE.L  #DIR_BUF,-(A7)  * Direccion del buffer
        BSR     SCAN
        ADD.L   #8,A7           * Limpiar pila

        CMP.L   #0,D0
        BLE     BUCLE_ECO_A     * Si no hay datos, reintentar

        MOVE.W  D0,-(A7)        * Tamano real leido
        MOVE.W  #0,-(A7)        * Descriptor: 0 = Linea A
        MOVE.L  #DIR_BUF,-(A7)  * Direccion del buffer
        BSR     PRINT
        ADD.L   #8,A7

        BRA     BUCLE_ECO_A

* =============================================================================
* TEST 2: Eco en Linea B
* Lee caracteres de la Linea B y los escribe de vuelta por la Linea B.
* Valida: SCAN(desc=1), PRINT(desc=1), RTI(RxB,TxB)
* =============================================================================
*BUCLE_ECO_B:
*        MOVE.W  #TAMANO,-(A7)   * Tamano maximo a leer
*        MOVE.W  #1,-(A7)        * Descriptor: 1 = Linea B
*        MOVE.L  #DIR_BUF,-(A7)  * Direccion del buffer
*        BSR     SCAN
*        ADD.L   #8,A7
*
*        CMP.L   #0,D0
*        BLE     BUCLE_ECO_B
*
*        MOVE.W  D0,-(A7)        * Tamano real leido
*        MOVE.W  #1,-(A7)        * Descriptor: 1 = Linea B
*        MOVE.L  #DIR_BUF,-(A7)
*        BSR     PRINT
*        ADD.L   #8,A7
*
*        BRA     BUCLE_ECO_B

* =============================================================================
* TEST 3: Eco cruzado (Lee de A, escribe por B)
* Valida: SCAN(desc=0), PRINT(desc=1), RTI(RxA,TxB) simultaneamente
* =============================================================================
*BUCLE_ECO_CRUZADO:
*        MOVE.W  #TAMANO,-(A7)
*        MOVE.W  #0,-(A7)        * Lee de Linea A
*        MOVE.L  #DIR_BUF,-(A7)
*        BSR     SCAN
*        ADD.L   #8,A7
*
*        CMP.L   #0,D0
*        BLE     BUCLE_ECO_CRUZADO
*
*        MOVE.W  D0,-(A7)
*        MOVE.W  #1,-(A7)        * Escribe por Linea B
*        MOVE.L  #DIR_BUF,-(A7)
*        BSR     PRINT
*        ADD.L   #8,A7
*
*        BRA     BUCLE_ECO_CRUZADO

* =============================================================================
* TEST 4: Eco cruzado inverso (Lee de B, escribe por A)
* Valida: SCAN(desc=1), PRINT(desc=0), RTI(RxB,TxA) simultaneamente
* =============================================================================
*BUCLE_ECO_CRUZ_INV:
*        MOVE.W  #TAMANO,-(A7)
*        MOVE.W  #1,-(A7)        * Lee de Linea B
*        MOVE.L  #DIR_BUF,-(A7)
*        BSR     SCAN
*        ADD.L   #8,A7
*
*        CMP.L   #0,D0
*        BLE     BUCLE_ECO_CRUZ_INV
*
*        MOVE.W  D0,-(A7)
*        MOVE.W  #0,-(A7)        * Escribe por Linea A
*        MOVE.L  #DIR_BUF,-(A7)
*        BSR     PRINT
*        ADD.L   #8,A7
*
*        BRA     BUCLE_ECO_CRUZ_INV

* =============================================================================
* TEST 5: Descriptor invalido en SCAN (descriptor = 2)
* Debe devolver D0 = -1 ($FFFFFFFF) como codigo de error.
* Valida: Gestion de errores de SCAN con descriptor fuera de rango.
* =============================================================================
*        MOVE.W  #TAMANO,-(A7)
*        MOVE.W  #2,-(A7)        * Descriptor invalido (solo 0 y 1 son validos)
*        MOVE.L  #DIR_BUF,-(A7)
*        BSR     SCAN
*        ADD.L   #8,A7
*        * Resultado esperado: D0 = $FFFFFFFF (-1)
*        BREAK

* =============================================================================
* TEST 6: Descriptor invalido en PRINT (descriptor = 5)
* Debe devolver D0 = -1 ($FFFFFFFF) como codigo de error.
* Valida: Gestion de errores de PRINT con descriptor fuera de rango.
* =============================================================================
*        MOVE.W  #10,-(A7)
*        MOVE.W  #5,-(A7)        * Descriptor invalido
*        MOVE.L  #DIR_BUF,-(A7)
*        BSR     PRINT
*        ADD.L   #8,A7
*        * Resultado esperado: D0 = $FFFFFFFF (-1)
*        BREAK

* =============================================================================
* TEST 7: Descriptor invalido en SCAN (descriptor = $FFFF, valor maximo word)
* Valida: Robustez con valor extremo como descriptor.
* =============================================================================
*        MOVE.W  #TAMANO,-(A7)
*        MOVE.W  #$FFFF,-(A7)    * Descriptor extremo
*        MOVE.L  #DIR_BUF,-(A7)
*        BSR     SCAN
*        ADD.L   #8,A7
*        * Resultado esperado: D0 = $FFFFFFFF (-1)
*        BREAK

* =============================================================================
* TEST 8: SCAN con tamano 0
* No debe leer ningun caracter. D0 debe ser 0.
* Valida: Caso borde de tamano = 0 en SCAN.
* =============================================================================
*        MOVE.W  #0,-(A7)        * Tamano 0: no leer nada
*        MOVE.W  #0,-(A7)        * Descriptor: Linea A
*        MOVE.L  #DIR_BUF,-(A7)
*        BSR     SCAN
*        ADD.L   #8,A7
*        * Resultado esperado: D0 = 0
*        BREAK

* =============================================================================
* TEST 9: PRINT con tamano 0
* No debe escribir ningun caracter ni activar interrupciones de TX.
* Valida: Caso borde de tamano = 0 en PRINT. El IMR no debe cambiar.
* =============================================================================
*        MOVE.W  #0,-(A7)        * Tamano 0: no escribir nada
*        MOVE.W  #0,-(A7)        * Descriptor: Linea A
*        MOVE.L  #DIR_BUF,-(A7)
*        BSR     PRINT
*        ADD.L   #8,A7
*        * Resultado esperado: D0 = 0, COPIAIMR sin bit TxA activado
*        BREAK

* =============================================================================
* TEST 10: PRINT con tamano 1 (un solo caracter)
* Valida: Caso minimo de escritura. Se debe transmitir 1 caracter por Linea A.
* =============================================================================
*        MOVE.B  #'Z',DIR_BUF    * Coloca un caracter 'Z' en la direccion del buffer
*        MOVE.W  #1,-(A7)        * Tamano: 1 caracter
*        MOVE.W  #0,-(A7)        * Descriptor: Linea A
*        MOVE.L  #DIR_BUF,-(A7)
*        BSR     PRINT
*        ADD.L   #8,A7
*        * Resultado esperado: D0 = 1, se transmite 'Z' por Linea A
*        BREAK

* =============================================================================
* TEST 11: Imprimir una cadena predefinida por Linea A
* Carga un mensaje en memoria y lo envia. Permite verificar la transmision
* completa de una cadena conocida sin depender de la recepcion.
* Valida: PRINT con datos conocidos, RTI(TxA).
* =============================================================================
*MSG_T11 DC.B    'Hola Mundo!!'
*MSG_LEN EQU     12
*
*        MOVE.W  #MSG_LEN,-(A7)  * Tamano del mensaje
*        MOVE.W  #0,-(A7)        * Descriptor: Linea A
*        MOVE.L  #MSG_T11,-(A7)  * Direccion del mensaje
*        BSR     PRINT
*        ADD.L   #8,A7
*        * Resultado esperado: D0 = 12, se transmite 'Hola Mundo!!' por Linea A
*        BREAK

* =============================================================================
* TEST 12: Imprimir cadena predefinida por Linea B
* Igual que TEST 11 pero por la Linea B.
* Valida: PRINT(desc=1) con datos conocidos, RTI(TxB).
* =============================================================================
*MSG_T12 DC.B    'Test LineaB!'
*MSG_L12 EQU     12
*
*        MOVE.W  #MSG_L12,-(A7)
*        MOVE.W  #1,-(A7)        * Descriptor: Linea B
*        MOVE.L  #MSG_T12,-(A7)
*        BSR     PRINT
*        ADD.L   #8,A7
*        * Resultado esperado: D0 = 12, se transmite 'Test LineaB!' por Linea B
*        BREAK

* =============================================================================
* TEST 13: Eco simultaneo en ambas lineas (A y B)
* Lee de ambas lineas y escribe de vuelta a cada una.
* Valida: Funcionamiento concurrente de ambos canales y su RTI.
* =============================================================================
*BUCLE_DUAL:
*        * --- Eco Linea A ---
*        MOVE.W  #TAMANO,-(A7)
*        MOVE.W  #0,-(A7)        * SCAN Linea A
*        MOVE.L  #DIR_BUF,-(A7)
*        BSR     SCAN
*        ADD.L   #8,A7
*
*        CMP.L   #0,D0
*        BLE     DUAL_B          * Si no hay datos en A, intentar B
*
*        MOVE.W  D0,-(A7)
*        MOVE.W  #0,-(A7)        * PRINT Linea A
*        MOVE.L  #DIR_BUF,-(A7)
*        BSR     PRINT
*        ADD.L   #8,A7
*
*DUAL_B:
*        * --- Eco Linea B ---
*        MOVE.W  #TAMANO,-(A7)
*        MOVE.W  #1,-(A7)        * SCAN Linea B
*        MOVE.L  #DIR_BF2,-(A7)
*        BSR     SCAN
*        ADD.L   #8,A7
*
*        CMP.L   #0,D0
*        BLE     BUCLE_DUAL      * Si no hay datos en B, volver al inicio
*
*        MOVE.W  D0,-(A7)
*        MOVE.W  #1,-(A7)        * PRINT Linea B
*        MOVE.L  #DIR_BF2,-(A7)
*        BSR     PRINT
*        ADD.L   #8,A7
*
*        BRA     BUCLE_DUAL

* =============================================================================
* TEST 14: Escritura grande (intenta saturar el buffer interno de TX)
* Envia un bloque de 2000 bytes para provocar que el buffer circular se llene.
* El valor devuelto en D0 debe ser <= 2000 (los que cupieron).
* Valida: Comportamiento de PRINT cuando ESCCAR devuelve -1 (buffer lleno).
* =============================================================================
*TAM_BIG EQU     2000
*
*        * Rellenar el buffer de memoria con el caracter 'A' (preparacion del test)
*        LEA     DIR_BUF,A1
*        MOVE.W  #TAM_BIG-1,D3
*FILL_BIG:
*        MOVE.B  #'A',(A1)+
*        DBRA    D3,FILL_BIG
*
*        MOVE.W  #TAM_BIG,-(A7)  * Tamano: 2000 caracteres
*        MOVE.W  #0,-(A7)        * Descriptor: Linea A
*        MOVE.L  #DIR_BUF,-(A7)
*        BSR     PRINT
*        ADD.L   #8,A7
*        * Resultado esperado: D0 = 2000 (si el buffer esta vacio) o D0 < 2000
*        BREAK

* =============================================================================
* TEST 15: Multiples PRINTs consecutivos (acumulacion en buffer)
* Envia dos bloques seguidos para verificar que el buffer acumula caracteres
* correctamente entre llamadas y las interrupciones TX los van vaciando.
* Valida: Acumulacion en buffer circular, coherencia entre PRINTs.
* =============================================================================
*MSG_P1  DC.B    'Primero-'
*MSG_L1  EQU     8
*MSG_P2  DC.B    'Segundo!'
*MSG_L2  EQU     8
*
*        * Primer PRINT
*        MOVE.W  #MSG_L1,-(A7)
*        MOVE.W  #0,-(A7)
*        MOVE.L  #MSG_P1,-(A7)
*        BSR     PRINT
*        ADD.L   #8,A7
*
*        * Segundo PRINT inmediato (se acumulan en el buffer interno de TxA)
*        MOVE.W  #MSG_L2,-(A7)
*        MOVE.W  #0,-(A7)
*        MOVE.L  #MSG_P2,-(A7)
*        BSR     PRINT
*        ADD.L   #8,A7
*        * Resultado esperado: se transmite 'Primero-Segundo!' por Linea A
*        BREAK

* =============================================================================
* TEST 16: SCAN de buffer vacio
* Llama a SCAN sin que haya habido ninguna recepcion previa. Debe devolver 0.
* Valida: SCAN con buffer de recepcion vacio (LEECAR devuelve -1 de inmediato).
* =============================================================================
*        MOVE.W  #TAMANO,-(A7)
*        MOVE.W  #0,-(A7)        * Descriptor: Linea A
*        MOVE.L  #DIR_BUF,-(A7)
*        BSR     SCAN
*        ADD.L   #8,A7
*        * Resultado esperado: D0 = 0 (nada que leer)
*        BREAK

* =============================================================================
* TEST 17: SCAN con tamano 1 (un solo caracter)
* Lee un unico caracter de la Linea A. Se debe enviar un caracter previamente
* por el terminal para que haya algo en el buffer de recepcion.
* Valida: Caso minimo de lectura.
* =============================================================================
*BUCLE_T17:
*        MOVE.W  #1,-(A7)        * Tamano: 1 caracter
*        MOVE.W  #0,-(A7)        * Descriptor: Linea A
*        MOVE.L  #DIR_BUF,-(A7)
*        BSR     SCAN
*        ADD.L   #8,A7
*
*        CMP.L   #0,D0
*        BLE     BUCLE_T17       * Esperar hasta recibir 1 caracter
*
*        * Reenviar el caracter leido como eco
*        MOVE.W  #1,-(A7)
*        MOVE.W  #0,-(A7)
*        MOVE.L  #DIR_BUF,-(A7)
*        BSR     PRINT
*        ADD.L   #8,A7
*
*        BRA     BUCLE_T17

* =============================================================================
* TEST 18: Eco bidireccional cruzado (A->B y B->A simultaneamente)
* Lee de cada linea y la envia por la contraria. Maximiza la concurrencia
* del controlador de interrupciones con las 4 fuentes activas.
* Valida: RTI con RxA+TxB y RxB+TxA simultaneos, coherencia del COPIAIMR.
* =============================================================================
*BUCLE_BIDIR:
*        * Lee de A, escribe por B
*        MOVE.W  #TAMANO,-(A7)
*        MOVE.W  #0,-(A7)        * SCAN Linea A
*        MOVE.L  #DIR_BUF,-(A7)
*        BSR     SCAN
*        ADD.L   #8,A7
*
*        CMP.L   #0,D0
*        BLE     BIDIR_BA
*
*        MOVE.W  D0,-(A7)
*        MOVE.W  #1,-(A7)        * PRINT Linea B
*        MOVE.L  #DIR_BUF,-(A7)
*        BSR     PRINT
*        ADD.L   #8,A7
*
*BIDIR_BA:
*        * Lee de B, escribe por A
*        MOVE.W  #TAMANO,-(A7)
*        MOVE.W  #1,-(A7)        * SCAN Linea B
*        MOVE.L  #DIR_BF2,-(A7)
*        BSR     SCAN
*        ADD.L   #8,A7
*
*        CMP.L   #0,D0
*        BLE     BUCLE_BIDIR
*
*        MOVE.W  D0,-(A7)
*        MOVE.W  #0,-(A7)        * PRINT Linea A
*        MOVE.L  #DIR_BF2,-(A7)
*        BSR     PRINT
*        ADD.L   #8,A7
*
*        BRA     BUCLE_BIDIR

        BREAK                   * Instruccion de parada (inalcanzable si hay bucle activo)
**************************** FIN PROGRAMA PRINCIPAL ******************************************

	INCLUDE bib_aux.s
	
	