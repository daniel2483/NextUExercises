

saldoActual = 45
saldoAnterior = saldoActual
moneda = "US$"

moneda = input("Con cual moneda desea realizar el pago (BTC,DASH o LTC): ")
cantidad = float(input("Ingresa una cantidad: "))

cotizacionBTC = 0.55
cotizacionDASH = 0.34
cotizacionLTC = 0.23


if moneda.lower() == "btc":
    saldoActual+= cotizacionBTC * cantidad
elif moneda.lower() == "dash":
    saldoActual+= cotizacionDASH * cantidad
else:
    saldoActual+= cotizacionLTC * cantidad

print("El saldo anterior es de:",saldoAnterior)
print("El nuevo saldo es de:",saldoActual)
