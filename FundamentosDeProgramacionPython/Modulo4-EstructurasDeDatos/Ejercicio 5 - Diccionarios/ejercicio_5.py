import requests
import json

URL = "https://api.coinmarketcap.com/v2/listings/"
URL2 = "https://pro-api.coinmarketcap.com/v1/cryptocurrency/quotes/latest"
URL3 = "https://pro-api.coinmarketcap.com/v1/cryptocurrency/listings/latest"

headers = {  'Accepts': 'application/json',  'X-CMC_PRO_API_KEY':  'a7163a53-2f76-4d3e-9755-a09201ac4dd9'}
parametros = {'symbol': 'BTC'}

#data = requests.get("https://pro-api.coinmarketcap.com/v1/cryptocurrency/quotes/latest",headers=headers,params=parametros)

#print(data.json())

crypto_monedas = {}

data = requests.get(URL3,headers=headers).json()

for crypto_coin in data["data"]:
    crypto_monedas[crypto_coin["symbol"]]= crypto_coin["name"]

#monedas = tuple(crypto_monedas)

#for num in range(0,len(crypto_monedas)):
#    print("Moneda:",crypto_monedas[num])
invalid = True

revisar_moneda = input("Ingrese una moneda para verificar si es válida: ").upper()

if revisar_moneda in crypto_monedas:
    invalid = False
    

#if revisar_moneda in monedas:
#    invalid = False

#while invalid == True:
#    print("Moneda inválida!")
#    revisar_moneda = input("Ingrese una moneda para verificar si es válida: ").upper()
#    if revisar_moneda in crypto_monedas:
#        invalid = False
    
#else:
    
#    print("Moneda válida!")

while invalid == True:
    print("Moneda inválida!")
    revisar_moneda = input("Ingrese una moneda para verificar si es válida: ").upper()
    if revisar_moneda in crypto_monedas:
        invalid = False
else:
    print("Moneda válida!")
    print("Su nombre abreviado (symbol) es: ",revisar_moneda)
    print("Su nombre completo (name) es: ",crypto_monedas[revisar_moneda])
