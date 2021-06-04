i=0
cripto=[]
cant=[]
cotiz=[]
while i<5:
    cripto.append(input("Indique el nombre de la criptomoneda: "))
    cant.append(float(input("Indique la cantidad de "+cripto[i]+": ")))
    cotiz.append(float(input("Indique la cotización en USD de "+cripto[i]+": ")))
    i=i+1

i=0
while i<5:
    print("Moneda: ",cripto[i],", Cantidad: ",str(cant[i]),", Cotización: "+str(cotiz[i]))
    i=i+1

