
crytoCoin = input("Criptomoneda: ")
crytoAmount = input("Cantidad Acumulada de Criptomoneda: ")
cotizacion = input("Cotización por US$ del día de la criptomoneda: ")

conversionToDolar = float(cotizacion)

Total = float(crytoAmount) * conversionToDolar

print("Ud. posee un total de US$:",Total)


#RETROALIMENTACIÓN

#¡Qué alegría que ya hiciste tu primer programa en Python! Aquí tienes nuestra propuesta de
#solución para este ejercicio. Ahora te animamos a que incorpores tu solución al portafolio que
#estás construyendo, ya estás comenzando a ver el fruto de tu esfuerzo.


#nombreCripto = input("Nombre de la Criptomoneda: ")
#cantCripto = float(input("Cantidad acumulada de la Criptomoneda: "))
#cotizacion = float(input("Cotización por US$ del día de la Criptomoneda: "))
#valorTotal= cantCripto * cotizacion
#print("Ud. Posee un total de US$ "+str(valorTotal))
