import { Component } from '@angular/core';

@Component({
  selector: 'app-root',
  templateUrl: './app.component.html',
  styleUrls: ['./app.component.css']
})
export class AppComponent {
  title = 'pipe';
  valor1 = 'hola este es un mensaje de ejemplo de pipe!';
  fecha1 = new Date(2020, 10, 27);
  numero1 = 45;
}
