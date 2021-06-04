from datetime import datetime
from datetime import timedelta

crypto = input("Ingrese una crytomoneda: ")
cantidad = float(input("Ingrese la cantidad acumulada: "))
cotizacion = float(input("Cotización fija por día: "))
#dias = int(input("Cantidad de días: "))

monto_dolares_us = cantidad * cotizacion

cantidad_dias = float(7) # Cantidad de días en una semana

ganancia = (cantidad * 0.5 * cantidad_dias * cotizacion)

print("Cantidad en $US: ",monto_dolares_us,",que el usuario tiene.")

ahora = datetime.now()
en_siete_dias = ahora + timedelta(days=7)  

dia = en_siete_dias.strftime("%A")
diaNumber = en_siete_dias.strftime("%d")
anno = en_siete_dias.strftime("%Y")
mes = en_siete_dias.strftime("%B")

print("Ganancias del 5% de aumento diario dentro de una semana en el día",dia,diaNumber,"de",mes,"de",anno,"\nGanancias US$ =",ganancia)



# Solucion
#from datetime import datetime
#nombreCripto=input("Nombre de la Criptomoneda: ")
#cantCripto=float(input("Cantidad acumulada de la Criptomoneda: "))
#cotizacion=float(input("Cotización por US$ del día de la Criptomoneda: "))
#ahora = datetime.now()
#print(“La fecha completa y hora en la que obtuvo la información fue:“+str(ahora))
#valorTotal= cantCripto * cotizacion
#print("Ud. Posee un total de US$ "+str(valorTotal))
#valorTotal1=valorTotal*1.05
#valorTotal2=valorTotal1*1.05
#valorTotal3=valorTotal2*1.05
#valorTotal4=valorTotal3*1.05
#valorTotal5=valorTotal4*1.05
#valorTotal6=valorTotal5*1.05
#valorTotal7=valorTotal6*1.05
#ganancia= valorTotal7-valorTotal
#print(“Su ganancia luego de una semana es: “+str(ganancia)+“ USD”)

