x = int(input("Indique el primer número: "))
y = int(input("Indique el segundo número: "))
z = int(input("Indique el tercer número: "))


print("El máximo entre",x,",",y,"y",z,"es",max(max(x,y),z))

def max(a,b):
    """ Esta función cálcula el máximo entre dos números """
    if a>b:
        maximo = a
    else:
        maximo = b
        
    return maximo
