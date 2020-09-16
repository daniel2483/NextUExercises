import requests
from datetime import datetime
from time import gmtime, strftime

# Función para obtener monedas válidas (simbolos) de coinmarketcap.com
def cripto_list():
    crypto_monedas = {}
    url = "/v1/cryptocurrency/listings/latest"
    headers = {  'Accepts': 'application/json',  'X-CMC_PRO_API_KEY':  'a7163a53-2f76-4d3e-9755-a09201ac4dd9'}
    data = requests.get(_ENDPOINT+url,headers=headers).json()
    for crypto_coin in data["data"]:
        crypto_monedas[crypto_coin["symbol"]]= crypto_coin["name"]
        #print(crypto_coin["symbol"])
    return crypto_monedas

# Menu de operaciones
def menu():
    print("\t###############################################")
    print("\t#    Billetera Digital                        #")
    print("\t#                                             #")
    print("\t#            Menú de opcion                   #")
    print("\t# 1. Recibir Cantidad.                        #")
    print("\t# 2. Transferir Monto.                        #")
    print("\t# 3. Mostrar Balance de una Moneda.           #")
    print("\t# 4. Mostrar Balance General.                 #")
    print("\t# 5. Mostrar histórico de Transacciones.      #")
    print("\t# 6. Salir del programa.                      #")
    print("\t# Presione q y enter para salir al Menu       #")
    print("\t###############################################")

    operacion = input("\n\tIngrese la opción deseada: ")
    if operacion.isdigit() and (int(operacion) > 0 and int(operacion) < 7):
        print("\tOpción válida")
    else:
        print("\nPor favor ingrese una opción válida (Opciones de 1 a 6)!\n")

        # Escribe el menu Inicial, se dibuja el menu en caso de ingresar una opcion no válida
        menu()

    if int(operacion) == 1: # Operacion de recibir una cantidad de moneda
        recibir_cantidad()

    if int(operacion) == 2: # Operacion de recibir una cantidad de moneda
        transferir_cantidad()

    if int(operacion) == 3: # Operacion para mostrar balance de una moneda
        mostrar_balance_moneda()

    if int(operacion) == 4: # Operacion para mostrar balance de una moneda
        mostrar_balance_general()

    if int(operacion) == 5:
        mostrar_historico()

    if int(operacion) == 6:
        exit

def revisar_cripto(monedas_diccionario):
    invalid = True
    revisar_moneda = input("\tIngrese una moneda para verificar si es válida: ").upper()

    if revisar_moneda.upper() == "Q":
        menu()

    elif revisar_moneda in crypto_monedas:
        invalid = False
    elif invalid == True:
        print("\tDebe ingresar una moneda válida...")
    return invalid,revisar_moneda

def esnumeroValido(valor):

    cantidad = valor.replace(".","")
    if cantidad.isdigit():
        revisar_cero = float(valor)
        #print(revisar_cero)
        if revisar_cero == 0.0:
            return False
        else:
            return True
    else:
        return False

def escodigoValido(codigo):

    # Descargo el codigo propio
    if codigo == codigo_propio:
        return False

    # Longitud mínumo del codigo es de 8 digitos
    if len(codigo) < 8:
        return False

    # Verifica que el codigo tenga valores de alpha_codigo y no caracteres especiales
    for num in range(0,len(codigo)):
        if codigo[num] not in alpha_codigo:
            return False
    return True

# Se obtienen las cotizaciones de monedas de binance.com
def obtener_valor_moneda(moneda):
    url = "https://api.binance.com/api/v3/ticker/price?symbol="+ moneda.upper() + "USDT"
    valorActual = requests.get(url)
    jsonVal = valorActual.json()
    precioActual = jsonVal["price"]
    #print("\tEl valor actual de la moneda en US$ es de:",precioActual)
    return precioActual

# Leer archivo con saldo, si ya hay un monto a una moneda especifica retorna True y su cantidad o sino False y un valor vacío None
def leer_archivo_saldo(moneda):
    file = open("archivo_de_saldo.txt","r")
    lista = file.readlines()

    for i in range(0,len(lista)):
        if moneda in lista[i]:
            file.close()
            return True,lista[i]
    file.close()
    return False,None

# Función para leer las lineas de un archivo determinado
def leer_archivos(file):
    file = open(file,"r")
    saldos = file.readlines()
    file.close()
    return saldos

