import { Component, OnInit } from '@angular/core';

@Component({
  selector: 'i-tareas-grupos',
  templateUrl: './i-tareas-grupos.component.html',
  styleUrls: ['./i-tareas-grupos.component.css']
})
export class ITareasGruposComponent implements OnInit {

  titleGroups = 'Grupos';
  listaGrupos = [{icono: "fas fa-briefcase", nombre: "Universidad", resaltado: false},
                 {icono: "fas fa-user-friends", nombre: "Trabajo", resaltado: false},
                 {icono: "fas fa-graduation-cap", nombre: "Universidad", resaltado: false}]
  constructor() { }

  ngOnInit(): void {
  }

  // Directiva
  mouseEnter(item){
    //this.listaGrupos["resaltado"] = true;
    item.resaltado = true;
  }

  mouseExit(item){
    //this.listaGrupos.resaltado = false;
    item.resaltado = false
  }

}
