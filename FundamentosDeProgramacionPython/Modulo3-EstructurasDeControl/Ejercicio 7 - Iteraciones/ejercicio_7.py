import random

crytoCoin = input("Cuál es la criptomoneda? ")
amount = float(input("Cuál es la cantidad? "))

print("Cantidad Original: ",amount)

for day in range(1,8):
    randomValue = random.randrange(0, 4)
    subidaObajada = random.randrange(0, 2)
    mensaje= ""
    if subidaObajada == 0:
        amount = amount + (amount * randomValue/100)
        mensaje = "Subida"
    else:
        amount = amount - (amount * randomValue/100)
        mensaje = "Bajada"

    if randomValue != 0:
        print("Día",day," :",amount," Interes:",randomValue," Fue de",mensaje)
    else:
        print("Día",day," :",amount," Interes:",randomValue," No hubo subida ni bajada")
