

crytoCoin1 = input("Ingrese el nombre de una cryto Moneda (1): ")
crytoCoin2 = input("Ingrese el nombre de una cryto Moneda (2): ")
crytoCoin3 = input("Ingrese el nombre de una cryto Moneda (3): ")

cantidadCrypto1 = float(input("Cuál es la cantidad de cryto moneda " + crytoCoin1 + ": "))
cantidadCrypto2 = float(input("Cuál es la cantidad de cryto moneda " + crytoCoin2 + ": "))
cantidadCrypto3 = float(input("Cuál es la cantidad de cryto moneda " + crytoCoin3 + ": "))


if cantidadCrypto1 > cantidadCrypto2:
	if cantidadCrypto1 > cantidadCrypto3:
		print ("Cantidad de:",crytoCoin1,cantidadCrypto1)
		if cantidadCrypto2 > cantidadCrypto3:
			print ("Cantidad de:",crytoCoin2,cantidadCrypto2)
			print ("Cantidad de:",crytoCoin3,cantidadCrypto3)
		else:
			print ("Cantidad de:",crytoCoin3,cantidadCrypto3)
			print ("Cantidad de:",crytoCoin2,cantidadCrypto2)
	else:
		print ("Cantidad de:",crytoCoin3,cantidadCrypto3)
		print ("Cantidad de:",crytoCoin1,cantidadCrypto1)
		print ("Cantidad de:",crytoCoin2,cantidadCrypto2)

elif cantidadCrypto2 > cantidadCrypto3:
	print ("Cantidad de:",crytoCoin2,cantidadCrypto2)
	if cantidadCrypto3 > cantidadCrypto1:
		print ("Cantidad de:",crytoCoin3,cantidadCrypto3)
		print ("Cantidad de:",crytoCoin1,cantidadCrypto1)
	else:
		print ("Cantidad de:",crytoCoin1,cantidadCrypto1)
		print ("Cantidad de:",crytoCoin3,cantidadCrypto3)
else:
	print ("Cantidad de:",crytoCoin3,cantidadCrypto3)
	print ("Cantidad de:",crytoCoin2,cantidadCrypto2)
	print ("Cantidad de:",crytoCoin1,cantidadCrypto1)

