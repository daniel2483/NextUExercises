from datetime import datetime

cripto = input("Cual es la criptomoneda: ")
cotizacion = float(input("Cual es la cotización por $ del día: "))

dt = datetime.now()
dt = dt.strftime("%Y-%m-%d %H:%M:%S")

print("Fecha en que se hizo el cálculo: ",dt)


# Respuesta

#from datetime import datetime
#nombreCripto=input("Nombre de la Criptomoneda: ")
#cantCripto=float(input("Cantidad acumulada de la Criptomoneda: "))
#cotizacion=float(input("Cotización por US$ del día de la Criptomoneda: "))
#ahora = datetime.now()
#print(“La fecha completa y hora en la que obtuvo la información fue:
#“+ahora.strftime(“%A, %d de %B de %Y a las %I:%M:%S%p”))
