
valid_alpha_user = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ1234567890-_."

while True:
    user = input("Ingrese el nombre de usuario: ")
    if(len(user)>4):
        a=set(valid_alpha_user)
        b=set(user)
        if len(b-a)>0:
            print("Usuario inválido.")
            continue
        else:
            print("Usuario válido.")
            break
    else:
        print("Usuario inválido.")
            
