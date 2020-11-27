import { Component, OnInit } from '@angular/core';

@Component({
  selector: 'i-tareas-hoy',
  templateUrl: './i-tareas-hoy.component.html',
  styleUrls: ['./i-tareas-hoy.component.css']
})
export class ITareasHoyComponent implements OnInit {

  titleHoy = 'Tareas Hoy';
  listaTareasHoy = ['Recoger Libros', 'Firmar Autorización', 'Enviar Email Diario']
  constructor() { }

  ngOnInit(): void {
  }

}
