import { BrowserModule } from '@angular/platform-browser';
import { NgModule } from '@angular/core';

import { AppComponent } from './app.component';
import { BarraSuperiorComponent } from './barra-superior/barra-superior.component';
import { InicioComponent } from './inicio/inicio.component';
import { ITareasPendientesComponent } from './inicio/i-tareas-pendientes/i-tareas-pendientes.component';
import { ITareasHoyComponent } from './inicio/i-tareas-hoy/i-tareas-hoy.component';
import { ITareasGruposComponent } from './inicio/i-tareas-grupos/i-tareas-grupos.component';

@NgModule({
  declarations: [
    AppComponent,
    BarraSuperiorComponent,
    InicioComponent,
    ITareasPendientesComponent,
    ITareasHoyComponent,
    ITareasGruposComponent
  ],
  imports: [
    BrowserModule
  ],
  providers: [],
  bootstrap: [AppComponent]
})
export class AppModule { }
