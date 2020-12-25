import React from 'react';
import Componente2 from './componente2.jsx'

class Componente1 extends React.Component{
  constructor(){
    super()
    this.state = {
      mensaje: 'Bienvenido a ReactJS con Jose Daniel Rodriguez',
      mensaje2: 'Learning States & Props'
    }

  }
  render(){
    return(
      <div>
        <h1>{this.state.mensaje}</h1>
        <Componente2 mensajeProps={this.state.mensaje2} cambioEstado={this.changeState.bind(this)}/>
        <div>
          <button onClick={this.changeState.bind(this)}>Cambiar Estado</button>
        </div>
      </div>
    )}

  changeState(){
    this.setState({ mensaje: 'Este es un nuevo mensaje...'})
  }

}


export default Componente1;