# Funcion para ingresar el primer valor de una moneda en caso de que no se haya registrado un saldo para esta
def primer_valor_de_moneda(moneda,cantidad):
    file = open("archivo_de_saldo.txt","a")
    file.write(moneda+"="+str(float(cantidad))+"\n")
    file.close()

# Función para actualizar la cantidad de una moneda en base a la credito o debito de una moneda
def actualizar_valor_moneda(moneda,cantidad,transaccion):
    file = open("archivo_de_saldo.txt","r")
    list_lines = file.readlines()
    nueva_cantidad = 0

    for i in range(0,len(list_lines)):
        if moneda in list_lines[i]:
            valores = list_lines[i].split("=")
            #print(float(cantidad) + float(valores[1]))
            if(transaccion == "credito"):
                list_lines[i] = moneda+"="+str(float(cantidad) + float(valores[1]))+"\n"
            elif(transaccion == "debito"):
                list_lines[i] = moneda+"="+str(-float(cantidad) + float(valores[1]))+"\n"
            nueva_cantidad = list_lines[i].split("=")
            break
    #print(list_lines)
    file.close()

    file = open("archivo_de_saldo.txt","w")

    # Para sobreescribir el nuevo valor modificado
    for i in range(0,len(list_lines)):
        file.write(list_lines[i])
    file.close()
    return nueva_cantidad[1] # Retorna el valor total

# Funcion creada para registrar todas las transacciones de Credito,Debito o Consulta de montos inclusive la consulta del historico
def transacciones_log(moneda,cantidad,tipo,codigo):
    # Se convierte la fecha actual a un formato YYYY-MM-DD HH:MM
    fecha = datetime.now().strftime("%Y-%m-%d %H:%M")
    # Se obtiene la zona horaria donde se efectuo la operacion
    timezone = "GMT "+strftime("%z", gmtime())

    # Valida si la cotizacion si no hay una excecion es que la transaccion no se trata de un credito o debito. Es una consulta
    try:
        cotizacion_usd = obtener_valor_moneda(moneda)
        cantidad_usd = float(cantidad)*float(cotizacion_usd)
    except KeyError:
        cotizacion_usd = "None"
        cantidad_usd = "None"

    file = open("archivo_transacciones.log","a")
    datos = str(fecha)+" "+timezone+"--"+moneda+"--"+tipo+"--"+str(cantidad)+"--"+codigo+"--"+str(cantidad_usd)+"\n"
    file.write(datos)
    file.close()

# Funcion creada para recibir una cantidad de una Moneda especificada, a través de un codigo válido
# Para considerar un codigo válido este debe ser alfanumerico y tener una longitud minima de 8 digitos
def recibir_cantidad():
        print ("\n\tRecibir una cantidad: ")

        cantidad_total = 0

        # Validación de moneda
        valor_invalido,moneda = revisar_cripto(monedas_diccionario)
        while valor_invalido == True:
            valor_invalido,moneda = revisar_cripto(monedas_diccionario)
        else:
            print("\tMoneda",moneda,"es una moneda válida...")

            # Obtengo la cantidad a recibir
            cantidad = input("\tIngrese la cantidad a recibir: ")

            if cantidad == "q":
                menu()

            # Validación de cantidad
            validacionCantidad = esnumeroValido(cantidad)

            while validacionCantidad == False:
                print("\tIngrese un valor correcto de cantidad...")

                # Obtengo la cantidad a recibir
                cantidad = input("\tIngrese la cantidad a recibir: ")

                if cantidad == "q":
                    menu()

                # Valido si la cantidad es número válido
                validacionCantidad = esnumeroValido(cantidad)

            # Obtengo el código para recibir
            codigo = input("\tIngrese el código de origen: ")

            if codigo == "q":
                menu()

            # Validar el codigo (mayor o igual a 8 digits y que sea alfanumerico)
            validacionCodigo = escodigoValido(codigo)

            while validacionCodigo == False:
                print("\tIngrese un valor de código correcto(alfanumerico de minimo 8 digitos)...")

                # Obtengo el código para recibir
                codigo = input("\tIngrese el código de origen: ")

                if codigo == "q":
                    menu()

                # Valido el codigo
                validacionCodigo = escodigoValido(codigo)

        #precio_moneda = obtener_valor_moneda(moneda)
        hay_saldo,monto = leer_archivo_saldo(moneda)

        if hay_saldo == False:
            primer_valor_de_moneda(moneda,cantidad)
            cantidad_total = cantidad
        else:
            cantidad_total = actualizar_valor_moneda(moneda,cantidad,"credito")

        print("\tSe ha acreditado",cantidad,moneda,"a su billetera digital")

        # Registro la nueva transacción
        transacciones_log(moneda,cantidad,"crédito",codigo)
        print("\tEl total de de moneda",moneda,"es de",cantidad_total)

        input("\tPresione enter para continuar con otra operación...")
        print("\n")

        # Invocar de nuevo el menu luego de la transaccion
        menu()

