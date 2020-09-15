criptos = ["BTC","BCC","LTC","ETH","ETC","XRP"]
cripto = input("Ingrese el nombre de la moneda: ")
amount = 0

while cripto.upper() not in criptos:
    cripto = input("La moneda "+cripto+" no existe. Ingrese el nombre de la moneda: ")
    
else:
    print("Moneda Válida")

amount = input("Ingrese la cantidad disponible de " + cripto + ": ")

while amount.isnumeric() == False:
    amount = input("Cantidad incorrecta, Ingrese la cantidad disponible de " + cripto + ": ")
    
else:
    print("Cantidad Válida")

cotizacion = input("Cotizaciones en US$: ")

while cotizacion.isnumeric() == False:
    cotizacion = input("Cotización incorrecta, Cotizaciones en US$: ")
    
else:
    print("Cotización Válida")

cantidad_en_dolares = float(amount)*float(cotizacion)

print("Total en US$: ",cantidad_en_dolares)

