

def validacion_moneda(crypto):
    cryptos = ["BTC", "BCC", "LTC", "ETH", "ETC", "XRP"]

    while crypto.upper() not in cryptos:
        crypto = input("No ingresaste una moneda correcto, Ingresa una nueva moneda: ")
    else:
        print("Moneda válida")
        return crypto

def validacion_cantidad(cantidad):

    while cantidad.isnumeric()==False:
        cantidad = input("No ingresaste una cantidad correcta, Ingresa una nueva cantidad: ")
    else:
        print("Cantidad válida")
        return cantidad

def validacion_cotizacion(cantidad):

    while cantidad.isnumeric()==False:
        cantidad = input("No ingresaste una cotización correcta, Ingresa una nueva cotización: ")
    else:
        print("Cotización válida")
        return cantidad



for num in range(0,3):
    moneda = input("Ingresa una nueva moneda: ")
    crytoMoneda = validacion_moneda(moneda)

    cantidad = input("Ingresa la cantida de la moneda " + crytoMoneda + ": ")
    cantidad = validacion_cantidad(cantidad)

    cotizacion = input("Ingresa la cotización de la moneda " + crytoMoneda + ": ")
    cotizacion = validacion_cotizacion(cantidad)

    cantidad_en_us_dolares = float(cantidad) * float(cotizacion)
    
    print("La cantidad en dólares de",crytoMoneda,"es de",cantidad_en_us_dolares,"US$")
    