# Funcion creada para tranferir una cantidad de una Moneda especificada, a través de un codigo válido
# Para considerar un codigo válido este debe ser alfanumerico y tener una longitud minima de 8 digitos
def transferir_cantidad():
        print ("\n\tTransferir una cantidad: ")

        cantidad_total = 0

        saldo_suficiente = False

        # Validación de monedas con saldo
        moneda = input("\tIngrese una moneda a transferir: ").upper()

        if moneda == "q":
            menu()

        posee_cantidad,saldo=leer_archivo_saldo(moneda)

        while posee_cantidad == False:
            print("\tUd no posee saldo para esa moneda, o ha ingresado una moneda inválida!")
            moneda = input("\tIngrese una moneda a transferir: ")
            if moneda == "q":
                menu()
            posee_cantidad,saldo=leer_archivo_saldo(moneda)
        else:
            print("\tSe posee saldo de moneda",moneda,"y es de",saldo)

            saldo_moneda,saldo_cantidad = saldo.split("=")

            # Obtengo la cantidad a transferir
            cantidad = input("\tIngrese la cantidad a transferir: ")

            if cantidad == "q":
                menu()

            # Validación de cantidad
            validacionCantidad = esnumeroValido(cantidad)

            while validacionCantidad == False:
                print("\tIngrese un valor correcto de cantidad...")

                # Obtengo la cantidad a recibir
                cantidad = input("\tIngrese la cantidad a transferir: ")

                if cantidad == "q":
                    menu()

                # Valido si la cantidad es número válido
                validacionCantidad = esnumeroValido(cantidad)



            if float(cantidad) > float(saldo_cantidad):
                print("\tNo tiene saldo suficiente!")
                saldo_suficiente = False
            else:
                saldo_suficiente = True

            while saldo_suficiente == False:

                    # Obtengo la cantidad a recibir
                    cantidad = input("\tIngrese una nueva cantidad a transferir: ")

                    if cantidad == "q":
                        menu()

                    # Validación de cantidad
                    validacionCantidad = esnumeroValido(cantidad)

                    while validacionCantidad == False:
                        print("\tIngrese un valor correcto de cantidad...")

                        # Obtengo la cantidad a recibir
                        cantidad = input("\tIngrese la cantidad a transferir: ")

                        if cantidad == "q":
                            menu()

                        # Valido si la cantidad es número válido
                        validacionCantidad = esnumeroValido(cantidad)

                    if float(cantidad) > float(saldo_cantidad):
                        print("\tNo tiene saldo suficiente!")
                        saldo_suficiente = False
                    else:
                        saldo_suficiente = True




            # Obtengo el código para recibir
            codigo = input("\tIngrese el código de destino: ")

            if codigo == "q":
                menu()

            # Validar el codigo (mayor o igual a 8 digits y que sea alfanumerico)
            validacionCodigo = escodigoValido(codigo)

            while validacionCodigo == False:
                print("\tIngrese un valor de código correcto de destino (alfanumerico de minimo 8 digitos)...")

                # Obtengo el código para recibir
                codigo = input("\tIngrese el código de destino: ")

                if codigo == "q":
                    menu()

                # Valido el codigo
                validacionCodigo = escodigoValido(codigo)

            cantidad_total = actualizar_valor_moneda(moneda,cantidad,"debito")

        print("\tSe ha debitado la cantidad",cantidad,moneda,"de su billetera digital")

        # Registro la nueva transacción
        transacciones_log(moneda,cantidad,"débito",codigo)
        print("\tEl total de de moneda",moneda,"es de",cantidad_total)


        input("\tPresione enter para continuar con otra operación...")
        print("\n")

        # Invocar de nuevo el menu luego de la transaccion
        menu()

