import { async, ComponentFixture, TestBed } from '@angular/core/testing';

import { ITareasPendientesComponent } from './i-tareas-pendientes.component';

describe('ITareasPendientesComponent', () => {
  let component: ITareasPendientesComponent;
  let fixture: ComponentFixture<ITareasPendientesComponent>;

  beforeEach(async(() => {
    TestBed.configureTestingModule({
      declarations: [ ITareasPendientesComponent ]
    })
    .compileComponents();
  }));

  beforeEach(() => {
    fixture = TestBed.createComponent(ITareasPendientesComponent);
    component = fixture.componentInstance;
    fixture.detectChanges();
  });

  it('should create', () => {
    expect(component).toBeTruthy();
  });
});
