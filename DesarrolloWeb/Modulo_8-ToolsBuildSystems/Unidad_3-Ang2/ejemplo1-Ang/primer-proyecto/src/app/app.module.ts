import { BrowserModule } from '@angular/platform-browser';
import { NgModule } from '@angular/core';

import { AppComponent } from './app.component';
import { BarraSuperiorComponent } from './barra-superior/barra-superior.component';

@NgModule({
  declarations: [
    AppComponent,
    BarraSuperiorComponent
  ],
  imports: [
    BrowserModule
  ],
  providers: [],
  bootstrap: [AppComponent]
})
export class AppModule { }
