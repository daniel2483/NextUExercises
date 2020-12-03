import { Component, OnInit } from '@angular/core';

@Component({
  selector: 'animaciones',
  templateUrl: './animaciones.component.html',
  styleUrls: ['./animaciones.component.css']
})
export class AnimacionesComponent implements OnInit {

  dias: string[] = [];

  constructor() { }

  ngOnInit() {
    this.dias = ['Lunes', 'Martes', 'Miércoles', 'Jueves'];
  }

  newItem(nombre: string){
    this.dias.push(nombre);
  }

}
