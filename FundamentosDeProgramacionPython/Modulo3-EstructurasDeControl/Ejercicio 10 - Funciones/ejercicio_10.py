import requests
import json


#value = requests.get("https://api.binance.com/api/v3/ticker/price?symbol=BTCUSDT")

#jsonVal = value.json()
#print(jsonVal["price"])


def validarMoneda(moneda):
    monedas = ["BTC","BCC","LTC","ETH","ETC","XRP"]

    while moneda.upper() not in monedas:
        moneda = input("Debe ingresar una moneda válida: ")
    else:
        print("Moneda Válida")
        url = "https://api.binance.com/api/v3/ticker/price?symbol="+ moneda.upper() + "USDT"
        valorActual = requests.get(url)
        jsonVal = valorActual.json()
        precioActual = jsonVal["price"]
        print("El valor actual de la moneda en US$ es de:",precioActual)
        return moneda,precioActual


moneda = input("Ingresar moneda: ")
moneda,precioActual = validarMoneda(moneda)
