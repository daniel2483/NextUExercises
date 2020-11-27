import { Component, OnInit } from '@angular/core';

@Component({
  selector: 'i-tareas-pendientes',
  templateUrl: './i-tareas-pendientes.component.html',
  styleUrls: ['./i-tareas-pendientes.component.css']
})
export class ITareasPendientesComponent implements OnInit {

  titlePending = 'Tareas Pendientes';
  tareasPendientes = ['Recoger Libros', 'Firmar Autorización', 'Cita con Maria', 'Hablar con Dios']
  
  constructor() { }

  ngOnInit(): void {
  }

}
