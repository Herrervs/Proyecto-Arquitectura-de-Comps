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

CR      EQU     $0D           * Carriage Return
LF      EQU     $0A           * Line Feed
FLAGT   EQU     2             * Flag de transmision
FLAGR   EQU     0             * Flag de recepcion


**************************** INIT *************************************************************
INIT:
        MOVE.B          #%00010000,CRA      * Reinicia el puntero MR1
        MOVE.B          #%00000011,MR1A     * 8 bits por caracter.
        MOVE.B          #%00000000,MR2A     * Eco desactivado.
        MOVE.B          #%11001100,CSRA     * Velocidad = 38400 bps.
        MOVE.B          #%00000000,ACR      * Velocidad = 38400 bps.
        MOVE.B          #%00000101,CRA      * Transmision y recepcion activados.
        RTS
**************************** FIN INIT *********************************************************

**************************** PRINT ************************************************************
PRINT:
        RTS
**************************** FIN PRINT ********************************************************

**************************** SCAN ************************************************************
SCAN:
        RTS

**************************** FIN PROGRAMA PRINCIPAL ******************************************

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