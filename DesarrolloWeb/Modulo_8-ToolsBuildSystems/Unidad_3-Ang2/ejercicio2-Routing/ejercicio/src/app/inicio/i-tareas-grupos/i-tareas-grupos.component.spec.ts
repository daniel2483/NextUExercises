import { async, ComponentFixture, TestBed } from '@angular/core/testing';

import { ITareasGruposComponent } from './i-tareas-grupos.component';

describe('ITareasGruposComponent', () => {
  let component: ITareasGruposComponent;
  let fixture: ComponentFixture<ITareasGruposComponent>;

  beforeEach(async(() => {
    TestBed.configureTestingModule({
      declarations: [ ITareasGruposComponent ]
    })
    .compileComponents();
  }));

  beforeEach(() => {
    fixture = TestBed.createComponent(ITareasGruposComponent);
    component = fixture.componentInstance;
    fixture.detectChanges();
  });

  it('should create', () => {
    expect(component).toBeTruthy();
  });
});
