import { BrowserModule } from '@angular/platform-browser';
import { NgModule } from '@angular/core';
import { FormsModule } from '@angular/forms';
import { HttpModule } from '@angular/http';

import { AppComponent } from './app.component';
import { FormUsuariosComponent } from './form-usuarios/form-usuarios.component';
import { FormGruposComponent } from './form-grupos/form-grupos.component';

@NgModule({
  declarations: [
    AppComponent,
    FormUsuariosComponent,
    FormGruposComponent,
  ],
  imports: [
    BrowserModule,
    FormsModule,
    HttpModule
  ],
  providers: [],
  bootstrap: [AppComponent]
})
export class AppModule { }
