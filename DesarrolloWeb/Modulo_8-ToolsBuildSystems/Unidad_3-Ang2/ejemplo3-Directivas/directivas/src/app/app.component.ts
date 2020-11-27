import { Component } from '@angular/core';

@Component({
  selector: 'app-root',
  templateUrl: './app.component.html',
  styleUrls: ['./app.component.css']
})
export class AppComponent {
  title = 'directivas';
  tituloMostrado = true;
  listaNombres = ['Juan','Pedro','Daniel','Andrés','Alejandro'];

  // Directiva Estructural
  buttonClicked(){
    this.tituloMostrado = !this.tituloMostrado;
  }
}
