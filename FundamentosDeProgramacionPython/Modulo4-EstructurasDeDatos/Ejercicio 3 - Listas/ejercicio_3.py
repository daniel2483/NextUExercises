moneda = []
cantidad = []
cotizacion = []

for num in range(0,5):
    #print(num)
    monedas = input("Ingrese el nombre de una criptomoneda: ")
    cantidades = float(input("Ingrese la cantidad de la criptomoneda: "))
    cotizaciones = float(input("Ingrese la cotización de la criptomoneda: "))

    moneda.append(monedas)
    cantidad.append(cantidades)
    cotizacion.append(cotizaciones)

for num in range(0,5):
    print("De la cripto moneda",moneda[num],"essta cotizada en",cotizacion[num],"y se posee una cantidad de",cantidad[num])
    
