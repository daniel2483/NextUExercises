// Importa el modulo componente del core de angular
import { Component } from '@angular/core';
import { BarraSuperiorComponent } from './barra-superior/barra-superior.component'

// Decorador, acciones en segundo plano
@Component({
  selector: 'app-root', // Identificador del componente, y sera llamado como una etiqueta HTML
  templateUrl: './app.component.html', // Vista del componente
  styleUrls: ['./app.component.css'] // Estilos para el componente en cuestion
})
export class AppComponent {
  title = 'Hola Mundo!!';
}
