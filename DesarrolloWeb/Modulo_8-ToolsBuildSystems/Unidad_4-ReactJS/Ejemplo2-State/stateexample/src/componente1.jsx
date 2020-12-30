import React from 'react';

class Componente1 extends React.Component{
  constructor(){
    super()
    this.state = {
      mensaje: 'Bienvenido a ReactJS con Jose Daniel Rodriguez',
    }
  }
  render(){
    return(
      <div>
        <h1>{this.state.mensaje}</h1>Test
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
