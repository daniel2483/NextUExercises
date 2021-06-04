from abc import ABC,abstractmethod # Abstract Base Class

class Figura(ABC):
    def __init__(self,nombre): # Constructor
        self.nombre = nombre

    @abstractmethod
    def area(self):
        pass
    def permietro(self):
        pass
    
class Rectangulo(Figura): 
    def __init__(self,nombre,base,altura):
        super().__init__(nombre)
        self.base = base
        self.altura = altura

    def area(self):
        return self.base*self.altura

    def perimetro(self):
        return 2*(self.base+self.altura)

rect = Rectangulo("Rectangulo 1",3.0,2.0)
cuad = Rectangulo("Cuadrado Unitario",1.0,1.0)

print("El rectángulo "+rect.nombre+" tiene área "+str(rect.area())+" y perímetro "+str(rect.perimetro()))
print("El rectángulo "+cuad.nombre+" tiene área "+str(cuad.area())+" y perímetro "+str(cuad.perimetro()))
