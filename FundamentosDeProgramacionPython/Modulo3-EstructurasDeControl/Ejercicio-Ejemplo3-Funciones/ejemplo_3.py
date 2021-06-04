x = int(input("Indique el primer número: "))
y = int(input("Indique el segundo número: "))


print("El máximo entre",x,"y",y,"es",max(x,y))

def max(a,b):
    """ Esta función cálcula el máximo entre dos números """
    if a>b:
        maximo = a
    else:
        maximo = b
        
    return maximo