# Funcion creada para mostrar el balance de una moneda especificada,
#si esta no se encuentra en las monedas de binance.com sale un mensaje "No disponible en binance.com API"
def mostrar_balance_moneda():
    print ("\n\tMostrar Balance de una moneda: ")

    # Validación de monedas con saldo
    moneda = input("\tIngrese una moneda a consultar: ").upper()

    if moneda == "Q":
        menu()

    posee_cantidad,saldo=leer_archivo_saldo(moneda)



    while posee_cantidad == False:
        print("\tUd no posee saldo para esa moneda, o ha ingresado una moneda inválida!")
        moneda = input("\tIngrese una moneda a consultar: ").upper()

        if moneda == "Q":
            menu()

        posee_cantidad,saldo=leer_archivo_saldo(moneda)

    monto = saldo.split("=")
    monto = str(monto[1])
    monto = monto[0:(len(monto)-1)]

    try:
        cotizacion = obtener_valor_moneda(moneda)
        monto_en_usd = float(cotizacion)*float(monto)
    except KeyError:
        cotizacion = "No disponible en binance.com API"
        monto_en_usd = cotizacion


    print("\tSe posee saldo de moneda",moneda)
    print("\t--------------------------------------------------------------")
    print("\t| Moneda: ",moneda)
    print("\t| Saldo: ",monto)
    print("\t| Cotización Actual US$: ",cotizacion)
    print("\t| Monto en USD:",monto_en_usd)
    print("\t--------------------------------------------------------------")

    transacciones_log(moneda,"0","consulta_moneda",codigo_propio)

    input("\n\tPresione enter para continuar con otra operación...")
    print("\n")

    # Invocar de nuevo el menu luego de la transaccion
    menu()

# Funcion creada para mostrar el balance general de cada una de las monedas en el monedero digital.
# En caso de que una moneda no este dentro de binance.com API, no cuenta dentro del Total en USD
def mostrar_balance_general():
    print ("\n\tMostrar Balance General: ")

    saldos = leer_archivos("archivo_de_saldo.txt")
    total_list = []
    monto_total_usd = 0

    print("\tNombre Moneda |  Cantidad  | Cotización Actual | Monto en US$ ")
    for i in range (0,len(saldos)):
        moneda,saldo = saldos[i].split("=")
        try:
            cotizacion_actual = obtener_valor_moneda(moneda)
            monto_en_usd = float(saldo[0:len(saldo)-1])*float(cotizacion_actual)
            total_list.append(monto_en_usd)
        except KeyError:
            cotizacion_actual = "-"
            monto_en_usd = "-"

        #print(len(saldo))
        #print(saldo[0:(len(saldo)-1)])
        print("\tMoneda: "+moneda+"   |   "+saldo[0:len(saldo)-1],"   |   ",cotizacion_actual,"  |  ",monto_en_usd)

    for i in range(0,len(total_list)):
        monto_total_usd += float(total_list[i])

    print("\tMonto Total en USD: ",monto_total_usd)

    transacciones_log("None","0","consulta_balance_general",codigo_propio)

    input("\n\tPresione enter para continuar con otra operación...")
    print("\n")

    # Invocar de nuevo el menu luego de la transaccion
    menu()

# Funcion para mostrar un histórico transaccional, incluye: créditos, débitos, consultas
def mostrar_historico():
    print ("\n\tMostrar histórico Transaccional: ")

    historico = leer_archivos("archivo_transacciones.log")

    print("\tFecha y hora exacta GMT -- Moneda  -- Tipo Transaccion  -- Códigos  -- Montos")
    for i in range (0,len(historico)):
        print("\t"+historico[i])

    transacciones_log("None","0","consulta_balance_general",codigo_propio)

    input("\n\tPresione enter para continuar con otra operación...")
    print("\n")

    # Invocar de nuevo el menu luego de la transaccion
    menu()


##########################################################
####################### Principal ########################
##########################################################

_ENDPOINT = "https://pro-api.coinmarketcap.com"
crypto_monedas = {}

crypto_monedas = cripto_list()

# Obtengo el listado de criptomonedas que pueden ser utilizadas
monedas_diccionario = cripto_list()

file_saldo = "archivo_de_saldo.txt"
file_log = "archivo_transacciones.log"

alpha_codigo = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ1234567890"

# Este código representa el código propio de este monedero digital
codigo_propio = "BGSTux34"

# Escribe el menu Inicial, se dibuja el menu en caso de ingresar una opcion no válida
menu()
