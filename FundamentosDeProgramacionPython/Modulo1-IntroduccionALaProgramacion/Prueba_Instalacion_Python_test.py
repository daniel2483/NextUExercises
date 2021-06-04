#!/usr/bin/env python3
# -*- coding: utf-8 -*-
# Fundamentos bÃ¡sicos de programaciÃ³n en Python, NextU
# Actividad Final Unidad 1
#
# Observe las acciones realizadas en este programa y la 
# salida que produce al ejecutar: python3 test.py
# 

import platform

print('Curso             : Fundamentos básicos de programación en Python')
print('Unidad            : 1')
print()

# Información del ambiente de desarrollo
print('Versión de Python :', platform.python_version())
print('Plataforma        :', platform.platform())
print('Sistema           :', platform.system())
print('Nombre Nodo       :', platform.node())
print('Versión kernel    :', platform.version())
print('Máquina/procesador:', platform.machine()+"/"+platform.processor())


X = 10 , Y =35 y Z = 20
a. X + Y * Z / X - Z = 10 + (35 * (20 / 10)) - 10 = 10 + 70 -10 = 70
b. (X + Y * Z) / X - Z = (10 + (35*20)) / 10 = (10 + 700) / 10 = 710/10 = 71
c. X + (Y * Z / X) - Z = 10 + ( 35 * ( 20 / 10 )) - 20 = 10 + (35 * 2) - 20 = 10 + 70 - 20 = 60
d. X + Y * Z / (X - Z) = 10 + 35 * (20 / (10 - 20)) = 10 + 35 (20 / -10) = 10 + 35 * -2 = -60